# Program editor delta

## MODIFIED Requirements

### Requirement: Usable native GUI and contextual help
The editor SHALL support native text entry/paste, visible keyboard focus, scalable layout, discoverable buttons and actionable status. Help SHALL expose the versioned Lua contract, reachable peripheral names/channels and examples matching shipped behavior. Saved-program starters and examples SHALL use function declarations exclusively. A draggable native title bar, close control and task-specific tab content SHALL replace the all-in-one scrolling form.

#### Scenario: Essential actions without custom shortcuts
- **WHEN** a native text field has keyboard focus
- **THEN** Save, Run/Apply and Stop remain usable through GUI controls without relying on custom-input key events.

#### Scenario: Discover a peripheral from the editor
- **WHEN** the player inspects attached peripherals
- **THEN** the UI distinguishes red and green paths, device types and disconnected/pending status and provides names usable by the Lua API.

#### Scenario: Learn and run one saved-program language
- **WHEN** the player inserts an empty-draft starter or manually copies a complete Reference tutorial into the Editor
- **THEN** the copied source uses the declaration grammar and can be validated, saved and run through the normal authoring flow
- **AND** help preserves setup, wiring, API signatures, expected results, relevant failure notes and the separate rules for Console commands
- **AND** browsing, copying, inserting, validating and saving cause no implicit activation or peripheral effects; native literal copying, draft preservation and existing explicit controls remain intact.
