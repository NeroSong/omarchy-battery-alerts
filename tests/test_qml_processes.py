from pathlib import Path


repo = Path(__file__).resolve().parents[1]
service = (repo / "Service.qml").read_text()
panel = (repo / "Panel.qml").read_text()

for source in (service, panel):
    assert '"/usr/bin/timeout", "--kill-after=1s", "5s"' in source
    assert '"/usr/bin/omarchy-notification-send"' in source
    assert '[safeJsonPath,' not in source
    assert '"/usr/share/omarchy/bin/omarchy-notification-send"' not in source

assert "pendingSettings" in panel
assert "onExited: function(exitCode)" in panel
assert "pendingState" in service

print("QML process-boundary tests passed")
