# Selected Service Rack artwork integration

The user selected AR2 candidate **B — Service Rack**, explicitly including
research icons. This integration extracts only B's deterministic meshes into
`assets/service_rack.py` and the existing `assets/generate.py` pipeline. No
runtime themes, discarded alternatives, game distributions or reference-mod
archives are introduced. No version bump, merge, tag or release is authorized
by this artwork handoff.

## Source and selection

- Accepted main ancestor: `4fe09733d5a30fa5bbf4ad08af71ae9fa60bc941`.
- SC4 source ancestor: `6d1be5f9e364e79483d7eeee67247cf0fb28e3ec` (PR #19).
- Selected study source: `9cbd4ae73c1c62763724735ea93428a3e2d5f5f5`.
- Selected unreleased preview SHA256:
  `75f43f0ddadd4ec6c0a880a2169c2bca5e225341b311859299cc5a7411182cb3`.

SC4 was open/unmerged at integration. This artwork PR is stacked on its branch,
not a duplicate main-targeted PR containing its unrelated changes. The release
owner must preserve ancestry and review the actual stack/base before merging;
this task does not merge SC4 or change its independent acceptance scope.

All 176 existing PNG outputs reproduce the approved B preview byte-for-byte:
24 bodies, 24 shadows, 120 status sheets, six item icons and two glyph/fill
images. An independent frozen inventory digest in `assets/check.py` prevents
silently weakening this equality while allowing the approved antialiased mesh
alpha. The four flat-monitor shadow outputs remain unchanged. The new two
256px technology icons are intentional additions, not falsely claimed preview
equivalence: Circuit Computers depicts the selected desk and Recipe Searcher
depicts the selected scanner. Existing research effects, prerequisites and
costs are untouched.

## Provenance and geometry

These are original project-MIT meshes/materials, with no copied reference pixels
or geometry. AR1's downloaded source references and AR2's exact license/source
receipts remain in the durable study bundles. Nixie recess/foot/vent hierarchy
was studied as a technique, not transplanted art. Historical approved Greg
Flavored sources and notices remain byte-exact, not sampled. See
[editable sources and notices](../assets/README.md).

The production manifest is regenerated from the actual adopted source, pinned
Pillow/NumPy dependencies and every output's PNG/RGBA/alpha bytes. It does not
reuse the preview's intentionally stale production manifest.

Footprints, ground pivots, all cardinal native socket positions, selection,
power/status logic and data/lifecycle behavior are unchanged. Every monitor
alpha pixel and the full 60×60 active interior are preserved, with unchanged
64×64 logical/touch geometry and exact four-unit chamfered mechanical skirt.
Only the two technology icon fields and their sizes change in production
prototype Lua. Production control/runtime/service Lua remains unchanged from
SC4.

## Verification and evidence boundary

The durable receipt, immutable final tested archive, before/after gallery,
source/provenance inventory, command logs and native captures are under:

`/home/siredvin/artifacts/tweaked-computers/t_77647909/`

The final handoff receipt identifies exact archive/source hashes and actual
completed gates. Required gates are reproducibility/provenance/alpha/contact
checks, actual gameplay ZIP inventory, packaged sprite/lifecycle/cold and
monitor-feedback checks in both engine modes, followed by matched native base
and Space Age tours of the final archive. The common native scene includes
ordinary vanilla context, all six devices/cardinals, real red/green edges,
selection/deconstruction, compact statuses and changing standalone/merged
monitors. Research images also require an actual native research-UI inspection.
Contact sheets alone do not close these gates.

Captures use isolated licensed Factorio 2.0.77 build 84539 clients and private
Xvfb. Software-rendered appearance is not hardware FPS, physical-display
smoothness, exhaustive wire interaction or multiplayer acceptance. Historical
AR2 failed/clipped captures remain immutable and distinct from final evidence;
selection of B approves its direction, not technical checks that were not run.
The independent artwork review and final integration/release remain downstream
cards; no published 0.1.9 artifact is overwritten.
