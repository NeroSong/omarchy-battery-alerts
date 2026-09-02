const assert = require("node:assert/strict")
const model = require("../BatteryModel.js")

const defaults = { warningThreshold: 30, criticalThreshold: 20 }

assert.equal(model.batteryPercentage(null), -1)
assert.equal(model.batteryPercentage({ isPresent: true, percentage: undefined }), -1)
assert.equal(model.batteryPercentage({ isPresent: true, percentage: 0.305 }), 31)

assert.deepEqual(model.normalizeSettings({}), { version: 1, ...defaults })
assert.deepEqual(
  model.normalizeSettings({ warningThreshold: 20, criticalThreshold: 40 }),
  { version: 1, warningThreshold: 20, criticalThreshold: 19 }
)
assert.deepEqual(
  model.normalizeSettings({ warningThreshold: 2, criticalThreshold: 99 }),
  { version: 1, warningThreshold: 6, criticalThreshold: 5 }
)
assert.deepEqual(
  model.adjustWarning(defaults, 5),
  { warningThreshold: 6, criticalThreshold: 5 }
)
assert.deepEqual(
  model.adjustWarning(defaults, 20),
  { warningThreshold: 20, criticalThreshold: 19 }
)
assert.deepEqual(
  model.adjustCritical(defaults, 90),
  { warningThreshold: 90, criticalThreshold: 89 }
)
assert.deepEqual(
  model.adjustCritical(defaults, 60),
  { warningThreshold: 61, criticalThreshold: 60 }
)

let state = model.nextAlert(80, true, true, defaults, false, false)
assert.equal(state.alert, "")

state = model.nextAlert(50, true, true, defaults, false, false)
assert.equal(state.alert, "")

state = model.nextAlert(30, true, true, defaults, false, false)
assert.deepEqual(state, { alert: "warning", warningSent: true, criticalSent: false })

state = model.nextAlert(29, true, true, defaults, state.warningSent, state.criticalSent)
assert.equal(state.alert, "")

state = model.nextAlert(20, true, true, defaults, state.warningSent, state.criticalSent)
assert.deepEqual(state, { alert: "critical", warningSent: true, criticalSent: true })

state = model.nextAlert(19, true, true, defaults, state.warningSent, state.criticalSent)
assert.equal(state.alert, "")

state = model.nextAlert(25, false, false, defaults, true, true)
assert.deepEqual(state, { alert: "", warningSent: false, criticalSent: false })

state = model.nextAlert(15, true, true, defaults, false, false)
assert.deepEqual(state, { alert: "critical", warningSent: true, criticalSent: true })

state = model.nextAlert(25, true, false, defaults, true, false)
assert.deepEqual(state, { alert: "", warningSent: true, criticalSent: false })

state = model.nextAlert(-1, true, false, defaults, true, true)
assert.deepEqual(state, { alert: "", warningSent: true, criticalSent: true })

state = model.nextAlert(-1, false, false, defaults, true, true)
assert.deepEqual(state, { alert: "", warningSent: true, criticalSent: true })

state = model.nextAlert(Number.NaN, false, false, defaults, true, true)
assert.deepEqual(state, { alert: "", warningSent: true, criticalSent: true })

let failure = {}
const start = 1_000_000
for (let minute = 0; minute < 10; minute += 1) {
  failure = model.nextReadFailureState(-1, start + minute * 60_000, failure)
  assert.equal(failure.notify, false)
}
failure = model.nextReadFailureState(-1, start + 10 * 60_000, failure)
assert.equal(failure.notify, true)
assert.equal(failure.notified, true)

failure = model.nextReadFailureState(-1, start + 11 * 60_000, failure)
assert.equal(failure.notify, false)

failure = model.nextReadFailureState(50, start + 12 * 60_000, failure)
assert.deepEqual(failure, { startedAt: 0, lastAt: 0, notified: false, notify: false })

failure = model.nextReadFailureState(-1, start + 13 * 60_000, failure)
assert.equal(failure.notify, false)
assert.equal(failure.startedAt, start + 13 * 60_000)

failure = model.nextReadFailureState(-1, start + 20 * 60_000, failure)
assert.equal(failure.notify, false)
assert.equal(failure.startedAt, start + 20 * 60_000)

console.log("BatteryModel tests passed")
