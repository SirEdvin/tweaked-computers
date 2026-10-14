# Planning validation

This report concerns planning artifacts only. The production mod has not been implemented or tested in Factorio.

## Executed checks

- OpenSpec strict validation passed with no reported issues; status reports proposal, specs, design and tasks complete.
- Verified 8 capability specifications, each with its own Lua API/workflow companion: 67 requirements and 101 scenarios in total.
- Extracted all 9 executable Lua examples and checked them with the actual Lua 5.2.4 reference compiler. Evaluated each literal descriptor under an empty environment and verified API version, handler shape and named registration references. No handler was executed and no API effects were mocked or claimed.
- Compared every inherited writable field against the pinned Factorio runtime schema: 36 control-behavior classes and 164 effective writable entries, plus structural equality for 29 nested concepts and all values in 10 enum groups.
- Checked all 16 monitor palette constants/masks against pinned upstream values; exercised the documented signed-32-bit arithmetic, TTL rounding and character-geometry formulas with reference calculations.
- Verified selected repository file hashes and all 14 immutable Redis command document hashes against the source manifest.
- Checked local document links, paired Markdown fences and task IDs. All 38 implementation tasks remain unchecked and include verification criteria.
- The final audit completed with an empty errors list. Machine-readable results are retained in [research/planning-checks.json](research/planning-checks.json).

## Commands and reproducibility

```text
openspec validate add-native-circuit-computers --strict --json
openspec status --change add-native-circuit-computers --json
```

The supplemental audit ran from the research workspace using `check_plan.py` and a locally built reference Lua 5.2.4 compiler. It extracted code fences into scratch files, used `luac -p`, loaded only descriptor factories with an empty environment, and compared the catalogue to the pinned source JSON. Its per-example source hashes and actual counts are in the retained results. The temporary toolchain is not a dependency of the proposed mod; Factorio's modified 5.2.1 environment still needs its own tests.

## Findings corrected during the audit

A pseudotype block was initially marked as executable Lua; its fence was corrected rather than weakening Lua syntax validation. Two task-verification keyword false positives were corrected to recognize the explicit words prove/confirm. The final consistency review also clarified subscription admission/resync baselines, detached-facade metadata, aggregate-limit keys and the monitor scale error code.

## Explicitly not verified

No production callback compiler/sandbox, composite prototypes, circuit behavior, rendering/input, gameplay balance, full configurator implementation, cold Factorio reload, multiplayer run or distributable artwork has been exercised. Reference Lua syntax/factory checks do not establish those properties. All implementation tasks remain unchecked.
