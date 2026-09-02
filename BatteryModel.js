function clampThreshold(value, fallback) {
  var parsed = Math.round(Number(value))
  if (!isFinite(parsed)) parsed = fallback
  return Math.max(5, Math.min(90, parsed))
}

function normalizeSettings(value) {
  var raw = value && typeof value === "object" ? value : {}
  var warning = clampThreshold(raw.warningThreshold, 30)
  var critical = clampThreshold(raw.criticalThreshold, 20)

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
  var percentage = Number(device.percentage)
  if (!isFinite(percentage) || percentage < 0) return -1
  return Math.max(0, Math.min(100, Math.round(percentage * 100)))
}

function isDischarging(device, onBattery, dischargingState) {
  return !!(device && device.isPresent && onBattery
    && device.state === dischargingState)
}

function nextAlert(level, onBattery, discharging, settings, warningSent, criticalSent) {
  var normalized = normalizeSettings(settings)
  var numericLevel = Number(level)

  // A temporarily unavailable display device must not start a new discharge
  // session and repeat alerts when UPower catches up.
  if (!isFinite(numericLevel) || numericLevel < 0) {
    return {
      alert: "",
      warningSent: warningSent,
      criticalSent: criticalSent
    }
  }

  if (!onBattery) {
    return { alert: "", warningSent: false, criticalSent: false }
  }

  level = numericLevel

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
      // Reaching critical first must not produce a delayed normal warning.
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

function normalizeReadFailureState(value) {
  var raw = value && typeof value === "object" ? value : {}
  var startedValue = raw.readFailureStartedAt !== undefined
    ? raw.readFailureStartedAt : raw.startedAt
  var lastValue = raw.readFailureLastAt !== undefined
    ? raw.readFailureLastAt : raw.lastAt
  var notifiedValue = raw.readFailureNotified !== undefined
    ? raw.readFailureNotified : raw.notified
  var startedAt = Number(startedValue || 0)
  var lastAt = Number(lastValue || 0)
  if (!isFinite(startedAt) || startedAt < 0) startedAt = 0
  if (!isFinite(lastAt) || lastAt < startedAt) lastAt = 0
  return {
    startedAt: startedAt,
    lastAt: lastAt,
    notified: notifiedValue === true
  }
}

function nextReadFailureState(level, now, value) {
  var state = normalizeReadFailureState(value)
  var numericLevel = Number(level)

  if (isFinite(numericLevel) && numericLevel >= 0) {
    return { startedAt: 0, lastAt: 0, notified: false, notify: false }
  }

  var current = Number(now)
  if (!isFinite(current) || current <= 0) current = 1

  // A gap longer than 2.5 check intervals means the shell was suspended or
  // stopped; time when no read was attempted does not count toward 10 minutes.
  if (state.lastAt <= 0 || current < state.lastAt
      || current - state.lastAt > 150000) {
    state.startedAt = current
    state.notified = false
  }
  state.lastAt = current

  var notify = !state.notified && current - state.startedAt >= 600000
  if (notify) state.notified = true

  return {
    startedAt: state.startedAt,
    lastAt: state.lastAt,
    notified: state.notified,
    notify: notify
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
    nextAlert: nextAlert,
    normalizeReadFailureState: normalizeReadFailureState,
    nextReadFailureState: nextReadFailureState
  }
}
