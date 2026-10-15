# Integrated redesign candidate — 0.1.2 ALPHA

This is the RD5 installable review candidate, not a public release. RD6 owns
Factorio Mods/GitHub publication and live documentation deployment. The package
remains pinned to Factorio 2.0.77, base alone or optional Space Age, and Lua API v1.
Back up worlds and the old ZIP before upgrading. Never overwrite published 0.1.1.

## Integrated source

- Approved plan: `705e562df16cbfd6ff4d2c9b960ca33a24facc38`.
- RD1 physical shells/migration: `8796f1262956cc3c04319b95dc2eed2e841988c8`.
- RD2 complete artwork: `877a14e7db1739e8db0d450e9db5604cdee77439`.
- RD3 tabbed workspace: `1bf47289dd5e228380e29d096e1076e2681fddaa`.
- RD4 monitor layering: `88e6c3a961135cdc8ba97ce6bb3814dac8bc056c`.
- Main CI/runtime-sort fix: `f06cfe6293ea769280772104a2ab23b53a53ae2c`.

The integration retains all three new GUI event registrations, the production
fixture allowlist, the separate saved/active/draft model, exact role/color
ownership and existing resource caps. No additional guest API or runtime is added.
The upgrade harness now preserves the old archive's actual filename while creating
its genuine 0.1.1 save, then replaces it with the correctly named 0.1.2 candidate.
This matters now that the candidate version differs from the baseline.

## Focused verification and reproducibility

Build once with `python3 tools/build.py --output /outside/repo/rd5-artifact`.
Use fresh external output paths and that exact ZIP with `tools/smoke.py`:

| Fixture | Extra flags | Evidence boundary |
| --- | --- | --- |
| `tests.redesign_engine` | `--data-fixture tests.redesign_data --production-context --cold` | Native shell/contact/role/passive power, mark/cancel and cold identity |
| `tests.network_engine` | `--cold` | Same-color discovery, current authority, role/foreign/vanilla refusal |
| `tests.integration_engine` | `--production-context --cold` | Author/Validate/Save/Run, real factory entities and shipped programs; GUI/player doubles |
| `tests.editor_workspace` | none | Five tabs, ownership, focus/draft retention, model scale layouts; GUI mocks |
| `tests.editor_cold` | `--cold` | Dirty/saved/active snapshots, tab/focus/reference/follow/recovery and spent credits |
| `tests.monitor_feedback_engine` | `--data-fixture tests.monitor_feedback_data --production-context --cold` | Marked subsets, ongoing updates, draw layers, cold state and actual robot removal |
| `tests.art_engine` | `--data-fixture tests.art_data` | Registered packaged sprites, contact geometry, all status selections |
| `tests.runtime_contract` | none | Compiler/sandbox and retained main sort regression |

Run each in base and Space Age. Separately run `tools/rd1_upgrade.py` with the
same candidate: pinned original gameplay source, populated old-save ordinary
reload, real configuration-change conversion/refusal and retained data/wires.
The baseline is instrumented only with the fixed opt-in fixture; candidate bytes
are unchanged. This is not an arbitrary mock-up of a saved migration graph.

Run package unit tests, strict asset regeneration, generated player/API inventory,
strict MkDocs and built-link checks. External evidence contains the exact archive
SHA-256/SHA-1, inventory, commands, complete logs, per-case counts, cold shutdown
results and ancestry statuses. Hashes belong outside this packaged document to
avoid a recursive self-hash. Rebuild after all packaged edits and require equality
with the matrix archive before reusing its evidence.

Contact sheets are regenerated from the integrated artwork and include ordinary /
enlarged cardinal views, sockets, icons and every status frame. They are asset
composites, not screenshots. Editable exporters/provenance remain in source.
The source-grounded developer OpenWiki is a separate repository deliverable.

## User review and remaining acceptance

Use the one [integrated native-client checklist](player/editor.md#integrated-redesign-playtest)
on a backed-up test world. Native graphical construction, typing/paste/clipboard,
focus/caret/scroll, hover/wire readability, art appearance and genuine red-X
visibility remain unperformed/user-owned. Headless properties and table-backed GUI
contracts do not pass those checks. No broad client/multiplayer/stress matrix,
new release, default-branch merge, protection change or OpenSpec archival is part
of RD5. Deferred native review is not a newly imposed publication gate.
