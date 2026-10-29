# Exact optional dependency for CI

This directory is **test-only**. `tools/build.py` packages an explicit runtime
inventory that does not include `.github/`; the chart mod is not embedded in
Tweaked Computers and remains an optional external installation for players.

`factorio-charts_1.2.0.zip` is the unchanged published Mod Portal archive supplied
for the Dashboard integration. The original MIT license is included separately
as `LICENSE` and remains inside the ZIP.

- Mod Portal: `https://mods.factorio.com/mod/factorio-charts`
- Release download path: `/download/factorio-charts/6a945b6a78d6b8a65e654836`
- SHA-1: `57e2e88c0f88e03b75ceff3b2ad5dfc79980a444`
- SHA-256: `32b1683912281812c122d6b414d15ab553e943138ceb2b27fe52a38ee6512815`
- Manifest: `name=factorio-charts`, `version=1.2.0`, `factorio_version=2.1`.
- Inspected upstream commit: `ff7f6bd06a4532c8cd2bfbf0a4bd464916dbb62a`.
  All Lua files and the license match byte-for-byte. The published manifest has
  LF rather than CRLF; the published changelog has different release date/text.
  This archive was not rebuilt from the Git tag.

CI verifies the SHA-256 before explicitly installing this ZIP only in
present-library cases. This avoids a Portal download login or an additional
release/hosting dependency. Absence cases do not install or enable it.
