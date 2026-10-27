# Radar modem Lua API v1: attachment and dormancy amendment

This change-local API specification supplements the existing `openspec/specs/radar-modem/lua-api.md`. It changes enrollment and work lifetime, not the guest method surface. All unchanged payload, validation, queue, ordering, authority and resource-admission contracts continue to apply.

## Unchanged methods

| Exact dot-call signature | Returns |
| --- | --- |
| `open(channel)` | zero values |
| `isOpen(channel)` | boolean |
| `close(channel)` | zero values |
| `closeAll()` | zero values |
| `transmit(channel, replyChannel, payload)` | zero values |
| `isWireless()` | boolean, true for supported tiers |
| `getLimits()` | defensive limits record |

No tracking switch, wake/sleep API, new setting, new limit, remote-discovery method or event type is introduced. Channel domains, payload limits, return arity and dot-call validation remain unchanged.

## Computer-rooted discovery

`peripheral.find("modem", wire)`, `peripheral.wrap(name, wire)`, `peripheral.call` and metadata require the same explicit local red/green path as before. Direct cables and transitive paths through supported network connectors qualify. The whole path keeps one color and the computer's exact force and surface. Unsupported vanilla relays, factory input/output/target roles, ghosts, merged-display adjacency and hidden radar-origin links do not qualify.

Placement, cloning, blueprint revival or wiring to a standalone peripheral does not enroll a radar. First valid computer-rooted discovery/adoption enrolls it; no player replacement is required. Discovery can retain its existing `E_NETWORK_PENDING`, `E_LIMIT` and `E_CAPACITY` outcomes when complete proof or safe enrollment is unavailable. It must not return a successful partial inventory.

A stopped, faulted or unpowered computer does not erase a physical cable or the radar's shared state. Physical topology remains power-independent; guest execution, Console authority and powered modem methods retain their separate existing checks.

## Dormant identity and channels

An enrolled radar disconnected from every computer retains its opaque name and shared channels as passive saved data. It has no recurring availability checks, generic tick visits or dormant-pool scans. It is not enumerated as a radio receiver candidate merely because an open-channel record exists.

An old wrapper does not grant access during detachment: calls still need a current selected-color path and otherwise fail with the existing unreachable/pending diagnostic. Reconnecting the exact entity within the same force and surface restores its name and channels. Same-radar access from multiple computers and both colors continues to share one channel set.

Stopping a program is not detachment and does not close channels. Replacing, cloning, mining and rebuilding still do not transfer identity or channel state. An observed scope mismatch must invalidate old bindings and clear the channel set before participation in the new scope, including when the record was dormant.

## Messages and ordering

A dormant radar neither receives nor buffers traffic. Routing starts from eligible receiving computers and their current local paths, rather than an enumeration of all remembered radar records. Existing candidate/delivery/throughput ceilings still apply to the relevant connected routing plan; dormant records cannot consume candidate slots.

A message already accepted into a computer queue remains a data snapshot after radar detachment, channel closure or radar removal. The computer's own stop, fault, removal and power-loss queue rules remain unchanged. Reconnection never replays missed radio traffic, startup or transmission effects. Both-color deduplication and computer/radar/subscription publication ordering remain unchanged.

## Upgrade and reload

Installing the implementation over a supported older save must exclude disconnected legacy radar records from recurring work before the first ordinary tick. Their existing identities and channels remain recoverable on later same-scope reconnection. Ordinary cold reload preserves this exclusion without a periodic legacy/dormant sweep or authoritative writes in `on_load`.

Passive data still contributes to memory and save serialization; the performance promise is absence of per-tick work proportional to disconnected-radar count. Native Factorio radar simulation is unaffected.

## Required API acceptance

Exercise a direct and transitive attachment, both colors and multiple computers, stopped/unpowered computer attachment, last-path detachment, same-entity reconnection before and after cold reload, dormant destruction and scope change, and legacy-save migration with retained channels. Verify queued-event preservation/no replay and unchanged signatures/errors through actual guest/Console paths. Pair functional cases with no-dormant-scan assertions and native timing evidence; a documentation change alone proves none of these outcomes.
