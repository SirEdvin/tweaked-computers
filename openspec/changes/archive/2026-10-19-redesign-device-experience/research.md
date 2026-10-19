# Evidence and limits

This is planning, not an implementation or graphical-client acceptance report.

## Pinned inputs

- Tweaked Computers: `cb300e62ebad6a4a9a38a0679f21e251009f1d16` (alpha 0.1.1 implementation).
- Factory Planner: `adff94b6b303fc9c8448bf9db329cfeeb20fa593`, https://github.com/ClaudeMetz/FactoryPlanner. Inspected its source, MIT license and `screenshots/01_main_interface.png`; it is inspiration, not a new dependency.
- Factorio: official local headless binary reports 2.0.77. Inspected matching runtime/prototype JSON schemas and shipped base circuit entity definitions, not the rolling latest API.
- User image: https://files.catbox.moe/0kxw7f.png. Inspected the image itself: an asset-style computer view with checkerboard background, not a screenshot demonstrating GUI or wiring behavior.
- User clarified that the missing monitor X is the native red deconstruction marker.

## Observed source facts

| Complaint | Evidence at the pinned implementation | Conclusion |
| --- | --- | --- |
| Generic NETWORK selection | `prototypes/devices.lua`: visible electric-energy-interface bodies have priority 40; invisible `tc-port-*` constant-combinators have priority 60. `scripts/device-definitions.lua` places the single-role network child at the body center. `locale/en/devices.cfg` labels it NETWORK. | A selectable implementation helper is the actual native endpoint and wins hover. Merely renaming it does not make the physical device the endpoint. |
| Connection semantics | `scripts/lifecycle.lua` constructs/owns role children; `scripts/network.lua` admits only exact bound network connectors. | Hiding every helper without changing connector ownership would break wiring/discovery. Preserve the lifecycle connector seam and role checks. |
| Cluttered editor | `scripts/ui/editor.lua` builds source, all actions, output, help and recovery into one scroll flow; source height is capped at 300. | Information architecture must change, not only colors or button spacing. |
| Useful existing behavior | `scripts/ui/editor-model.lua` enforces sessions, revisions, separate save/activation and recovery. | Reuse the model; rework presentation without dropping safety actions. |
| Peripheral copies | `assets/generate.py` selects the same `computer_advanced_off` model for every non-monitor kind, repeats it for wider devices and adds letter glyphs. | Distinct silhouettes require new art, not recoloring the same computer. |
| Socket mismatch | Native role offsets in definitions differ from the art generator's decorative badge offsets; role colors are independently declared. | Derive visual and physical sockets from one layout contract. |
| Missing monitor X | `scripts/rendering.lua` uses filled rectangles for panel/cursor and `light-effect` sprites for glyphs. No deconstruction-specific handling exists in `control.lua`. | Overlay occlusion is a credible hypothesis, not proven by headless execution. Also check whether the body receives the native order. |

## Reference design and API constraints

Factory Planner's `modfiles/ui/base/main_dialog.lua`, `ui/main/title_bar.lua` and `ui/base/modal_dialog.lua` support the proposed native frame hierarchy, compact title controls, draggable window, display-scale sizing and contextual actions. The inspected source does not supply the proposed five tabs: those are our requested editor-first information architecture.

Pinned schema checks:
- ElectricEnergyInterfacePrototype has no native circuit connection properties; ConstantCombinatorPrototype has cardinal circuit connection points.
- LuaRendering.draw_rectangle has `draw_on_ground`, not a general `render_layer`; draw_sprite supports a layer.
- `light-effect` follows `entity-info-icon` in RenderLayer ordering. Exact native X occlusion still requires a graphical view of the candidate.
- Native tabbed-pane, selected tab index, focus/select/scroll methods and drag_target exist. Do not invent caret readback or free-resize events; keeping the source widget alive avoids unnecessary loss of editing context.

## Narrow unresolved engine checks assigned to implementation

RD1 verifies the circuit-shell/private-power carrier in the exact engine before converting existing devices. RD4 determines a usable layer below native feedback and checks real mark state. These are bounded technical checks of the agreed UX contract, not invitations to change it silently.

No new runtime, native GUI, migration or client tests have run for this redesign. Browser review verifies only the planning HTML. Existing alpha evidence does not establish the redesign's usability.
