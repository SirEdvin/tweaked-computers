# Spec Delta

## ADDED Requirements

### Requirement: Combinator-style read-only signal panel
The Logic Handler inspector SHALL present one Input signals area and an adjacent Output signals area at normal supported widths. Red and green input entries SHALL appear together in the input area using native-style wire-colored slot backgrounds, grouped by wire with textual identification. The UI SHALL NOT expose expressions, conditions, signal pickers, count editors or output toggles.

#### Scenario: Both input colors carry signals
- **WHEN** red and green input networks both contain signals
- **THEN** both sets are visible together without a wire-selector tab, with red-backed and green-backed slots in the shared input area
- **AND** labels or tooltips identify wire origin without relying only on color.

#### Scenario: Same identity on both wires
- **WHEN** the same signal identity has a value on red and a different value on green
- **THEN** each wire's contribution remains distinguishable in its own colored slot rather than being collapsed into an unlabeled sum
- **AND** the guest API still requires an explicit single input color.

#### Scenario: Small supported window
- **WHEN** resolution or GUI scale requires a narrower layout
- **THEN** the signal regions reflow or scroll without hiding close/copy controls or losing the distinction between inputs and outputs.

### Requirement: Faithful signal identities and counts
Signal slots SHALL preserve type, prototype name, quality and signed count, including recipe signals distinct from same-named item signals. Exact counts and identity details SHALL be accessible even if slot overlays abbreviate large values. Disconnected inputs, connected networks with no nonzero signals, unavailable samples and capacity failures SHALL be distinguishable.

#### Scenario: Quality and namespace distinctions
- **WHEN** normal and higher-quality versions of an item, or an item and recipe with the same name, appear together
- **THEN** they remain separate entries with appropriate icons and unambiguous identity details.

#### Scenario: Negative or large values
- **WHEN** a sampled signal has a negative count or a value near a signed-32-bit boundary
- **THEN** the inspector preserves the exact value in its detail/tooltip presentation rather than rounding the authoritative count.

#### Scenario: Empty versus disconnected
- **WHEN** one input color is connected but has no nonzero signals and the other is disconnected
- **THEN** the shared input region distinguishes those states without fabricating zero-valued slots or reporting a failed query as empty.

### Requirement: Own output contribution rather than network totals
The Output signals area SHALL show the handler's own emitted bank, with an explicit label that it is shared across its red and green output wires. It SHALL NOT attribute signals from other emitters on an output network to this handler. Inspection SHALL NOT write a bank, claim ownership or change fail-safe cleanup behavior.

#### Scenario: Another emitter shares the output wire
- **WHEN** an unrelated device emits signals onto a network connected to the handler's output
- **THEN** the inspector shows only this handler's contribution, not the combined output-network totals.

#### Scenario: Writer or handler loses authority or power
- **WHEN** existing fail-safe reconciliation clears the handler's output
- **THEN** the next successful inspector update shows the cleared bank without replaying a write or restoring the former owner.

### Requirement: Bounded live signal observation
The open signal panel SHALL throttle observations, label per-wire ticks or pending/stale state, and publish only complete red/green pairs spanning at most 30 ticks. Separate-tick samples SHALL NOT be described as atomic. Incomplete pairs SHALL remain private and expire. Inspection SHALL NOT create guest subscriptions or promise pulse capture. Closing SHALL stop inspection without changing program subscriptions or output ownership.

#### Scenario: Signals change with the inspector open
- **WHEN** powered input values change and inspection work is admitted
- **THEN** the panel updates its displayed signals without reopening the window, altering subscriptions or changing the wire-selection contract.

#### Scenario: Query exceeds supported signal capacity
- **WHEN** a native input exceeds the existing supported signal limit or work admission fails
- **THEN** the panel reports the relevant limit/pending state rather than presenting a truncated signal set as complete or resetting logic output.
