# Recipe Searcher candidate verification

Unreleased implementation of `add-recipe-searcher`; no release/version/tag or
Mod Portal publication is made by this change. Target: Factorio 2.0.77 build
84539, base and optional Space Age. The candidate retains Console, monitor
buffering and live budget settings. Production budgets are unchanged.

## Evidence and reproducibility

Durable evidence root: `/home/siredvin/artifacts/tweaked-computers/t_35655795/`.
The final external verification receipt records the exact commit, candidate ZIP
SHA-256, counted suite/mode/cold-phase ledger, native renderer, process exits and
selected evidence hashes. The receipt is external so its own archive hash is not
a self-referential packaged document. Intermediate failed/pilot archives and logs
remain separate; an older pass does not certify a later changed archive.

Build outside git, then run these existing wrappers with fresh output paths:

```sh
python tools/build.py --output "$WORK/package"
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/recipe-searcher" --mode both \
  --fixture tests.recipe_searcher_engine --data-fixture tests.recipe_searcher_data \
  --production-context --cold --upgrade-fixture
python tools/recipe_searcher_upgrade.py --factorio "$HEADLESS" \
  --archive "$ARCHIVE" --legacy /path/to/published/tweaked-computers_0.1.8.zip \
  --output "$WORK/recipe-install"
```

The installation driver requires the immutable released ZIP with SHA-256
`f37b1d44fb148a248a6bd73334612e49ee0d0729a3cb1357868923ae5ed406db`.
It adds only an opt-in control hook and test fixture to a private legacy copy,
checks all other released bytes, and leaves the candidate archive unchanged.
A companion-version change triggers an actual configuration event despite the
candidate intentionally retaining the release's numeric version. Ordinary reload
is a separate process without that change. Do not install both same-version ZIPs.

## Automated feature coverage

- Real data prototypes enforce 1×1 / 30 kW, direct native contacts/private power,
  exact steel/advanced-circuit/processing-unit recipe, two direct prerequisites,
  200 red/green/utility research units at 60 seconds, and unchanged prior effects.
- Real compiled guest calls exercise exact inventory/arity/domains, item/fluid
  same-name separation, no-match/input-only exclusion, hidden/locked/recycling and
  companion-mod producers, primary/additional/modded categories, exact 50 success,
  51 refusal, an oversized single category and category-before-count refinement.
- Complete engine readback is compared with snapshots, including ordered repeated
  products, fixed/ranged/probabilistic amounts, modifiers, fluid temperatures,
  visibility/false values and Space Age surface conditions/open bounds. Mutation
  of one snapshot cannot change native recipes or the next result.
- Live script availability and independent forces are checked. Native red/green
  paths, unpowered limits/discovery/relay, restored power, captured force loss and
  replacement refusal, cross-surface clone isolation, rotation/clone/mining and
  helper cleanup are exercised. The lifecycle suite includes real wired searcher
  blueprint capture, rotated revival and cold preservation.
- Host-only fault injection separately verifies unsupported/nonfinite metadata,
  native-access errors and refusal before native filtering at zero credits.
  These cases are labelled synthetic; they are not claims that invalid metadata
  was installed into the engine.
- Real scheduler ticks run repeated exactly-50 searches beside an interactive
  neighbor and a saturating search program. `pcall` cannot recover fatal budget
  exhaustion. Cold load retains actual spent credits and aliases. Installation
  into a populated, Circuit-Computers-researched pre-feature factory keeps the
  searcher locked; independent research and later configuration preserve it.
- The maintained example is saved/activated through the existing editor's labelled
  player/GUI doubles in the integration fixture. Its actual guest compiler and
  real powered wired provider execute both item/fluid queries. The complete public
  API inventory includes exactly `findRecipes` and `getLimits` for this family.

Affected regressions include runtime/compiler cache, Console contract/cold,
production integration/lifecycle/redesign, candidate GUI/data and art fixtures.
CI includes the new two-mode query/cold/configuration and released-save install
checks without new resource budgets or a parallel test framework.

The historical TC04 `tests.device_engine` is not the current-shell acceptance
suite: its old `body()` looks up a legacy native entity after production replaces
that entity. It fails `public build path did not bind body` in both the immutable
0.1.8 baseline and this candidate before reaching research checks. Preserve those
logs; do not call it a passing candidate regression or weaken production lifecycle
to accommodate it. Updated research assertions are backed by the new native
fixture; current-shell behavior is covered by production redesign/lifecycle plus
the focused searcher fixture.

## Resource/performance boundary

There is no saved query index/cache, asynchronous job or recipe execution. Before
native filtering, the provider admits `(catalogue_count + 1) * (8 + product_name_bytes)`
work units, plus category input work. Candidate iteration and byte-sensitive name
sorting are admitted, as is category membership using the registered category
inventory as a conservative comparison envelope. A staged whitelist bounds
nodes/containers/bytes while projecting; the existing sandbox makes the final
owned defensive snapshot. No duplicate host Data-copy layer changes `E_LIMIT`
into storage `E_CAPACITY`.

The fixture adds 2,048 unrelated producers and a large product-list recipe. One
serial diagnostic run observed catalogues of 2,429 (base) and 2,877 (Space Age):
20 measured scheduler calls per mode completed 19 search callbacks while the
neighbor reached 29 samples. The last tick used 112,169 / 120,681 shared guest
work respectively. The native no-match filter averaged about 0.006 ms and the
50-match filter about 0.005–0.006 ms; all native samples were below 0.04 ms in
that run. This supports retaining the conservative provisional 8-unit catalogue
admission coefficient without increasing budgets, not translating it into a
universal milliseconds-per-unit guarantee.

Whole-scheduler means were about 7.8 ms; maxima about 28.9 / 27.6 ms. These short
instrumented shared-host diagnostics are not a worst-case CPU bound, benchmark
speedup or 60-UPS promise. Native filtering/property materialization remains opaque
and mod-metadata-dependent. Fifty results is a count ceiling, not a CPU guarantee.
The final receipt retains its own raw measurements and does not erase unfavorable
tails or replace them with publication cadence.

## Original artwork and actual clients

The scanner adds original Foundry geometry: an open archive bed, copper rails and
raised optical bridge, distinct from the KV cartridge rack. Socket coordinates
come from actual production Lua in the pinned engine. The generator updates shared
status/shadow positioning, exports all directions/states/icon and retains source
and output provenance. All 147 prior generated PNG payloads remain byte-exact;
176 PNG outputs, 72 native contact coordinates and six distinct silhouettes are
checked. Contact sheets are asset composites, not native-client screenshots.

The fixed `tests.recipe_searcher_client_engine` scene is prepared through
`tools/shell_client.py --fixture tests.recipe_searcher_client_engine`, with
independent configs/write-data/mods and matching licensed full distributions.
Private Xvfb clients expose four powered cardinal specimens wired on red/green,
four deliberately unpowered specimens, original-family bodies and a vanilla
assembler. Actual-window captures show body selection and the inventory quickbar
icon; native screenshots retain every cardinal closeup and the complete scene.
The inspected renderer is llvmpipe OpenGL (software), not representative GPU FPS.
Clients must exit normally, with `Goodbye`, zero exit and no forced cleanup.

A localhost-only headless server and two real full clients exercise joining after
a saved query and script-driven force availability change. All three independent
readbacks agree on complete ordered recipe data/current enabled state; the joining
peer retains the prior snapshot rather than reconstructing an unsaved cache.
Client/server logs and JSON readbacks are distinct from single-process evidence.
The final receipt identifies the actual connected/cold cases and their exact ZIP;
this does not certify arbitrary modpacks, WAN conditions or other client platforms.

## Static/package checks

```sh
python -m unittest discover -s tools -p test_build.py
python tools/planning_examples.py --check
python tools/configuration_catalog.py --check
python tools/player_docs.py --check --site "$WORK/site" --report "$WORK/docs.json"
python -m mkdocs build --strict --site-dir "$WORK/site"
python assets/check.py --output "$WORK/art-check"
npm exec --yes --package=@fission-ai/openspec -- openspec validate add-recipe-searcher --strict
```

The explicit package inventory includes the two new API/capability contract files,
example, player guide and exact generated art bytes, but excludes proposal/design/
tasks, Python tools, licensed game distributions and display credentials.
Generated OpenWiki pages are untouched. Keep saves/backups and matching old ZIPs:
downgrading a factory containing the new device is not lossless; restore a
pre-upgrade backup instead.
