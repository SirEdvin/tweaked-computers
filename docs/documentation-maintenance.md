# Player documentation maintenance

Source: `docs/player/` (Markdown); configuration: `mkdocs.yml`; generated output:
`site/` (ignored, never commit it). The expected public base URL is
https://siredvin.github.io/tweaked-computers/.

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

`tools/player_docs.py` generates only the readable settings/nested-schema tables,
common limits and exact shipped runnable examples. After intentional source changes,
run it without `--check`, review the generated diff, then rebuild and check. It
compares public methods/aliases with actual exports and the existing API inventory,
checks event/color coverage and all eight companion-contract/page mappings, and
checks built internal HTML links/anchors. This is static coverage plus human
contract review, not runtime/client proof. Do not edit generated pages directly.

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
upload it as a release. The fixture compiles every `lua` fence as a complete native
document using the actual compiler/limits, but does not claim client delivery or
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
**2.1.23** in `info.json`; old-save migration checks additionally need their original
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

## Public delivery ownership

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
