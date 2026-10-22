# speaker-peripheral resource-policy Lua API amendment

Proposed normative amendment to the existing [API](../../../../specs/speaker-peripheral/lua-api.md), with unchanged details retained there unless explicitly replaced below. Shared execution, status and errors: [api-contract.md](../../api-contract.md).

`playNote(instrument [, volume [, pitch]])` and `playSound(path [, volume])` preserve their successful one-boolean result: true means one engine submission, not audible completion. No call returns false solely because an old note/sound/submission-count allowance was reached. Work pressure suspends before submission; a hard-resource or native refusal raises a recoverable error. No submitted sound is replayed after suspension/load, and no client-dependent state controls deterministic results.

`getInstruments()` and `getNotes(instrument)` return complete inventories without fixed 64/128 limits. `getSounds([prefix [, after]])` keeps its complete sorted cursor-page protocol, but total catalogue size and path lengths have no independent mod ceiling. Page size is configurable retention/UI tuning. All valid pages remain reachable; native validation, local positional audibility and volume/note domains remain unchanged.

`getLimits()` reports policy version 2 and applicable settings, not obsolete catalogue/playback-count maxima. A pending unsubmitted playback call is a normal continuation, not a new background audio player. Stop or authority loss cancels an unsubmitted call; previously submitted audio is not recalled.
