import json
import os
from pathlib import Path
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[1]
helper = repo / "bin/safe-json"


def run(home, *args, check=True):
    return subprocess.run([helper, *args], env=dict(os.environ, HOME=str(home)),
                          text=True, capture_output=True, check=check)


with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    written = {"warningThreshold": 30, "criticalThreshold": 20}
    run(home, "write", "settings", json.dumps(written))
    assert json.loads(run(home, "read", "settings").stdout) == written
    settings = home / ".config/omarchy/battery-alerts.json"
    assert settings.is_file() and not settings.is_symlink()

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    target = home / ".config/omarchy/battery-alerts.json"
    target.parent.mkdir(parents=True)
    target.symlink_to("/etc/passwd")
    assert run(home, "read", "settings", check=False).returncode != 0
    assert run(home, "write", "settings", "{}", check=False).returncode != 0

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    target = home / ".config/omarchy/battery-alerts.json"
    target.parent.mkdir(parents=True)
    os.mkfifo(target)
    assert run(home, "read", "settings", check=False).returncode != 0
    assert run(home, "write", "settings", "{}", check=False).returncode != 0

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    target = home / ".config/omarchy/battery-alerts.json"
    target.parent.mkdir(parents=True)
    target.write_bytes(b"{" + b"x" * 9000 + b"}")
    assert run(home, "read", "settings", check=False).returncode != 0

print("Safe JSON tests passed")
