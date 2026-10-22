# logic-handler resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/logic-handler/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

Existing `readSignal(input, signal)`, `readSignals(input)`, `getInputStatus()`, `getOutput()`, `setOutput(signals)`, `clearOutput()`, `subscribe(options, handler_name)` and `unsubscribe(subscription_id)` keep their argument and return shapes. Reads and subscription filters have no fixed identity-count ceiling. Output capacity comes from actual native section capacity and aggregate resource admission, not 64 slots. Native identities and signed counts are validated before any output replacement.

`readSignals` still returns one complete sorted defensive `Signal[]`, never a cursor or partial array. Snapshot capture records one native observation; conversion/sorting can resume without mixing later values. `getOutput` describes only this device's bank. Inspector acquisition uses the same complete native read path without charging a fictitious guest per-call Data ceiling.

Signal event payloads gain optional `resync=true` and `dropped_since_previous` after a lost delivery or sampling gap. The next admitted resync contains a full current snapshot; missed intermediate pulses cannot be reconstructed. Work pressure defers sampling without faulting subscribers. A single too-large queue event is dropped whole and counted, never truncated. Filter evaluation does not require passing an arbitrary full-network slot gate. `getLimits()` uses policy version 2 and omits `signal_slots` and `filter_signals`.
