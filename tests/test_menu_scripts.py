from pathlib import Path
import json
import os
import re
import stat
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[1]
install = repo / "bin/install-menu-entry"
uninstall = repo / "bin/uninstall-menu-entry"


def run(script: Path, home: Path, check: bool = True):
    env = dict(os.environ, HOME=str(home))
    return subprocess.run([script], check=check, env=env, capture_output=True, text=True)


def parse_jsonc(value: str):
    without_comments = re.sub(r"^\s*//[^\n]*(?:\n|$)", "", value, flags=re.MULTILINE)
    without_trailing_commas = re.sub(r",(\s*[}\]])", r"\1", without_comments)
    return json.loads(without_trailing_commas)

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    menu.parent.mkdir(parents=True)
    original = '{\n  // Keep me.\n  "personal": {"label": "Personal"}\n}\n'
    menu.write_text(original)
    menu.chmod(0o600)
    run(install, home)
    installed = menu.read_text()
    assert installed.count("battery-alerts:start") == 1
    assert "omarchy-shell shell summon nerosong.battery-alerts" in installed
    assert '"personal"' in installed
    assert menu.with_name(menu.name + ".battery-alerts.bak").read_text() == original
    assert stat.S_IMODE(menu.stat().st_mode) == 0o600

    run(install, home)
    assert menu.read_text() == installed

    run(uninstall, home)
    restored = menu.read_text()
    assert "battery-alerts:start" not in restored
    assert '"personal"' in restored
    assert stat.S_IMODE(menu.stat().st_mode) == 0o600
    assert parse_jsonc(restored)["personal"]["label"] == "Personal"

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    run(install, home)
    installed = menu.read_text().replace(
        '  }\n  // battery-alerts:end\n',
        '  },\n  // battery-alerts:end\n  "after": {"label": "After"}\n',
    )
    menu.write_text(installed)
    assert set(parse_jsonc(installed)) == {"setup.battery-alerts", "after"}
    run(uninstall, home)
    assert parse_jsonc(menu.read_text()) == {"after": {"label": "After"}}

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    menu.parent.mkdir(parents=True)
    manual = '{\n  "setup.battery-alerts": {"label": "Battery Alerts"}\n}\n'
    menu.write_text(manual)
    result = run(install, home)
    assert "already exists" in result.stdout
    assert menu.read_text() == manual

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    run(install, home)
    assert "battery-alerts:start" in menu.read_text()
    run(uninstall, home)
    assert "battery-alerts:start" not in menu.read_text()

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    menu.parent.mkdir(parents=True)
    invalid = "not jsonc\n"
    menu.write_text(invalid)
    result = run(install, home, check=False)
    assert result.returncode != 0
    assert menu.read_text() == invalid

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    menu.parent.mkdir(parents=True)
    wrapped = '{\n  "items": {"personal": {"label": "Personal"}}\n}\n'
    menu.write_text(wrapped)
    result = run(install, home, check=False)
    assert result.returncode != 0
    assert "add the documented entry manually" in result.stderr
    assert menu.read_text() == wrapped

print("Menu script tests passed")
