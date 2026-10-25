# Tasks

Implementation starts only after explicit apply authorization, on a new branch from main. Do not port the resource-policy runtime or raise budgets to satisfy these checks.

## 1. Direct circuit access through the real guest boundary

- [ ] 1.1 Simplify `scripts/services/logic.lua` input reads and the circuit-specific peripheral/sandbox handoff. Add compiled-guest regressions for 64/65/150/1,100 native signals, long names, native categories, optional fields, red/green separation, fresh getter calls and unchanged native ordering. Verify complete tail access and nested mutation isolation without generic Data ceilings, and update the read contract in player/API documentation.
- [ ] 1.2 Read own output from native configuration and remove circuit slot/name/owned-bank gates, sorting and the reusable output mirror. Preserve caller validation, native capacity, staging/rollback and ownership. Verify 65/150/1,100-entry output/readback where native capacity permits, omitted-default round trips, duplicates, invalid counts, foreign emitters, multiple writers and power/path/stop cleanup; update the output docs and Reference.

## 2. Subscriptions without an internal inventory policy

- [ ] 2.1 Keep subscription-count admission at registration; remove filter/sampled-device ceilings and cached registration baselines. Implement unsorted effective-identity comparison with only required previous/event state. Verify initial, unchanged/reordered, disappeared, connected-empty and power-resync cases, plus a 1,100-identity filter built by non-growing edits of a native array; update subscription documentation.
- [ ] 2.2 Complete trusted circuit registration/event preparation and compiler/scheduler delivery without generic payload limits. Preserve queue entry/envelope overflow behavior and byte-counter consistency. Verify full large-event delivery, cross-subscriber/baseline isolation, unsubscribe/power cleanup, genuine backlog overflow, forged guest events, mutated caller requests, and unchanged ordinary state/other-event limits; document the circuit payload accounting exception.

## 3. Inspector and saved-state compatibility

- [ ] 3.1 Adapt `scripts/ui/peripheral-inspector{,-model}.lua` to direct native observations and optional identities without sorting, revalidation or hidden tails. Extend existing inspector tests for all represented categories, exact counts, both colors, own output, selection/scroll retention and more than 1,024 accessible entries; update help and affected examples in the same change.
- [ ] 3.2 Retire obsolete circuit caches during synchronized lifecycle handling without replay or destructive snapshot rewriting. Add cold/upgrade coverage retaining valid owners, registrations and a large pending event, including older expanded/defaulted records; verify first post-load reads are fresh and malformed-registration safeguards remain. Document compatibility and backup/rollback guidance.

## 4. Integrated acceptance

- [ ] 4.1 Build the exact candidate and run the affected native logic, recipe-signal, inspector, runtime, shell, lifecycle and budget regressions in base and Space Age on 2.0.77. Include the focused large-circuit fixture, separate-process pending-event reload and prior-release upgrade. Verify complete markers, zero exits, no forced cleanup and archive/source correspondence; preserve all failures outside git.
- [ ] 4.2 Exercise the large inspector in both full clients, inspect captures and verify tail access, fresh updates, optional-field display, close/power/authority behavior and clean exits. Compare matched baseline/candidate small-controller and large-circuit observations under unchanged settings; report actual tick/memory evidence without claiming a universal native bound. Run the existing monitor animation regression to catch shared-runtime collateral changes.
- [ ] 4.3 Reconcile the Logic API companion, shared Data wording, player docs, Reference, examples and actual `getLimits()` output. Run existing documentation/static checks and strict OpenSpec validation; verify no obsolete circuit ceilings/cache state, runtime rewrite, unrelated policy changes or game/evidence files enter the patch. Keep implementation tasks unchecked until their real verification passes.
