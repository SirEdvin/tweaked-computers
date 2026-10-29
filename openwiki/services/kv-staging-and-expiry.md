---
type: service
title: KV atomic staging, expiry and carried data
description: Physical-local byte-string/hash storage with whole-command publication, absolute simulation expiry, bounded reclamation and validated item snapshots.
tags: [kv, persistence, expiry, staging, services]
sources:
  - id: openwiki-source-44e1570dfd85eaa2de9f98b0
    resource: repo://scripts/services/kv.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
verified:
  - by: openwiki/0.7.1
    at: 2026-10-29T22:50:29.161Z
---

# KV atomic staging, expiry and carried data

## State belongs to the physical database

`services/kv.lua` registers a fixed `kv` peripheral binding and a `tc_kv` material adapter. `rec.database` is a plain versioned record with entries, sorted key order, content bytes, total hash fields and reclamation cursor. Two computers reaching the same physical database see the same contents; two databases do not share a global keyspace. Stop/restart of a computer does not clear the peripheral's contents. Access still passes the [current peripheral authority/power checks](../network/discovery-and-authority.md).

This is local strings/hashes only, not Redis/network I/O. Keys, fields and values are byte strings without numeric coercion; empty or NUL-containing keys are valid within byte limits. Wrong-type string/hash commands fail explicitly. Native guest tables are not retained as arbitrary database values. `getLimits` reports the service's own capacities and common call ceilings; do not assume computer-state ceilings equal KV capacities.

## A mutator publishes once

Reads use `live(d,key,tick)` and never need a sweep to know that a deadline has expired. Mutators validate arity, all operand types/bytes and expiry range before constructing a candidate. `stage` walks the bounded existing index and carries only live entries into a fresh database. Existing entry records/field maps are immutable until publication: hash changes copy fields, and deadline changes copy the entry.

`publish` sorts the candidate key order, recomputes total key/content bytes and hash-field counts, checks all capacities and spends before replacing `rec.database` once. A type/capacity/admission failure therefore leaves original values, deadlines, counters and index aliases intact. Logical capacity excludes expired entries even if maintenance has not reclaimed them yet.

`set` replaces the whole value with a string entry and clears any previous expiry. Hash updates preserve an existing deadline and delete an empty hash. Multi-field updates/deletes execute in request order against the private candidate and count genuinely inserted/removed members; repeated operands do not become independent physical copies. This is a command-local atomic guarantee, not a cross-database transaction or rollback of earlier successful commands in the same callback.

## Simulation time, not wall time

Positive `expire` seconds become `tick + seconds * 60`, bounded to safe integer range; nonpositive expiry deletes an existing key. `persist` removes a deadline. A key is live only while `tick < deadline`. `ttl` returns -2 for absent, -1 for no deadline, otherwise nearest simulation seconds (half-up), so a still-live key may return zero near its deadline.

Absolute deadlines survive world saves and material carrying. Carrying a database item does not pause or renew expiry, and pausing real time without advancing simulation does not age its keys. Snapshot import validates the absolute deadline rather than converting it to a new relative lifetime.

Physical reclamation is only maintenance: the render-phase sweep visits at most two eligible devices and eight indexed keys per device per tick, with a retained fair cursor and work reservation before each removal. It can operate independently of database power. Unsupported/guarded retained databases are excluded. Changing this sweep must not change the guest-visible `live` predicate or let expired content consume logical mutation capacity.

## Mining/import must not destroy malformed data

Initialization creates an empty database only when none exists, then audits retained records. The audit checks a dense one-to-one index, unique keys, entry types/deadlines, hash counts/bytes and aggregate accounting. Failure marks the body unmineable with `unsupported-database`; calls fail closed and maintenance skips it rather than guessing a repair.

Mining snapshots dense entry records with original byte keys as values, sorted hash-field records and absolute deadlines. It audits before snapshot and validates that snapshot through the same importer before enabling destructive mining. Import rejects unknown shapes/versions/types, duplicate keys/fields, bad deadlines and content/metadata overflow, builds a fresh candidate and only then publishes. This prevents aliasing, duplicated database contents from blueprint/script tags and silent index loss.

The [physical lifecycle](../devices/ownership-and-lifecycle.md) writes the snapshot into the actual mined material stack before unregistering; restoration reads only a consumed material item. Blueprint/clone flows do not duplicate KV contents. Destruction is explicitly destructive; do not describe it as a portable-data path.

## Extension and tests

New commands belong in the closed method/arity tables and must preserve preflight → candidate → complete capacity/accounting → single publish. Never mutate an old entry in place while staging. New snapshot versions require deliberate import policy, not clearing unsupported contents.

`tests/kv_engine.lua` includes compact command, expiry/capacity/aliasing and native mining/cold-load scenarios; lifecycle/integration fixtures cover physical shared/independent stores. They are source coverage references, not new test runs made during this documentation-only change. See [targeted operations](../operations/build-test-and-assets.md).
