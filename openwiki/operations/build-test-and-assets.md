---
type: operations
title: Build, targeted tests, artwork and documentation operations
description: Reproducible external-output packaging, exact-engine focused smoke, asset/parser provenance and the separate player-site deployment boundary.
tags: [build, testing, assets, licenses, operations, documentation]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T07:15:32.900Z
sources:
  - id: openwiki-source-d558e38ccd1b08e055e4f3f5
    resource: repo://.github/workflows/docs.yml
  - id: openwiki-source-6d4b4e707b8d60b6ccfa3425
    resource: repo://.github/workflows/openwiki-update.yml
  - id: openwiki-source-8037e2358a2c4f9b2c722a11
    resource: repo://AGENTS.md
  - id: openwiki-source-f28cbc9af274024b9716994f
    resource: repo://assets/README.md
  - id: openwiki-source-757f2a5291d89612677f740d
    resource: repo://mkdocs.yml
  - id: openwiki-source-ed1a70dfaf29a8bea3029be3
    resource: repo://tools/build.py
  - id: openwiki-source-76b87832ddf6312873ab8b07
    resource: repo://tools/smoke.py
  - id: openwiki-source-08ded4ecd7f943b2b7d08274
    resource: repo://vendor/phobos/NOTICE.md
generated: { by: "hermes", at: "2026-10-15T07:15:32.900Z" }
---

# Build, targeted tests, artwork and documentation operations

## Package actual reviewed source

The target is exactly Factorio 2.0.77, base with optional Space Age. The scaffold version in `info.json` is package input, not a reservation of a future portal release version. This is an alpha with provisional limits and deferred client QA.

From the repository root, use an absolute external destination:

```sh
python3 tools/build.py --output /absolute/external/artifacts
```

The builder refuses output inside the checkout. It validates pinned parser hashes/exact Lua inventory and asset input/output/notice hashes, then packages explicit top-level files and runtime directories, including docs/examples/tests plus capability/API contracts. Python source tooling and bytecode caches are excluded; prohibited executable suffixes are rejected before archive creation. The generators remain in public source rather than the runtime ZIP, as required by the Mod Portal upload validator. It excludes orchestration reports by selecting contract subdirectories, not the whole OpenSpec change. Every payload has a SHA-256 in `package-manifest.json`; ZIP ordering, timestamps and modes are deterministic. `openwiki/` is not in the runtime directory inventory, so the developer wiki is a repository deliverable, not silently added to the mod payload.

Inspect the builder's inventory before adding generated files beneath packaged directories. It includes files recursively there; do not put caches, secrets or verification logs under `docs`, `assets`, `tests` or another packaged directory. It rejects symlinks and duplicate paths. Builds write no application source, whereas asset generation/catalogue generation can change tracked outputs.

## Reuse the focused engine harness

For a minimal native compiler check, build once and select one fixture/mode with a fresh external output directory:

```sh
python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
  --archive /absolute/external/artifacts/tweaked-computers_0.1.0.zip \
  --output /absolute/external/runtime-smoke --mode base \
  --fixture tests.runtime_contract
```

Substitute the actual versioned filename produced by the builder. `--mode both` (the default) exercises base and Space Age. The harness checks the exact engine version, copies the exact archive, and reads fixture modules from that archive—not uncommitted alternate fixture files. It creates isolated mod/config/write directories and captures commands, logs, grouped-contract counts, exit codes and archive hash in `summary.json`.

Cold-capable fixtures support `--cold`; `--upgrade-fixture` requires it and adds a base configuration-change phase by changing only the copied test mod. Cold phases start isolated localhost-only headless servers, freeze an immutable snapshot, then require console `/quit` acknowledgement without forced termination for success. Ordinary map creation does not start that server. None of this launches a graphical client or proves multiplayer joining.

For integrated production ownership, use the fixed production-context fixture:

```sh
python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
  --archive /absolute/external/artifacts/tweaked-computers_0.1.0.zip \
  --output /absolute/external/integration-smoke \
  --fixture tests.integration_engine --data-fixture tests.candidate_data \
  --production-context --cold --upgrade-fixture
```

Only `tests.lifecycle_engine` and `tests.integration_engine` are accepted for production context, and both require cold mode. This lets one production registry own native entity events; loading lifecycle again in a second mod would create duplicate helpers and invalidate the evidence. Select the affected fixture rather than rerunning a matrix for every documentation edit.

Useful focused coverage: runtime/compiler (`runtime_contract`), computer (`computer_contract`, `computer_cold`), authoring (`editor_contract`, `editor_cold`), network (`network_engine`), signals (`logic_engine`), KV (`kv_engine`), monitors (`monitor_engine`), typed adapters (`configurator_engine`, `configurator_full_engine` with its data fixture), physical lifecycle (`device_engine`, `lifecycle_engine`). Check each fixture's exported hooks before adding `--cold`.

## Artwork and parser provenance

Selected Greg Flavored device artwork is pinned to `ac6cafc3993c902e2ca95d85b501d3c7e172570c`; the approved MIT permission basis and exact original files/notices are recorded under `assets/`. Preserve `Copyright (c) 2024 BirbIrl` and the complete Greg Flavored MIT notice, project-authored MIT notice and manifest with derivatives. No speculative replacement licensing gate is introduced here.

The glyph source `assets/glyphs.txt` is independently authored 5×7 stroke data, not imported CC:Tweaked/Greg Flavored/system font pixels. The generated atlas has 256 byte slots; ASCII, mosaic and replacement-box behavior is recorded in the asset contract. `assets.sprites` returns descriptions that consumers copy; prototypes/runtime registration remain separate. Do not rotate preprojected sprites a second time or confuse visual role cues with topology authorization.

```sh
python3 assets/check.py --output /absolute/external/fresh-asset-check
python3 tools/planning_examples.py --check
python3 tools/configuration_catalog.py --check
```

Asset checking regenerates into an external destination and validates output/provenance. In contrast, `assets/generate.py`, parser reimport and catalogue generation without `--check` deliberately write tracked artifacts: review their diffs. Phobos is a parser-only pinned eight-module closure at `2566dd85807b4f2bdff8e40ba4d79bcf8e96de3f`; preserve its MIT license/NOTICE/manifest. The importer adds host compilation-work/depth probes, not a guest VM or upstream bytecode backend.

## Player site is separate from developer OpenWiki

`mkdocs.yml` builds only `docs/player/` into ignored `site/`, with navigation for the complete player guide and Lua API reference. `requirements-docs.txt` locks docs dependencies with hashes. Follow [documentation maintenance](../../docs/documentation-maintenance.md) for local installation and trusted-ref dispatch. `python -m mkdocs build --strict` validates the player site; it does not generate or index OpenWiki.

The existing `.github/workflows/docs.yml` validates player docs on relevant PRs and main pushes. Its read-only build checks out the selected immutable source, builds strictly and records `site/source-commit.txt`. PRs do not upload/deploy Pages artifacts. Deployment is a separate main-workflow job with only Pages/id-token write permissions, serialized protected `github-pages` environment and no source checkout. Manual dispatch must run workflow code from main and accepts only main, the exact authorized publication branch or `alpha-*` tags; it can publish a review branch without merging it. Wiki-only changes do not trigger those player-doc path filters, and this card does not redeploy the live site or alter that player-doc automation.

OpenWiki finish also installs a separate `.github/workflows/openwiki-update.yml` and a managed block in `AGENTS.md`. The generated updater is daily/manual, checks out full history, installs pinned OpenWiki/optional rendering packages, runs a model-backed update and proposes an `openwiki/update` pull request. It deliberately preserves completed-page progress even after an update failure and then propagates the failure status. Its write permissions are limited to contents/pull requests; it has no pull-request event trigger and does not deploy Pages. The generated model/provider configuration and secret references need maintainer review before enabling hosted model-backed updates; wiki generation here used Hermes MCP instead. No hosted run of this generated updater, model-secret configuration or claim of scheduled automation success is part of this wiki handoff.

OpenWiki uses its resumable begin/plan/page-submit/finish lifecycle with source-evidenced Claims; generated indexes, Claims, provenance and setup blocks are tool-owned. Keep its workflow separate from the player content pipeline. This wiki's generation is documentation work only: historical engine reports in `docs/alpha-candidate.md` are not new test execution. GUI focus/typing, real touch/zoom/GPU alignment, audible output, multiplayer joining and maximum-world performance remain explicitly deferred; model service ticks are not client-visible latency guarantees.

Related: [developer task routing](../quickstart.md), [sandbox boundaries](../runtime/compiler-and-sandbox.md), [adapter extension](../configuration/typed-adapters.md).
