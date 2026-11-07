# Player documentation maintenance

The guide source is Markdown in `docs/player/`. MkDocs uses `mkdocs.yml`.
The welcome source is `docs/welcome.html`. The generated output is `site/`.
Git ignores this directory. Do not commit it. The public base URL is
https://siredvin.github.io/tweaked-computers/.

Use ASD-STE100 Simplified Technical English, Issue 9, for maintained mod documentation.
Follow the language rules in [AGENTS.md](../AGENTS.md#documentation-language).
Preserve API contracts, examples, warnings, and historical evidence.
Edit generated prose in its source. Do not edit generated pages directly.

## Typed API tooling

`tools/luals-lock.json` pins the Linux x64 LuaLS archive and its SHA-256.
`tools/luals-docs.json` isolates Lua 5.2 declarations from standard runtime libraries.
The built-in primitive type definitions remain enabled for diagnostics.
Install LuaLS in a new directory outside the checkout:

    WORK=$(mktemp -d "${TMPDIR:?}/tc-luals-XXXXXX")
    mkdir "$WORK/luals"
    curl --fail --location --retry 2 "$(jq -er .url tools/luals-lock.json)" -o "$WORK/luals.tar.gz"
    printf '%s  %s\n' "$(jq -er .sha256 tools/luals-lock.json)" "$WORK/luals.tar.gz" | sha256sum --check
    tar -xzf "$WORK/luals.tar.gz" -C "$WORK/luals"
    export LUALS_BIN="$WORK/luals/bin/lua-language-server"
    "$LUALS_BIN" --version

The tested stock exporter omits alias bodies, overloads, enum members, and some optionality metadata.
`tools/luals-export.lua` uses the documented LuaLS `docScriptPath` hook to keep parsed annotations.
It is not a Lua parser. Never load it in the game.
The JSON configuration expects the hook immediately above a copied declaration workspace.
Keep generated JSON, logs, and diagnostics outside the repository.
Create the output directory before you invoke LuaLS.
This version can exit with zero while reporting a missing output directory.
Require readable output files and passing conformance assertions. A zero exit is not sufficient.

The separate `api/**/*.d.lua` library defines public signatures, fields, and semantic notes.
Implementation metadata supplies `api/generated/`. Do not edit these generated files directly.
The tests in `tools/test_player_docs.py` reject extraction that loses contract data.
They compare every complete website reference block with its native counterpart.
LuaLS type diagnostics do not replace the restricted guest compiler or native-client acceptance.

The [section and exact-example migration map](api-migration.md) records every
retired heading and retained source identity. Its checked inputs are
`tools/data/api-section-migration.json` and `tools/data/api-example-migration.json`.
They contain destinations/hashes, not a second API definition. Retained
[verification obligations](api-migration-acceptance.md),
[editor interaction requirements](editor-interaction-contract.md) and
[Configurator provenance](configuration-catalog-provenance.md) remain distinct
from the generated player contract. Do not delete an old input while its
replacement is incomplete or its source-preservation check fails.

Maintained OpenSpec now contains behavioral `spec.md` files, not API companions.
The Configurator input lives in `tools/data/`; only its normalized public
declarations are player API authority. Existing active changes retain an
`api-reconciliation.md` mapping without changing their task/evidence status.
Historical archives and release receipts remain historical, not generation inputs.

## Local build and checks

Install the pinned documentation dependencies in a separate environment:

    WORK=$(mktemp -d "${TMPDIR:?}/tc-docs-XXXXXX")
    python3 -m venv "$WORK/venv"
    "$WORK/venv/bin/python" -m pip install --require-hashes -r requirements-docs.txt

`tools/emmy-lock.json` pins EmmyLua 0.25.1 and its archive hash.
`tools/emmy-docs.json` selects Lua 5.2. Install the pinned generator:

    mkdir "$WORK/emmy"
    curl --fail --location --retry 2 "$(jq -er .url tools/emmy-lock.json)" -o "$WORK/emmy.tar.gz"
    printf '%s  %s\n' "$(jq -er .sha256 tools/emmy-lock.json)" "$WORK/emmy.tar.gz" | sha256sum --check
    tar -xzf "$WORK/emmy.tar.gz" -C "$WORK/emmy"
    export EMMY_DOC_BIN="$WORK/emmy/emmylua_doc_cli"
    "$WORK/venv/bin/python" tools/website.py --site "$WORK/site"

`tools/website.py` builds the strict MkDocs guide first.
It adds unchanged stock EmmyLua HTML under `api/` and installs the authored welcome page.
The guide index remains at `guide.html`. Existing guide and complete reference routes remain available.
The builder refuses output collisions and checks local file and fragment links.

EmmyLua provides direct type links, API search, and shared themes.
Its search does not index the welcome prose or guides. Use Search in the guide for guide text.
The pinned renderer omits some alias and overload details and misrepresents some return signatures.
The welcome page links to the complete reference for these contracts.
Do not remove that reference until the stock renderer passes all conformance checks.

Strict validation rejects broken internal page links, missing anchors, and omitted navigation pages.
MkDocs does not crawl external source, issue, or wiki URLs.
The complete guide and public Lua reference are in `docs/player/`.
The developer OpenWiki remains separate under `openwiki/`.
Do not copy implementation or Claim metadata into player pages.

    python3 tools/configuration_catalog.py --check
    python3 tools/player_docs.py --check --site "$WORK/site" --report "$WORK/docs-inventory.json"

`tools/player_docs.py` generates complete API pages, named-type pages, native `scripts/ui/api-reference.lua`, navigation, provenance, and exact runnable examples.
After metadata changes, run `tools/configuration_catalog.py` first.
After documentation source changes, run `tools/player_docs.py`.
Review the diff. Rebuild the site. Run the checks.
The same validated LuaLS records supply every parameter, result, field, and note in both complete references.
Authored procedures and tutorials remain separate.
Checks compare public methods and aliases with independent implementation exports and the existing API fixture.
They preserve old example identities and resolve types, HTML links, and anchors.
They reject missing or changed outputs without rewriting them.
`tools/build.py` checks input and output hashes before packaging matching inert declarations and generated data.
A full `--check` exercises the pinned parser.
The hash check alone does not prove parser, runtime, or native-client behavior.

For changed Lua examples, reuse the existing exact-engine compile path:

    python3 tools/build.py --output /outside/repo/docs-package
    python3 tools/player_docs.py --check \
      --fixture-archive /outside/repo/docs-package/tweaked-computers_0.1.0.zip \
      --fixture-output /outside/repo/docs-syntax/tweaked-computers_0.1.0.zip
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/docs-syntax/tweaked-computers_0.1.0.zip \
      --output /outside/repo/new-docs-syntax-run --mode base \
      --fixture tests.player_documentation

Use new output paths. Substitute the actual numeric version.
The syntax ZIP is a separate test archive with an added compile fixture.
Never upload it as a release.
The fixture compiles every runnable `lua` fence in authored guides and examples with the actual compiler and limits.
It compiles retained Console commands in Console mode.
Generated signature and type snippets are definitions, not programs.
The preservation map prevents silent removal of a previously checked example.
These checks do not prove client delivery or repeat complete factory and runtime matrices.
Existing implementation fixtures test effects.

Dependencies are version-locked and hash-locked for the Linux build.
For an intentional update, use pip-tools on Python 3.12 with `mkdocs==1.6.1` as input.
Examine the complete lockfile diff. Run local validation again.
Do not replace hashes with unpinned installations.

## Required local validation

Tests run locally. GitHub no longer runs mod CI or pull-request documentation checks.
`main` no longer requires the hosted **Mod validation** check.
Keep the existing tests and runtime budgets. Verify changes before a push or release.
Do not restore GitHub test workflows or required hosted checks without maintainer authorization.

Activate the Python environment with the locked documentation dependencies.
Set `LUALS_BIN` and `EMMY_DOC_BIN` to the verified binaries.
Run these checks from the repository root:

    WORK=$(mktemp -d "${TMPDIR:?}/tc-local-check-XXXXXX")
    python -m unittest discover -s tools -p 'test_*.py'
    python tools/planning_examples.py --check
    python tools/configuration_catalog.py --check
    python tools/website.py --site "$WORK/site"
    python tools/player_docs.py --check --site "$WORK/site" --report "$WORK/player-docs.json"
    python tools/build.py --output "$WORK/package" > "$WORK/package.json"

For artwork changes, install `assets/requirements.txt` on Python 3.13+ and run
`python assets/check.py --output "$WORK/art"`. Use the same unchanged artwork
checks before a release.

For runtime changes, test the exact built archive with the relevant existing
`tools/smoke.py` fixtures and specialized harnesses in base and Space Age, including
separate-process cold reload where applicable. Current source pins Factorio
**2.1.23** in the harness (the manifest accepts all 2.1 patches); old-save migration checks additionally need their original
engine and immutable old mod archive. The current local engines are:

- Headless: `gameitself/headless-2.1.23/factorio/bin/x64/factorio`.
- Base client: `gameitself/base-2.1.23/factorio/bin/x64/factorio`.
- Space Age client: `gameitself/space-age-2.1.23/factorio/bin/x64/factorio`.

Confirm `--version` and `--help`, then follow the isolated-run procedures in
[AGENTS.md](../AGENTS.md), substituting these paths for its historical 2.0.77 paths.
The optional chart ZIP remains under `.github/fixtures/factorio-charts/` for
present/absent dependency tests; it is not shipped in the mod.

Keep package hashes, command exits, summaries, and complete failure logs outside git.
Local tooling and headless passes do not prove native UI, rendering, audibility, connected multiplayer, or representative GPU performance.
Run the affected checks. Report checks that you did not run.
Historical release reports and generated OpenWiki can describe the former CI setup.
This section gives the current policy.

The optional model-backed OpenWiki workflow remains dormant unless repository
variable `OPENWIKI_ENABLED` is explicitly `true`. Configure its provider secrets
and review its model settings before enabling it. This is not a required check
and does not affect reading the already-generated developer wiki.

## Hosted workflow

`.github/workflows/docs.yml` is named **Player documentation**.
It builds changed player documentation, configuration, and dependencies on pushes to `main` or explicit manual dispatch.
It does not run on pull requests.
The build has read-only contents permissions and no publishing secrets.
Only the separate deployment job receives Pages write and OIDC rights.
All actions are pinned to official release commit SHAs.
Checkout does not keep credentials.
The `github-pages` environment permits only workflow runs from `main`.
Deployments run in sequence. The environment has no publishing secrets.

The build verifies the pinned EmmyLua archive hash before extraction.
It uses `tools/website.py` for the welcome page, stock API browser, and complete guide.
For historical source refs without that tool, it uses the original strict MkDocs build.

Pushes to main deploy automatically. For the full alpha, TC17 must dispatch the
workflow FROM MAIN while selecting an approved source ref (no feature-PR merge):

    gh workflow run docs.yml --repo SirEdvin/tweaked-computers --ref main \
      -f publish_ref=refs/heads/tweaked-computers/t_e6cbf814-tc17-publish-the-complete-alpha-on-facto

Prefer an immutable alpha tag after testing and verifying the pushed tag SHA:

    gh workflow run docs.yml --repo SirEdvin/tweaked-computers --ref main \
      -f publish_ref=refs/tags/alpha-0.1.0

That tag is an example, not an existing/reserved version. Allowed sources are
`refs/heads/main`, the exact TC17 branch above, and `refs/tags/alpha-*` in THIS
repository. The main-only environment restriction applies to the WORKFLOW ref;
the source is explicitly selected, allowlisted and checked out in the read-only
build job. Thus the alpha branch/tag can deploy without broad environment rules.
Do not dispatch from the feature branch: the workflow intentionally rejects it.
A maintainer with repository write access must first verify any selected ref.

    gh run list --repo SirEdvin/tweaked-computers --workflow docs.yml --limit 5
    gh run watch RUN_ID --repo SirEdvin/tweaked-computers --exit-status

Inspect the build job's immutable source SHA, successful deploy job and live
`source-commit.txt`, then the actual homepage and representative API pages. Manual
selection is resolved once at checkout; deployment uses that run's artifact and
does not re-resolve a moving branch. Do not claim final guide completion from a
successful scaffold build. TC17 owns the final complete-site deployment and alpha.

## Future OpenSpec API artifacts

New changes default to the project-local `tc-spec-driven` schema. The bootstrap
and older changes keep their original schema. `specs/**/spec.md` contains behavior;
the separate conditional `lua-api` artifact discovers `api/**/*.d.lua` inside a
change. Its proposal's `API Impact` section records `Status: changed` or `none`,
a `Reason` and `Compatibility`. For changed, use the exact template table headers:

| Canonical path | Disposition | Removed identities |
| --- | --- | --- |
| api/monitor.d.lua | modified | - |

This example inventories a path, not a signature. Supply the complete proposed
replacement at `openspec/changes/NAME/api/monitor.d.lua`. Unaffected canonical
files supply its type dependencies. Inventory every affected file; use `added`,
`modified` or `removed`, and comma-separated exact removed public identities
(including `TC.Type.field` members), or `-`. A whole-file removal has a
comment-only `.d.lua` record with `-- Removes: api/path.d.lua` and
`-- Identities: TC.Name, TC.Name.member`; it is not an empty module to promote.
Preserve pre-promotion verification evidence when removing identities.

Before promotion, copy the complete `api/` directory to an evidence directory outside the repository.
After promotion, use `--baseline-api PATH` for the preserved API directory.
The checker exports that directory again with the pinned LuaLS binary.
It checks removed identities against both the baseline and the current declarations.
It records hashes for the baseline files.
Keep the baseline directory and reports with the test evidence.

For `Status: none`, omit the table and all proposed declarations. Review the
source, proposal and design, then obtain the review fingerprint (replace NAME):

```sh
PYTHONPATH=tools python -c 'from pathlib import Path; from api_changes import review_fingerprint; print(review_fingerprint(Path.cwd(), Path("openspec/changes/NAME")))'
```

Record it as `Reviewed-source: <digest>` in API Impact. The digest conservatively
covers declarations, runtime/prototype/schema inputs and the proposal/design;
it invalidates stale reviews, not infers semantic API changes. Re-review before
refreshing it. No synthetic declarations, `skip_api` flag or misuse of `skip_specs`
is needed. OpenSpec's file-existence status can still show `lua-api` ready and its
dependents blocked: the schema explicitly permits the conditional skip and the
workflow may create those dependents. This is not a machine-enforced skip state.

```sh
openspec schema validate tc-spec-driven --json
python tools/player_docs.py --check --change NAME --report "$WORK/proposed-api.json"
```

The project check is read-only: it checks the complete inventory, paths, removal
records, duplicate identities and reference closure using a scratch LuaLS overlay.
One glob match is not completeness. It rejects extra files and Markdown API
companions; it does not prove runtime implementation or independently infer that
an author omitted an affected module from the inventory. Review still compares
the design/implementation and public contract. Do not point this check at legacy
reconciled changes or the bootstrap without deliberately migrating their proposal.

Apply promotes accepted full replacements/removals into canonical `api/` (update
generators instead of hand-editing generated files), regenerates both references
and verifies independent runtime behavior. Compare promoted bytes to the reviewed
artifacts and preserve the pre-removal receipt. Archive/sync promotes only
behavioral `spec.md`; change-scoped declarations/removal records remain historical.
It does not update canonical API files for you. Never recreate API companions in
`openspec/specs/`. Local integration tests exercise these operations in scratch
projects and compare installed schemas and real change history before/after.

## Public delivery ownership

The Pages push trigger includes the public library, generators, metadata, pins, examples, and welcome page.
It builds reviewed Markdown and stock EmmyLua HTML from existing trusted refs.
The publication job does not run LuaLS, mod tests, or regeneration of tracked references.
Regenerate tracked references before publication. Run complete local checks.
These tools do not change the ref allowlist or authorize deployment.

The user authorized a public repository, full player docs, separate developer
OpenWiki and actual Factorio alpha. This supersedes the original local-ZIP-only
endpoint. A ZIP remains the upload artifact. Publishing an alpha does not by
itself authorize merging its implementation PR or archiving OpenSpec; merge only
after explicit maintainer authorization, review and passing relevant local checks.

- TC14 / `t_6534a3be`: public repository and documentation infrastructure.
- TC15 / `t_0645d3ca`: complete player guide and public API reference.
- TC16 / `t_8d2c465c`: developer OpenWiki.
- TC17 / `t_e6cbf814`: consolidated PR, live full docs and public Factorio alpha.

Remote: `git@github.com:SirEdvin/tweaked-computers.git`; default branch: `main`.
Later cards push only their own scoped branches and verify remote SHAs. No separate
intermediate PRs, unrelated branch merges, tag replacements or force-pushes.
