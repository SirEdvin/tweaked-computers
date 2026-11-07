# Factoriopedia interface delta

## MODIFIED Requirements

### Requirement: Existing resource bounds without a new catalogue quota
Catalogue operations SHALL consume the retained shared host-work and Data allowances without renewing credits or adding a feature-specific name-count cap. A list or record that cannot fit SHALL refuse explicitly without a prefix, cursor or silent truncation. `getLimits()` SHALL report current common limits and remain available regardless of electrical coverage. Successful lists SHALL not imply arbitrary modpack-size support.

#### Scenario: Catalogue exceeds shared result capacity
- **WHEN** the complete name array exceeds an existing Data allowance and sufficient work remains to detect that refusal
- **THEN** the list call raises `E_LIMIT`, publishes no partial array and leaves subsequent individually affordable exact-name queries possible with fresh work credits.

#### Scenario: Work is exhausted
- **WHEN** repeated calls exhaust retained shared host-work credits
- **THEN** the current fatal budget behavior remains in effect without renewed credits, retry loops or reclassification as an empty catalogue.

#### Scenario: Unrelated catalogue growth
- **WHEN** unrelated installed prototypes increase but an exact-name lookup's record is unchanged
- **THEN** that lookup does not enumerate unrelated prototypes or charge their count as its metadata work.
