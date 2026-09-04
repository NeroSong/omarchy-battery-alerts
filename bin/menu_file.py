"""Descriptor-scoped access to Omarchy's shared user menu extension."""

import json
import os
import re

from safe_file import _checked_dir, atomic_replace, fail, read_regular

MENU_NAME = "omarchy-menu.jsonc"
BACKUP_NAME = MENU_NAME + ".battery-alerts.bak"
START = "// battery-alerts:start"
END = "// battery-alerts:end"
ENTRY_ID = "setup.battery-alerts"
ACTION = "/usr/bin/omarchy-shell shell summon nerosong.battery-alerts"
LEGACY_ACTION = "omarchy-shell shell summon nerosong.battery-alerts"
BLOCK_PATTERN = re.compile(
    r"^[ \t]*// battery-alerts:start[ \t]*\n"
    r"(?P<body>.*?)"
    r"^[ \t]*// battery-alerts:end[ \t]*(?:\n|$)",
    flags=re.MULTILINE | re.DOTALL,
)


def strip_jsonc(value):
    stripped = re.sub(r"^\s*//[^\n]*(?:\n|$)", "", value, flags=re.MULTILINE)
    return re.sub(r",(\s*[}\]])", r"\1", stripped)


def parse_jsonc(value):
    parsed = json.loads(strip_jsonc(value))
    if not isinstance(parsed, dict):
        fail("menu must be a top-level JSONC object")
    return parsed


def marked_entry(text):
    if text.count(START) != 1 or text.count(END) != 1:
        fail("refusing ambiguous Battery Alerts menu markers")
    match = BLOCK_PATTERN.search(text)
    if match is None:
        fail("refusing malformed Battery Alerts menu block")
    block = parse_jsonc("{\n" + match.group("body") + "\n}")
    if set(block) != {ENTRY_ID} or not isinstance(block[ENTRY_ID], dict):
        fail("refusing a marker block not owned by Battery Alerts")
    if block[ENTRY_ID].get("action") not in (ACTION, LEGACY_ACTION):
        fail("refusing a marker block not owned by Battery Alerts")
    if text.count(f'"{ENTRY_ID}"') != 1:
        fail("refusing a Battery Alerts entry outside its marker block")
    return block[ENTRY_ID]


def menu_directory(create=True):
    home = os.environ.get("HOME")
    if not home or not os.path.isabs(home):
        fail("HOME must be an absolute path")
    home_fd = os.open(home, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        if os.fstat(home_fd).st_uid != os.getuid():
            fail("refusing an unowned HOME")
        config = _checked_dir(home_fd, ".config", create=create)
        try:
            omarchy = _checked_dir(config, "omarchy", create=create)
            try:
                return _checked_dir(omarchy, "extensions", create=create)
            finally:
                os.close(omarchy)
        finally:
            os.close(config)
    finally:
        os.close(home_fd)


def save_backup(directory_fd, original):
    atomic_replace(directory_fd, BACKUP_NAME, original, limit=65536)


def read_menu(directory_fd):
    return read_regular(directory_fd, MENU_NAME, limit=65536)


def replace_menu(directory_fd, value):
    atomic_replace(directory_fd, MENU_NAME, value.encode("utf-8"), limit=65536)
