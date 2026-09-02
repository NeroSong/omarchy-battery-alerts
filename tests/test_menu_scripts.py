from pathlib import Path
import os
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[1]
install = repo / "bin/install-menu-entry"
uninstall = repo / "bin/uninstall-menu-entry"

with tempfile.TemporaryDirectory() as temp:
    home = Path(temp)
    menu = home / ".config/omarchy/extensions/omarchy-menu.jsonc"
    menu.parent.mkdir(parents=True)
    original = '{\n  // Keep me.\n  "personal": {"label": "Personal"}\n}\n'
    menu.write_text(original)
    env = dict(os.environ, HOME=str(home))

    subprocess.run([install], check=True, env=env)
    installed = menu.read_text()
    assert installed.count("battery-alerts:start") == 1
    assert "omarchy-shell shell summon nerosong.battery-alerts" in installed
    assert '"personal"' in installed

    subprocess.run([install], check=True, env=env)
    assert menu.read_text() == installed

    subprocess.run([uninstall], check=True, env=env)
    restored = menu.read_text()
    assert "battery-alerts:start" not in restored
    assert '"personal"' in restored

print("Menu script tests passed")
