# Radar workloads, progression and recovery

Use the [generated modem reference](api/modem.md) for calls, fields and routing.
These operational notes preserve the workload and balance context; they do not
claim new timing, graphical or multiplayer acceptance.

## Competing factory workloads

The packaged competition scene combines four 6×6 charts, one maximum-size
transmission to eight handler registrations every 15 ticks, and a live logic
controller polling every 15 ticks. This is not a promise that every independent
cap can be saturated simultaneously. In particular, the separate lossless
every-tick logic subscription can visibly refuse with `E_BUSY` under full-wall
maintenance pressure; owned outputs fail closed rather than losing observations.
Polling/reapplying an appropriate controller or reducing workload is explicit
player recovery, not an automatic change to a saved program. Headless publication
intervals and a 30 FPS recording are not measured client FPS.

## Space Age progression

With Space Age 2.1.23 enabled, research **Interplanetary radar modems**. Research
requires exactly automation, logistic, chemical, production, utility and space
science: 500 units, one of each pack per unit, 30 seconds. No military or
planet-specific pack. Prerequisites are circuit computers and the production,
utility and space-science technologies. The recipe is initially disabled and
unlocks with research; reconciliation preserves an already researched force's
unlock without granting research to others.

Craft one radar, 20 steel plates, 20 processing units and 10 low-density structures
in 10 seconds. The advanced radar consumes 1 MW, uses a 5×5 footprint and about
1.5× native radar visual scale. These are initial balance choices, not measured
balance claims. Scanning radii remain native. Body, shadow, integration/reflection
and wire contact transformations reference installed native assets; no Factorio
assets are bundled. See [transformation provenance](radar-native-assets.md).
The advanced entity retains the pinned native 300 kW heating requirement on
freezing surfaces, separately from its 1 MW electrical consumption.

## Upgrade and recovery

Version 0.1.16 partitions previously registered radars out of generic ticking
before the first ordinary tick after upgrading 0.1.15. No mining, rewiring or
gameplay cleanup sweep is required. Ordinary cold reload preserves that separation.
Dormant records still use memory/save space and count toward identity capacity;
Factorio's own native radar simulation is unchanged.

Back up the save and complete mod set before upgrade. Roll back by restoring that
backup with its prior mods. Older code assumes a different registry layout, so do
not downgrade a newly saved 0.1.16 world in place. Downgrading a live save or removing Space Age is not
promised lossless: advanced entities/research can disappear. Unknown/corrupt modem
state is retained inert with `E_UNSUPPORTED`, not silently reset.
