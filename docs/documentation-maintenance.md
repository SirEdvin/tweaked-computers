# Player documentation maintenance

Source: `docs/player/` (Markdown); configuration: `mkdocs.yml`; generated output:
`site/` (ignored, never commit it). The expected public base URL is
https://siredvin.github.io/tweaked-computers/.

## Typed API tooling

`tools/luals-lock.json` pins the Linux x64 LuaLS archive and its SHA-256;
`tools/luals-docs.json` isolates Lua 5.2 declarations from standard runtime
libraries. The built-in primitive type definitions remain enabled for diagnostics.
Install only into a fresh directory outside the checkout:

    WORK=$(mktemp -d "${TMPDIR:?}/tc-luals-XXXXXX")
    mkdir "$WORK/luals"
    curl --fail --location --retry 2 "$(jq -er .url tools/luals-lock.json)" -o "$WORK/luals.tar.gz"
    printf '%s  %s\n' "$(jq -er .sha256 tools/luals-lock.json)" "$WORK/luals.tar.gz" | sha256sum --check
    tar -xzf "$WORK/luals.tar.gz" -C "$WORK/luals"
    export LUALS_BIN="$WORK/luals/bin/lua-language-server"
    "$LUALS_BIN" --version

The observed stock exporter omits alias bodies, overloads, enum members and some
optionality metadata. `tools/luals-export.lua` uses LuaLS's documented
`docScriptPath` hook to retain its parsed annotations; it is not a Lua parser and
must never be loaded by the game. The JSON config expects the hook immediately
above a copied declaration workspace. Keep generated JSON, logs and diagnostics
outside the repository. Create the output directory before invoking LuaLS: this
version can exit zero while reporting that its output directory does not exist.
Require readable output files and passing conformance assertions, not exit alone.

The separate `api/**/*.d.lua` library owns public signatures, fields and semantic
notes. `api/generated/` is derived from implementation metadata, never hand-edited.
The conformance and full-library tests in `tools/test_player_docs.py` reject lossy
extraction and compare every website/native block. LuaLS type diagnostics do not
replace this mod's restricted guest compiler or native-client acceptance.

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

    python3 -m venv .venv-docs
    .venv-docs/bin/python -m pip install --require-hashes -r requirements-docs.txt
    .venv-docs/bin/python -m mkdocs build --strict

Strict validation rejects broken internal page links, missing anchors and omitted
navigation pages. External source/issues/wiki URLs are not network-crawled by MkDocs.
The complete guide and public Lua reference live in `docs/player/`; developer
OpenWiki is separate under `openwiki/`. Do not copy implementation/Claim metadata
into player pages.

    python3 tools/configuration_catalog.py --check
    python3 tools/player_docs.py --check --site site --report /outside/repo/docs-inventory.json

`tools/player_docs.py` generates every API page and named-type page, native
`scripts/ui/api-reference.lua`, navigation, provenance and exact runnable examples.
After intentional source changes, run `tools/configuration_catalog.py` when its
metadata changed, then `tools/player_docs.py`, review the diff, rebuild and check.
The same validated LuaLS records supply every parameter, result, field and note
in both destinations; authored workflow/tutorial guidance stays separate.
Checks compare public methods/aliases with independent implementation exports and
the existing API fixture, preserve old example identities, resolve types and built
HTML links/anchors, and reject missing or changed outputs without rewriting them.
`tools/build.py` checks input/output hashes before packaging matching inert
declarations and generated data. A full `--check` still exercises the pinned parser;
the hash gate alone is not parser, runtime or native-client proof.

For changed Lua examples, reuse the existing exact-engine compile path:

    python3 tools/build.py --output /outside/repo/docs-package
    python3 tools/player_docs.py --check \
      --fixture-archive /outside/repo/docs-package/tweaked-computers_0.1.0.zip \
      --fixture-output /outside/repo/docs-syntax/tweaked-computers_0.1.0.zip
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/docs-syntax/tweaked-computers_0.1.0.zip \
      --output /outside/repo/new-docs-syntax-run --mode base \
      --fixture tests.player_documentation

Use fresh output paths and substitute the actual numeric version. The syntax ZIP
is explicitly a separate test-only archive with an added compile fixture; never
upload it as a release. The fixture compiles every runnable `lua` fence in authored
guides/examples using the actual compiler/limits, and retained Console commands in
Console mode. Generated signature/type snippets are definitions, not programs;
the preservation map prevents silently dropping a formerly checked example.
This does not claim client delivery or
repeat full factory/runtime matrices. Existing implementation fixtures own effects.

Dependencies are version/hash locked for the Linux build. To refresh deliberately,
use pip-tools on Python 3.12 with `mkdocs==1.6.1` as input, inspect the full lockfile
diff and re-run local validation. Do not replace hashes with unpinned installs.

## Required local validation

Tests run locally; GitHub no longer runs mod CI or pull-request documentation
checks, and `main` no longer requires the hosted **Mod validation** check. Keep
the existing tests and runtime budgets: removing hosted execution does not remove
the obligation to verify changes before pushing or releasing. Do not restore
GitHub test workflows or required hosted checks without maintainer authorization.

From the repository root, with the locked documentation dependencies installed
and that Python environment active, run the package/tooling regressions and
generated-document checks:

    WORK=$(mktemp -d "${TMPDIR:?}/tc-local-check-XXXXXX")
    python -m unittest discover -s tools -p 'test_*.py'
    python tools/planning_examples.py --check
    python tools/configuration_catalog.py --check
    python -m mkdocs build --strict --site-dir "$WORK/site"
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

Preserve package hashes, command exits, summaries and complete failure logs outside
git. Local tooling/headless passes are not proof of native UI, rendering, audibility,
connected multiplayer or representative GPU performance; run those checks when
affected and disclose anything unrun. Historical release reports and generated
OpenWiki may describe the former CI setup; this section is the current policy.

The optional model-backed OpenWiki workflow remains dormant unless repository
variable `OPENWIKI_ENABLED` is explicitly `true`. Configure its provider secrets
and review its model settings before enabling it. This is not a required check
and does not affect reading the already-generated developer wiki.

## Hosted workflow

`.github/workflows/docs.yml`, named **Player documentation**, builds changed player
docs/configuration/dependencies on pushes to `main` or an explicit manual dispatch;
it does not run on pull requests. The build has read-only contents permissions and
no publishing secrets. Only the separate deployment job receives Pages write and OIDC rights.
All actions are pinned to official release commit SHAs; build checks out without
persisted credentials. The `github-pages` environment permits only workflow runs
from `main`, with serialized deployments. No environment publishing secrets exist.

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

The Pages push trigger includes the public library, generators, metadata/pins and
examples. It still builds the reviewed versioned Markdown on the existing trusted
refs; it does not run LuaLS, mod tests or generation in the publication job.
Regenerate and run full local checks before publication. This migration does not
dispatch the workflow, alter its ref allowlist, or authorize deployment.

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
