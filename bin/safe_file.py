"""Small descriptor-based helpers for user-owned plugin data."""

import os
import secrets
import stat


MAX_DATA = 8192


def fail(message):
    raise RuntimeError(message)


def _checked_dir(parent_fd, name, create=False):
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    try:
        fd = os.open(name, flags, dir_fd=parent_fd)
    except FileNotFoundError:
        if not create:
            raise
        os.mkdir(name, 0o700, dir_fd=parent_fd)
        fd = os.open(name, flags, dir_fd=parent_fd)
    info = os.fstat(fd)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        os.close(fd)
        fail("refusing an unowned directory")
    if info.st_mode & 0o022:
        os.close(fd)
        fail("refusing a group- or world-writable directory")
    return fd


def data_dir(kind):
    home = os.environ.get("HOME")
    if not home or not os.path.isabs(home):
        fail("HOME must be an absolute path")
    home_fd = os.open(home, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        if os.fstat(home_fd).st_uid != os.getuid():
            fail("refusing an unowned HOME")
        if kind == "settings":
            config = _checked_dir(home_fd, ".config", create=True)
            try:
                return _checked_dir(config, "omarchy", create=True), "battery-alerts.json"
            finally:
                os.close(config)
        local = _checked_dir(home_fd, ".local", create=True)
        try:
            state = _checked_dir(local, "state", create=True)
            try:
                return _checked_dir(state, "omarchy", create=True), "battery-alerts.json"
            finally:
                os.close(state)
        finally:
            os.close(local)
    finally:
        os.close(home_fd)


def read_regular(directory_fd, name, limit=MAX_DATA):
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    try:
        fd = os.open(name, flags, dir_fd=directory_fd)
    except FileNotFoundError:
        return None
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            fail("refusing a non-regular or unowned file")
        if info.st_size > limit:
            fail("refusing an oversized file")
        data = bytearray()
        while len(data) <= limit:
            chunk = os.read(fd, min(65536, limit + 1 - len(data)))
            if not chunk:
                break
            data.extend(chunk)
        if len(data) > limit:
            fail("refusing an oversized file")
        return bytes(data)
    finally:
        os.close(fd)


def atomic_replace(directory_fd, name, data, limit=MAX_DATA):
    if len(data) > limit:
        fail("refusing oversized output")
    mode = 0o600
    try:
        existing = os.open(name, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                           dir_fd=directory_fd)
    except FileNotFoundError:
        existing = None
    if existing is not None:
        try:
            info = os.fstat(existing)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                fail("refusing to replace a non-regular or unowned file")
            mode = stat.S_IMODE(info.st_mode)
        finally:
            os.close(existing)

    temporary = ".battery-alerts-" + secrets.token_hex(16)
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
                 mode, dir_fd=directory_fd)
    try:
        written = 0
        while written < len(data):
            count = os.write(fd, data[written:])
            if count <= 0:
                fail("short write while replacing file")
            written += count
        os.fsync(fd)
        os.fchmod(fd, mode)
        os.replace(temporary, name, src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
        os.fsync(directory_fd)
    except Exception:
        try:
            os.unlink(temporary, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
        raise
    finally:
        os.close(fd)
