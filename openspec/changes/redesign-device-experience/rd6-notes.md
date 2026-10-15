# RD6 — Published 0.1.2 ALPHA

Published on 2026-10-15 under explicit user authorization. RD1–RD5 are integrated;
all prerequisite commit ancestries, including RD5 `7e929000339a6288662621b1b26148b4d12d9e8c`,
were checked in this release worktree. No main/PR #1 merge, protection change,
OpenSpec archival or newly passed native-client claim is part of this release.

## Immutable source and distribution

- Tag: `alpha-0.1.2` (annotated tag object `29d14fcbb651c168489265edc410b20679970eeb`).
- Released source: `a31519fb42bb91a77a3a9ffe6db980be21ee3fc8`.
- Portal: https://mods.factorio.com/mod/tweaked-computers
- GitHub prerelease: https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.2
- Source: https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2
- Developer wiki: https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2/openwiki
- Player site: https://siredvin.github.io/tweaked-computers/
- Filename/root: `tweaked-computers_0.1.2.zip` / `tweaked-computers_0.1.2/`.
- SHA-256: `bc67a2b8a0b9fedd308ef7b635019804eb6a3b5ceaa4d6f9ddc26db942774bd8`.
- SHA-1: `f8a7aa50d80b8852696d323186b712201232a420`.
- Package inventory: 352 files; deterministic rebuild from committed source is byte-exact.

Portal readback requires exactly one 0.1.2 entry with this filename, SHA-1,
Factorio family 2.0 and exact `base = 2.0.77`, optional `space-age = 2.0.77`
dependencies. Description and immutable source metadata were edited and read back;
license, category, tags and ownership were preserved. The existing listing and
0.1.1 release were not recreated/replaced. The official existing-release upload API
was used. An unauthenticated portal ZIP download returned HTTP 403; no claim of
portal-downloaded byte verification is made. The matching GitHub ZIP and checksums
were downloaded separately and compared byte-for-byte; release is explicitly a
prerelease with `latest=false`.

## Exact final archive checks

- Eight focused suites, base and Space Age: 16 cases, 154 contract-group executions.
- Two populated pinned-0.1.1 upgrades; six upgrade-suite cold phases.
- Twenty additional ordinary cold phases, 26 clean cold-process phases total.
- Every cold phase acknowledged console `/quit`, exit 0; no SIGINT or forced kill.
- Physical shell/socket roles, authority/refusal, factory author-save-run, five-tab
  GUI model, drafts/active revisions, monitor rendering/mark/cancel/robot removal,
  artwork and runtime sandbox are covered by the existing packaged fixtures.
- The downloaded published 0.1.1 SHA-1 matches its portal entry; 67 runtime,
  fixture, prototype and parser files match the pinned upgrade baseline exactly.
- Three package unit tests; strict asset/provenance checks and byte-exact regeneration
  of 147 PNGs/64 contacts; generated example/configuration/player-contract checks.
- Strict MkDocs: 20 built pages, 823 internal links. The RD5 source-grounded managed
  OpenWiki was retained, not rewritten as a publication report; immutable raw wiki
  source files were read back byte-exact from the release tag.

Hosted exact-head `Mod validation` passed for the released source:
https://github.com/SirEdvin/tweaked-computers/actions/runs/38743287607

Pages build/deploy succeeded using the existing main-dispatched, allowlisted alpha
tag path, without changing workflow/protection policy:
https://github.com/SirEdvin/tweaked-computers/actions/runs/38743355089

The live `source-commit.txt` equals the released source SHA. Homepage, installation,
editor and two API pages were read back for actual integrated-release content.
Final verification, complete logs/commands and public metadata readbacks are retained
in the RD6 external evidence, not inserted into packaged directories.

## Remaining user-owned checks

Native graphical GUI construction/layout, physical typing/paste/caret/clipboard/
focus/scroll, world hover/wiring/art readability, actual red-X visibility, touch,
audible playback and multiplayer joining remain deferred/unperformed. The unchecked
3.1 client portion is preserved. No broad client/stress matrix was added as a gate;
model/headless evidence is not native-client acceptance or a real-time resource
bound. Follow the integrated checklist in `docs/player/editor.md` on a backup save.

This post-publication bookkeeping file and completed RD6 checkmarks are excluded
from the package inventory. Their follow-up commit does not move the release tag
or modify the tested/uploaded archive. Immutable release source and the branch's
later bookkeeping head are intentionally distinct.
