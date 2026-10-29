# 0.1.18 ALPHA — Factorio 2.1 patch compatibility

Install `tweaked-computers_0.1.18.zip` from **alpha-0.1.18**, not GitHub's automatic
source archive; leave the mod ZIP unextracted.

- Accept any Factorio **2.1** patch instead of requiring exactly 2.1.23:
  `base >= 2.1.0`, optional `space-age >= 2.1.0`, and `factorio_version: "2.1"`.
- Keep optional `factorio-charts >= 1.2.0` unchanged.
- Runtime code, APIs and save behavior are unchanged from 0.1.17.

Verification is on **2.1.23** in base and Space Age, not every past or future 2.1
patch. The wider dependency range is not a claim that every patch is tested.
This metadata-only release does not repeat the full graphical or multiplayer
campaign; earlier evidence retains its original version and scope.

Back up saves and matching mod ZIPs before upgrading. The [0.1.17 computer-item
compatibility break](release-0.1.17.md#breaking-computer-item-change--back-up-first)
still applies: computer items are plain hardware, and ordinary pickup/replacement
loses their contents. Stay on 0.1.14 for Factorio 2.0.77.
