# Native radar asset transformations

Source engine: Factorio 2.0.77 build 84539. The ordinary radar prototype is not
modified. The advanced tier is guarded by Space Age and deep-copies that native
prototype in `prototypes/radar.lua`; no extracted image, sound or distribution is
shipped in the mod.

Native source definitions are the installed base `prototypes/entity/entities.lua`
radar and the native radar circuit-connector definition. Native graphic references
include the radar body, shadow, integration patch and water reflection. Any
Space Age frozen patch present at the mod's data-stage load is transformed too.
The composed item/research icon uses native radar and space-science-pack paths.
The existing six-device Service Rack provenance remains unchanged.

Reproducible transformation: multiply each native sprite's scale and shift by
1.5. Apply that same transformation to connector sprites and multiply red/green/
copper wire and shadow contact vectors by 1.5. Preserve frame dimensions, direction
count, animation rotation speed, native scanning and sounds. Replace the selection
box with ±2.5 tiles and collision box with ±2.2 tiles: a whole-tile 5×5 occupied
footprint rather than a misleading scaled 3×3 box. Use dedicated mined item and
clear fast-replacement/upgrade hints; keep native placement constraints.
Space Age applies vanilla radar's 300 kW heating field in its later
`base-data-updates.lua`; the advanced copy explicitly retains that same pinned
native heating/freezing constraint rather than accidentally bypassing it.

Data-stage assertions check the scale, boxes, six-pack research, recipe unlock and
native-only graphic paths. These assertions do not prove appearance. Final native
client screenshots and sampled animation are tracked separately by the feature's
acceptance ledger; until that evidence is complete, do not interpret prototype
loading as visual acceptance or llvmpipe captures as representative GPU FPS.

See the [modem reference](api/modem.md) for research, recipe, power and platform
routing, and [Service Rack artwork](artwork.md) for the unchanged authored devices.
