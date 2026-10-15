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
diff and re-run hosted validation. Do not replace hashes with unpinned installs.

## Required validation

`.github/workflows/ci.yml`, named **Mod CI**, emits the stable **Mod validation**
check on every pull request and every branch push, without path filters. Branch
pushes provide evidence on the exact head SHA as well as the PR merge candidate.
The `main` ruleset requires this check from the GitHub Actions integration; do
not rename the job without updating that rule. No administrator bypass is needed
to merge a passing PR. Tags are not CI or publication triggers.

The read-only job reuses the existing package regressions, generated-contract and
player-documentation checks, then downloads the official Factorio **2.0.77**
headless archive and verifies its pinned SHA-256 before execution. The packaged
sandbox runs in base mode; the existing factory integration and separate-process
save/reload checks run with base and Space Age. Reports and failure logs are kept
as short-lived Actions artifacts; no release is uploaded or replaced. This is
not graphical/client, multiplayer-join, stress or real-time latency acceptance.

The required check is deliberately separate from the path-filtered Pages
workflow below. Making only the latter required would leave runtime-only PRs
without a check. CI needs no Factorio publishing credentials or model API keys.

The optional model-backed OpenWiki workflow remains dormant unless repository
variable `OPENWIKI_ENABLED` is explicitly `true`. Configure its provider secrets
and review its model settings before enabling it. This is not a required check
and does not affect reading the already-generated developer wiki.

## Hosted workflow

`.github/workflows/docs.yml`, named **Player documentation**, builds changed player
docs/configuration/dependencies on pull requests and pushes to `main`. PR builds
have read-only contents permissions, no publishing secrets, no Pages upload or
deployment. Only the separate deployment job receives Pages write and OIDC rights.
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
after explicit maintainer authorization, review and passing required checks.

- TC14 / `t_6534a3be`: public repository and documentation infrastructure.
- TC15 / `t_0645d3ca`: complete player guide and public API reference.
- TC16 / `t_8d2c465c`: developer OpenWiki.
- TC17 / `t_e6cbf814`: consolidated PR, live full docs and public Factorio alpha.

Remote: `git@github.com:SirEdvin/tweaked-computers.git`; default branch: `main`.
Later cards push only their own scoped branches and verify remote SHAs. No separate
intermediate PRs, unrelated branch merges, tag replacements or force-pushes.
