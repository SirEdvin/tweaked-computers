---
type: service
title: Signal sampling and output ownership
description: Typed logic input normalization, sampled named subscriptions, mirrored native output banks and exact writer/run/path cleanup.
tags: [logic, signals, sampling, ownership, safety]
sources:
  - id: openwiki-source-199ebbbf763b15ba60eb9147
    resource: repo://scripts/device-definitions.lua
  - id: openwiki-source-2e3e95454d6dba095a611b9f
    resource: repo://scripts/runtime/sandbox.lua
  - id: openwiki-source-e9d0ec370bb6b76beda6ccff
    resource: repo://scripts/services/logic.lua
  - id: openwiki-source-84bfcd6a80f737a0b75f8c1c
    resource: repo://scripts/services/peripheral.lua
generated: { by: "hermes", at: "2026-10-29T22:50:29.161Z" }
verified:
  - by: openwiki/0.7.1
    at: 2026-10-29T22:50:29.161Z
---

# Signal sampling and output ownership

## Three physical roles, two independent color choices

The visible logic shell is Network and owns separate Input and Output pads plus private power. Network color authorizes which computer can call the peripheral; an explicit input selector (`red` or `green`) chooses the sampled Input wire. Combined input is rejected, including retained obsolete subscriptions before dispatch. These choices are not interchangeable. Output is one native constant-combinator bank visible on both output colors, not independent red/green programs. Sampling checks `lifecycle.has_power(rec)` rather than the now-passive body's energy.

`logic.lua` validates caller signal identities against the closed native prototype families and quality, interpreting omitted type/quality as item/normal without forcing those fields into returned native data. Output requires a dense array, rejects duplicate identities and wildcard/unknown signals, checks signed int32 counts and removes zeros. Native output indices retain the engine's uint16 range.

Full input reads return the fresh engine `get_signals` inventory for the selected connector after endpoint checks and fixed wrapper work, without a guessed prototype-universe scan, arbitrary input count ceiling, sorting or combined-color inventory. Single-signal reads use native `get_signal`. The sandbox's closed Logic result path transfers these detached native arrays; ordinary caller Data, output validation and retained queue limits remain separate boundaries.

## Output publication and writer identity

`setOutput` validates the whole bank and obtains current physical discovery authority plus witness path. Native publication creates an inactive section, assigns filters and reads every identity/count back, then removes old sections and activates the replacement. Success records exact execution-principal, binding-wire and witness-path ownership. The single bank's last successful write owns it; this is not a persistent lock or a separate bank per writer/color.

On native failure the adapter attempts to republish the old bank. Failed restoration retains `output_recovery` and clears physical output/owner. Invalid input or admission refusal before mutation must not publish a partial bank. `clearOutput` is an authorized write of an empty bank, not a universal request to clear somebody else's arbitrary device.

The lifecycle output-authority pass runs independently of guest callback dispatch and slower topology notifications. It checks writer/run activity and current physical witness, recomputing if necessary. Missing proof or work deferral clears the bank rather than trusting cached positive topology. Runtime Stop/fault/activation/removal cleanup clears only banks owned by that exact computer/run. Logic power loss/removal always clears its own physical bank, even if the source no longer compiles or exists.

## Sampling and event publication

Subscription creation validates input/filter/initial options, reads the current native baseline, and records peripheral generation, binding color and named handler. Run-specific IDs and subscription capacities bound retained work. Default creation does not fabricate an initial change; `initial=true` explicitly compares against an empty/disconnected baseline.

The shared sample phase gathers only required devices/input selections, sorts devices and subscription sequence and reads native inputs once per needed device/color. It computes filtered current/previous values, signal deltas and connection-state changes. Before queue/baseline mutation it reserves a complete copied event containing sample tick, subscription/peripheral binding, initial/resync flags, previous/current/change arrays and connection flags. The baseline advances only when enqueue succeeds. A full event queue faults the run and tears down owned outputs; it does not drop a transient silently.

When sampling/ordering/notification admission cannot guarantee observation, affected running subscribers fault explicitly (`E_BUSY` or the concrete failure) rather than skip an unknown interval. Loss of current binding/generation revokes that subscription and its queued events. Power suspension discards transient queued signal observations, marks resync and preserves the baseline; restoration resamples and emits explicit resynchronization rather than replaying all outage edges. This is current-state recovery, not a historical waveform recorder.

## Extension seams and evidence

Keep caller-input validation separate from fresh native input inventories, preserve input versus discovery wire semantics, and keep output ownership plain and host-cleanable. Register revocation/cleanup during control parsing; cleanup must not depend on executing source. A new sampled event must prepay full publication and update its baseline only after successful queueing.

`tests/logic_engine.lua` covers normalized/quality/int32 behavior, subscriptions, native output readback and cleanup/cold restoration; network and lifecycle fixtures exercise disconnection and source-independent teardown. These are source coverage references, not rerun results for this documentation change. Headless model tick measurements do not establish graphical or end-to-end real-time deadlines.

Related: [network/current authority](../network/discovery-and-authority.md), [shared scheduler/admission](../runtime/scheduling-and-admission.md), [physical teardown](../devices/ownership-and-lifecycle.md), [focused operations](../operations/build-test-and-assets.md).
