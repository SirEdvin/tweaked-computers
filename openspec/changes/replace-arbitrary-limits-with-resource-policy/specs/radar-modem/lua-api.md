# radar-modem resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/radar-modem/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

`open`, `isOpen`, `close`, `closeAll`, `transmit`, `isWireless` and `getLimits` retain arities and successful return shapes. Channel and reply-channel inputs accept nonnegative safe integers, rather than only 0..65535. There is no fixed count of open channels, candidates, handler deliveries or transmissions per tick; aggregate storage, queued-work and execution policy apply.

`transmit(channel, replyChannel, payload)` still returns zero values, not an acknowledgement. Before accepting fan-out it freezes a defensive payload and ordered eligible route plan under resource admission. After acceptance it resumes from its next delivery without replay, including after reload. Each destination is revalidated before enqueue. Capacity overflow drops the newest destination event and increments that receiver's diagnostics; no whole-run fault or sender retry is triggered. A destination that becomes unavailable is accounted in the retained delivery outcome/host diagnostics, without granting remote access to receiver state.

Routing completion and eventual handler execution are distinct. A sender's successful return does not promise every event was retained or every recipient ran. Existing force/surface/tier restrictions and per-radar/per-handler deduplication remain. `getLimits()` reports native-safe domains and resource policy, not obsolete 128/64/8/2/16 capacities.
