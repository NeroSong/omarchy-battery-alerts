function clampThreshold(value, fallback) {
  var parsed = Math.round(Number(value))
  if (!isFinite(parsed)) parsed = fallback
  return Math.max(5, Math.min(90, parsed))
}

function normalizeSettings(value) {
  var raw = value && typeof value === "object" ? value : {}
  var warning = clampThreshold(raw.warningThreshold, 50)
  var critical = clampThreshold(raw.criticalThreshold, 30)

  // Keep both controls usable even when a hand-edited settings file contains
  // an invalid pair. The panel applies the same invariant before saving.
  if (critical > warning) critical = warning

  return {
    version: 1,
    warningThreshold: warning,
    criticalThreshold: critical
  }
}

function batteryPercentage(device) {
  if (!device || !device.isPresent) return -1
  return Math.round(Number(device.percentage || 0) * 100)
}

function isDischarging(device, onBattery, dischargingState) {
  return !!(device && device.isPresent && onBattery
    && device.state === dischargingState)
}

function nextAlert(level, onBattery, discharging, settings, warningSent, criticalSent) {
  var normalized = normalizeSettings(settings)

  if (!onBattery || level < 0) {
    return { alert: "", warningSent: false, criticalSent: false }
  }

  // UPower may briefly report PendingDischarge or Unknown around power-source
  // transitions. Preserve the current discharge-session state so that a
  // transient reading cannot repeat an alert.
  if (!discharging) {
    return {
      alert: "",
      warningSent: warningSent,
      criticalSent: criticalSent
    }
  }

  if (level <= normalized.criticalThreshold) {
    return {
      alert: criticalSent ? "" : "critical",
      // Reaching critical first must not produce a delayed 50% warning later.
      warningSent: true,
      criticalSent: true
    }
  }

  if (level <= normalized.warningThreshold) {
    return {
      alert: warningSent ? "" : "warning",
      warningSent: true,
      criticalSent: criticalSent
    }
  }

  return {
    alert: "",
    warningSent: warningSent,
    criticalSent: criticalSent
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    clampThreshold: clampThreshold,
    normalizeSettings: normalizeSettings,
    batteryPercentage: batteryPercentage,
    isDischarging: isDischarging,
    nextAlert: nextAlert
  }
}
