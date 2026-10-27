# Peripheral discovery Lua API v1

Normative companion to [spec.md](spec.md). Shared types/errors: [common.md](../../api/common.md).

## Discovery and calls

| Signature | Returns | Semantics |
| --- | --- | --- |
| `peripheral.getNames(wire)` | `string[]` | Complete sorted unique names on explicit `"red"` or `"green"`; empty is a successful complete empty result |
| `peripheral.isPresent(name, wire)` | boolean | Physical current reachability; an unpowered device can still be present |
| `peripheral.getType(name, wire)` | string or nil | One of `monitor`, `kv_database`, `logic_handler`, `configurator`, `recipe_searcher`, `factoriopedia_interface`, `modem`, `speaker`; nil if not present |
| `peripheral.getMethods(name, wire)` | `string[]` or nil | Sorted public method names; includes declared aliases |
| `peripheral.describe(name, wire)` | `PeripheralInfo` or nil | Current public metadata, even while unpowered |
| `peripheral.wrap(name, wire)` | wrapped table or nil | Ephemeral dot-call method facade bound to name, entity generation and selected channel |
| `peripheral.call(name, wire, method, ...)` | method returns | Equivalent to a current checked wrapped-method call; unknown method is E_ARGUMENT |
| `peripheral.find(type_name, wire)` | zero or more wrapped tables | Multiple returns in sorted-name order, not one array; `{ peripheral.find(...) }` collects them |
| `peripheral.getName(wrapped)` | string | Validate an actual wrapped facade and return its bound name |
| `peripheral.getWire(wrapped)` | `Wire` | Return the facade's bound discovery color |

The explicit wire argument has no implicit default or `"both"` mode. A caller may inspect each color separately, but the runtime never constructs a path that changes color. Target metadata operations still require same-force/surface current path authority. `getName` and `getWire` only inspect a genuine facade's already-known binding and remain usable after detach; they grant no target access. A traversal that is incomplete throws E_NETWORK_PENDING/E_LIMIT; it is never reported as empty or absent.

```text
-- Documentation record; no LuaEntity/connector objects are included.
PeripheralInfo = {
  name = PeripheralName,
  type = "monitor" | "kv_database" | "logic_handler" | "configurator" | "recipe_searcher" | "factoriopedia_interface" | "modem" | "speaker",
  label = string | nil,
  powered = boolean,
  position = { x = number, y = number },
  surface = { index = integer, name = string },
  quality = string,
  direction = "north" | "east" | "south" | "west",
  footprint = { width = integer, height = integer },
  wire = Wire
}
```

Positions use Factorio world coordinates, not integer tile guesses. Monitor position/footprint describe its current logical rectangular group; footprint width/height are axis-aligned world extents, whereas terminal dimensions use display-local axes. Labels are descriptive and need not be unique. No API enumerates all force-wide computers or bypasses wires via coordinates.

Every device exposes `getLimits()` for its documented effective capacities. This static metadata method is available while unpowered if the binding is reachable; active read/write methods otherwise throw E_UNPOWERED. There is no generic raw property accessor or arbitrary method forwarding.

## Reachability rules

Only real physical wires between this mod's public computer-network connectors, supported native radar sockets and vanilla programmable-speaker sockets participate. Radar-origin hidden links are excluded from discovery and witness revalidation, including paths through speakers; radio messages carry data, not remote authority. Computer entities can be passive graph vertices but are not exposed as a programmable peripheral type in v1. Red/green graphs are independent. Input/output/target connectors, other vanilla poles/devices, ghosts, foreign forces and other surfaces do not relay discovery. Unknown external wires are left intact but ignored for discovery.

A merged monitor is one service identity discoverable through any reachable member. Its shared framebuffer is not an implicit network link between disconnected members or colors. KV access over both colors likewise exposes one database, not a color bridge.

A wrapper is not durable Data. Retain its opaque name and selected wire in computer state if needed, then wrap again in a later callback. A captured method is legal only within a callback and still revalidates authority at every call. Removing and replacing a device produces a new identity, even at the same position or with the same label. A topology cache must fail closed until current authority is proved.

The [Console-only exception](../console-shell/lua-api.md) retains authentic wrappers/captured peripheral methods through private symbolic descriptors, never saved functions or ordinary Data. Each use still proves live identity, generation, wire, power and scope. [Monitor synchronization selection](../monitor-display/buffering-api.md) adds the strict `setMonitorSyncGroup` / `getMonitorSyncGroup` dot calls, without granting discovery or exclusive drawing authority.

## Attachment events

Register through `computer.on("peripheral_attach", "attached")` and `computer.on("peripheral_detach", "detached")`.

```text
-- Both extend BaseEvent.
PeripheralAttach = {
  name = "peripheral_attach", peripheral = PeripheralName,
  peripheral_type = string, wire = Wire
}
PeripheralDetach = {
  name = "peripheral_detach", peripheral = PeripheralName,
  peripheral_type = string, wire = Wire,
  reason = "wire_removed" | "removed" | "regrouped" |
           "force_changed" | "surface_changed" | "limit" | "unavailable"
}
```

These names are transition notifications, not an inventory snapshot on registration. Call getNames after registering if an initial inventory is needed. Per `(computer, peripheral, wire)` publish detach before a replacement attach; deterministic names order simultaneous transitions. Power loss alone is not physical detach. Detach revokes authority before guest delivery and runs output fail-safe cleanup regardless of whether a handler exists. Already detached handles never revive merely because a new entity uses an old label.

Monitor touch/resize events deduplicate a logical display per computer registration and carry a sorted `wires` array of its currently valid channels. `wire` equals that array's first entry for convenient binding; clients may explicitly choose another listed channel. This is not merged-color reachability.

## Example: inspect both channels without bridging them

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      for _, wire in ipairs({ "red", "green" }) do
        for _, name in ipairs(peripheral.getNames(wire)) do
          local info = peripheral.describe(name, wire)
          if info then
            computer.log(wire .. " / " .. name .. " / " .. info.type)
          end
        end
      end
    end
  }
}
```

## Required cases

Same-color chain; red-to-green nonpath; vanilla/ghost/foreign-force relay refusal; both-color duplicate identity; powered versus unpowered discovery; invalidation between lookup/call; incomplete traversal refusal; monitor merge/split wrapper invalidation; saved names after new entity placement; shared writes; no signals encoded on discovery ports.
