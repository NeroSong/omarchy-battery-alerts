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
  if (critical >= warning) {
    if (warning <= 5) warning = 6
    critical = warning - 1
  }

  return {
    version: 1,
    warningThreshold: warning,
    criticalThreshold: critical
  }
}

function adjustWarning(settings, value) {
  var current = normalizeSettings(settings)
  var warning = clampThreshold(value, current.warningThreshold)
  var critical = current.criticalThreshold

  if (warning <= critical) {
    if (warning <= 5) {
      warning = 6
      critical = 5
    } else {
      critical = warning - 1
    }
  }

  return { warningThreshold: warning, criticalThreshold: critical }
}

function adjustCritical(settings, value) {
  var current = normalizeSettings(settings)
  var warning = current.warningThreshold
  var critical = clampThreshold(value, current.criticalThreshold)

  if (critical >= warning) {
    if (critical >= 90) {
      warning = 90
      critical = 89
    } else {
      warning = critical + 1
    }
  }

  return { warningThreshold: warning, criticalThreshold: critical }
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
    adjustWarning: adjustWarning,
    adjustCritical: adjustCritical,
    batteryPercentage: batteryPercentage,
    isDischarging: isDischarging,
    nextAlert: nextAlert
  }
}
