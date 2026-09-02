const assert = require("node:assert/strict")
const model = require("../BatteryModel.js")

const defaults = { warningThreshold: 50, criticalThreshold: 30 }

assert.deepEqual(model.normalizeSettings({}), { version: 1, ...defaults })
assert.deepEqual(
  model.normalizeSettings({ warningThreshold: 20, criticalThreshold: 40 }),
  { version: 1, warningThreshold: 20, criticalThreshold: 19 }
)

let state = model.nextAlert(80, true, true, defaults, false, false)
assert.equal(state.alert, "")

state = model.nextAlert(50, true, true, defaults, false, false)
assert.deepEqual(state, { alert: "warning", warningSent: true, criticalSent: false })

state = model.nextAlert(49, true, true, defaults, state.warningSent, state.criticalSent)
assert.equal(state.alert, "")

state = model.nextAlert(30, true, true, defaults, state.warningSent, state.criticalSent)
assert.deepEqual(state, { alert: "critical", warningSent: true, criticalSent: true })

state = model.nextAlert(29, true, true, defaults, state.warningSent, state.criticalSent)
assert.equal(state.alert, "")

state = model.nextAlert(25, false, false, defaults, true, true)
assert.deepEqual(state, { alert: "", warningSent: false, criticalSent: false })

state = model.nextAlert(25, true, true, defaults, false, false)
assert.deepEqual(state, { alert: "critical", warningSent: true, criticalSent: true })

state = model.nextAlert(25, true, false, defaults, true, false)
assert.deepEqual(state, { alert: "", warningSent: true, criticalSent: false })

console.log("BatteryModel tests passed")
