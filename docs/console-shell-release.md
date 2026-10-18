# Tweaked Computers 0.1.8 — ALPHA

## Live Console, without replacing your controller

Open a powered computer with an empty cursor and Ctrl + left-click, select
Console, then type or paste one Lua line and press Enter or Execute. Commands
have real factory effects; this is not a dry run. Your saved program may keep
running beside the prompt. There is no command history, OS, gameplay filesystem,
multiline continuation or unrestricted Lua.

The computer shares save-backed scratch globals between authorized viewers.
Scalars, plain tables with scalar keys, aliases/cycles, authentic peripheral
facades and captured peripheral methods survive commands, close/reopen and
save/load. Each call rechecks the original device identity and wire authority.
Unfinished native input/carets remain private to each viewer. Local functions
can compute within a line, but user functions/closures cannot be retained.

Successful Run/Apply, explicit Stop or confirmed Reset Shell clear scratch
values and cancel the old shell session. Reset Shell leaves saved source,
application state and the running program alone. Power loss retains committed
values but cancels pending commands and clears shell-owned outputs. Mining,
cloning and blueprint/settings transport do not copy shell experiments to a new
physical computer. See the [Console guide](player/console.md) for the exact
lifetime, retained-value limits and live peripheral example.

A failed command keeps the previously committed scratch graph, not an imaginary
rollback of earlier effects: successful monitor, KV, logic, configurator,
application-state writes and printed output remain. Shell/program scheduling
shares the existing computer ledger; shell commands do not get a second work
budget. Handler registration and subscriptions remain saved-program features.

The release also fixes missing syntax explanations/EOF positions, Console Follow
layout settlement and stale-reset feedback. No production safety ceilings are
increased. It retains the 0.1.6 live Map budget settings and the published 0.1.7
Foundry artwork, connected-subpixel chart and independent monitor background/glyph
reuse. Since alpha-0.1.7 the additional non-shell commits are history-preserving
merges of those already-shipped monitor/budget branches, not another budget or
renderer feature rollout.

## Installation and upgrade

Install **0.1.8 ALPHA** through the existing in-game Tweaked Computers listing,
or use `tweaked-computers_0.1.8.zip` from the matching GitHub prerelease. GitHub's
automatic source archives are not installable mod ZIPs. Target: Factorio **2.0.77**,
base alone or optional Space Age. Later engines and arbitrary mod combinations
are not claimed verified.

**Back up saves and keep their matching old ZIP before upgrading.** Load a copy
first. Existing saved programs retain their handler language restrictions; the
new scratch globals are Console-only. Do not downgrade a save containing shell
state in place. Unknown saved formats are retained for recovery, not erased.
Historical pre-0.1.5 monitor regrouping can still merge walls and clear content
when character geometry changes; retain the pre-upgrade save for rollback.

## Acceptance and honest boundaries

SH2 independently reviewed the implementation merged through PR #7 at
`a82e21390eb832bfb657f75add6f0e68eae5975d`. Its accepted, unpublished 0.1.7-version
candidate has SHA-256
`56dac45fd33be1f79eb6e3e750250cce09ee890266c9d7f39c4a7e60ecdff501`;
it is not a replacement for the published alpha-0.1.7 ZIP.

That evidence comprises 28 packaged base/Space Age mode cases, 36 separate-process
cold phases and five final full-client runs with normal shutdown. Native Console
input, paste/caret, Enter/Execute, close/reopen, live monitor effects beside a
running program, Follow, diagnostics and confirmed reset passed representative
size/scale cases. Two actual base clients verified late joining after effects,
shared aliases/cycles/captured methods, independent drafts/carets, conflicting
submissions, stale reset refusal and separate-process cold server resume without
observed desync or effect replay. Command history was explicitly removed after
the focused-arrow feasibility gate; it is not an unfinished promised feature.

SH3 binds this release to that evidence by comparing all production payload bytes,
then repeats packaged shell/runtime/budget/editor/ownership/cold checks, a populated
published-0.1.7 save upgrade and a final versioned native-client shell smoke.
The matching GitHub prerelease carries exact archive checksums, the final
verification receipt and selected native/multiplayer evidence. Package metadata
retains the conservative general `client_verified: false`: the focused evidence
here is not universal device/client certification.

Clients used llvmpipe software rendering: appearance/input evidence, not a GPU
FPS or real-time latency guarantee. Connected joining was tested in base, not
Space Age. Representative 800×480/1280×720 and selected 75%/100% UI scales are not
exhaustive platform/IME coverage. Native clipboard normalization precedes mod
ingress; commands are never submitted automatically. Native wire/touch delivery,
audible playback and arbitrary busy-factory smoothness remain unverified.

The [implementation fixture guide](console-shell-validation.md) documents the
reproducible packaged/client procedures. The player guide and complete Lua API
remain the authoritative user-facing reference; generated developer OpenWiki is
not manually refreshed by this release.
