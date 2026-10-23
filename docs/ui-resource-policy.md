# Resource-policy UI lane

## Implemented presentation

- The existing workspace status label reads `scripts/runtime/resource-policy.status(record, tick)` on the host, not through a guest command. Its tooltip contains the complete resource report and the cumulative loss counter, including saturation and last-drop details. A missing shared provider is shown as **Resource status unavailable**, never zero usage.
- Recoverable refusal is distinct from fault. Complete refusal/active/Console diagnostics remain selectable in the existing Console detail box. Changing telemetry does not rewrite this box, the source widget, or the command field. Failed Console admission retains the input and keeps the diagnostic in that detail box.
- Reference search and host discovery descriptors no longer have UI field/count cuts. Source-line selection no longer depends on the removed source-byte limit.
- Logic trays render every supplied signal, with independent red/green count and sample tick. Pending, unavailable without a sample, retained stale, disconnected, and empty samples remain distinguishable. Native widget identities and independent tray scrolling are preserved. Construction admission scales with the supplied inventory; no output/subscription behavior changes.

`editor-model.retention(player_index)` is read-only accounting for the parent policy integration. It returns no invented limit when `draft_storage_bytes` is absent. **Draft admission is not complete in this lane:** the attempted mutation batch was denied by the tool approval timeout and was not retried. Existing eight-document/source/command gates still need authorized replacement, pre-admission on every edit/save/rebase/reload/recovery path, and durable command drafts. Do not mark task 10.4 complete from this patch.

## Fixtures

`tests.ui_resource_status` uses explicitly labelled presentation doubles; it checks complete status/refusal formatting, saturation, no mutation, and draft accounting. `tests.editor_workspace` checks unchanged source/diagnostic widget text while resource values and loss totals change. Neither is proof of runtime counter persistence or a busy guest lane.

The existing `tests.ui_live_client_engine` fixture adds:

```lua
/c remote.call("tc-ui1", "signals", 150)
/c remote.call("tc-ui1", "open", "logic")
```

This constructs two **real** constant-combinator networks using native item signals, with different red/green values. `ui1-state.json` records native inventories separately from the inspector's acquired inventories and sample ticks; it also reports the actual policy status and retained-draft count when available. It does not supply fabricated inspector/status data. Use a smaller count only for a separately labelled compatibility test, never as the 150-signal acceptance substitute.

Prepare via `tools/shell_client.py --fixture tests.ui_live_client_engine` using the canonical absolute `gameitself` distribution path. Run only in a private display/config/mod/save tree. Prewrite input drivers before taking `native.lock`, bound the client case, request normal window close, and release the lock before inspection/editing or another case.

## Integration gates still required

1. Real shared resource provider plus settings; waiting/refusal under a busy guest, full queues, Stop/Run/reset/cold loss-counter persistence, log-warning eviction and exact-integer saturation. No runtime counter was fabricated in the native client.
2. Parent input acquisition without the baseline signal limit: the actual 150-red/150-green fixture currently receives `E_LIMIT`. Verify all 150 identities/counts, independent freshness, scrolling and unchanged output/subscriptions after integration.
3. Authorized draft admission work and real >8-document, lower/raise settings, visible refusal, reduction/forget, close/reopen and cold-retention workflows.
4. Space Age native client and connected multiplayer checks. Packaged headless/mock GUI passes are not those gates.

The separate Ctrl-click behavior is intentionally unchanged.
