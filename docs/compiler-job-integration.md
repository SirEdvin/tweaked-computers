# Bounded compilation and durable reconstruction

Compilation uses the existing Phobos frontend in one bounded synchronous pass.
It does not save tokenizer, parser or emitter execution. Running programs and
Console commands still use durable continuation ABI 9.

## Production path

`compiler.prepare(source, context, mode)` validates source and lowers its AST
without parsing it a second time. The shared validator skips legacy literal
quoting, source joining and accumulated expression/statement output; it retains
the same language checks and source diagnostics. Only actual durable emission
is charged as generated text. Native loading checks only the emitted durable
backend, not a discarded whole-handler wrapper. Consequently the wrapper's
native local-register ceiling no longer restricts durable-cell programs.
`compiler.compile` remains the explicitly non-durable internal test/legacy path;
production activation and scheduler dispatch use `prepare`.

Program validation finishes before retiring the previous run. A rejected
candidate preserves its saved source, editor draft and previous active generation.
Reconstruction refusal retains the exact program/Console invocation and its
memory owner instead of releasing an unfinished handler. It reports a recoverable
resource diagnostic with the applicable setting. The request remains blocked
until the compile, host, maintenance, host-memory or host-depth policy changes,
or host-memory usage falls after a memory refusal; it is not recompiled every
tick under unchanged pressure. Stop and explicit replacement remain available.

Cache entries are private and bounded by the existing cache setting. Source work
is admitted before hashing or copying, even on warm peers. The original immutable
source is the key, not another source-sized composite string; only its most recent
backend/mode/depth variant is retained. A variant mismatch recompiles rather than
reusing executable authority. Warm peers replay the remaining frontend charges
after the common source charge, preserving exact cold admission and refused
prefixes. Lowering host depth cannot reuse a proof obtained under a higher limit.
Saved generated text and prototype completion flags never acquire execution
rights. The tiny obsolete-cursor facade refuses without traversing its input;
retained source is recoverable through the ordinary frontend. The prototype
machine, native artifact loader, generated modules, generator and cursor-progress
success fixtures have been removed. Hostile-cursor rejection tests remain.

Preparation admits its temporary owner before cache lookup or parsing, so an
already-full host account cannot allocate the frontend before refusing. Native
syntax loading reserves the existing generated-artifact weight on that owner.
Warm preparation makes the identical reservation without loading again. One
cleanup path releases the owner on success, syntax/work refusal or loader error.
Refusal holds snapshot host usage after cleanup, not the transient diagnostic
usage, so releasing the compiler's own workspace cannot cause a retry loop.
Standalone compiler callers without world storage use a transient account under
the same setting, without initializing world storage. Malformed existing storage
does not select that fallback. These are deterministic accounting units, not a
calibrated measurement of native heap usage or complete frontend allocation.

The compiler uses the parser's tokenizer directly instead of discarding a separate
whole-source identifier-validation scan. A private tokenizer callback still checks
every identifier, including field/parameter/label names; quoted data keys are not
identifiers. Console expression probing retains its statement fallback and admits
the `return ` prefix before copying. First-line diagnostics remove that prefix's
offset, and real EOF coordinates preserve CRLF/BOM source positions.

Tokenization now shares that owner: state/token records, new fields, decoded-part
vectors, lexical diagnostic records and position copies reserve before growth.
Input-sized source slices and decoded joins reserve their header/payload before
native copying; copy/join work is prepaid too. This covers quoted/block strings,
comments, identifiers, numbers, whitespace, shebangs and malformed-token paths.
Block-comment recognition no longer copies its delimiter padding twice. Fixed
single-character probes and native allocator buffers are not a calibrated heap
bound; parser mutation/validation temporaries still need separate coverage. The parser
driver admits its root vectors, trivia lists/slots and EOF records. Its scanner
functions are module-local rather than recreated closures; one protected cleanup
clears scanner roots without allocating a `table.pack` result carrier.

AST constructors reserve node records, their possible field slots and lazily
created default vectors before growth, using the same 192/table and 48/field
weights. Optional slots are conservatively reserved even when absent; this
capacity lasts until the synchronous parse ends. Intrusive statement lists also
reserve roots, neighbor/index slots and rebuilt lookup tables. This covers the
constructors, not every later parser/validator mutation. Token construction now
uses direct branches instead of creating a dispatch table and closures per token;
valid operator construction no longer assembles an unused error string.

The lowering pass reserves its table workspace before growing it: initial graph
maps, block/branch records, lexical/capture/prototype metadata, expression and
assignment vectors, and output indexes, as well as live/definition sets,
predecessor lists, propagation records and cleanup-index containers. These use
the existing private-graph weights (192 per table, 48 per field). Reusing an
existing map field or vector slot does not charge it again; new fields are
admitted before publication. Reservations conservatively remain until the synchronous pass
ends, including records that become garbage earlier. This is a temporary arena,
not a per-tick credit or a new node/count quota. Unneeded empty fallback tables
are no longer allocated while traversing terminal edges.

Durable emission also admits string payloads before quoting, concatenation and
cleanup-reference slicing. Quoting reserves the string header, enclosing quotes
and at most four escaped bytes per input byte; joins reserve their output header
and payload (including separator bytes and bounded compiler-index text). One
reused, capacity-accounted parts vector avoids allocating a fresh table for each
concatenation. These reservations share the same temporary owner and proof;
they are not a source/string-length quota or a calibrated bound on native
formatter/concatenation allocator buffers.

The private cache proof interleaves work charges and byte reservations. A warm
pass batches them only when both complete allowances fit; otherwise it replays
their original order, preserving the first refusal and paid work prefix when
both resources are short. Work-only legacy proofs keep their existing replay
path. Neither the saved-frame ABI nor generated handler behavior changes.

## Source retention

Saved source and active source/handler metadata have separate owners on the
existing host-memory ledger. Immutable payloads shared between computers or saved
and active revisions are charged once, with a link for each owner. Save proves
the complete replacement before changing source/revision; activation admits its
source metadata before retiring the previous run. There is no `source_bytes` cap.
A shorter document can still require growth if other owners retain its old text.

Lowered settings preserve accepted ownership. Stop retains active source for
recovery; removal retires its owners for work-metered maintenance cleanup.
Material replacement restores accepted source as grandfathered usage without
transferring a live invocation. Legacy ownership enrollment publishes only after
all records succeed, and rolls back temporary owners on refusal.

## Verification

`tests.compiler_policy_guards` checks that durable validation does not quote or
join legacy executable output, and compares invalid-source diagnostics with the
legacy path for both program forms and Console. This is an allocation reduction,
not proof that all remaining parser/lowering/native allocations are admitted.
The same fixture observes admission before actual quoting/joining during durable
emission, including long literals with NUL, control characters, quotes and
backslashes in both program forms and Console.
Lexical probes observe native slices/joins, verify decoded bytes and source forms,
and refuse one byte before each recorded allocation boundary with exact paid work
and complete temporary-owner cleanup. Cache probes cover every recorded frontend
allocation in the rich-language case as well as lowering, preserving warm/cold
first refusal under competing shortages. Single-frontend probes count actual
tokenizer starts for both source forms and Console, preserve forbidden-identifier
and EOF locations, and refuse the Console prefix before parser entry.
`tests.compiler_ast_memory`, invoked by the same guard fixture, checks default
and fully populated constructor graphs, caller-owned aliases, token payload
semantics and every recorded one-byte-short reservation. List probes exercise
append/prepend, both middle-insertion directions, actual lookup rebuilding,
removal and clearing, with exact refusal work and complete owner reclamation.
These private parser structures are discarded on refusal; they are not saved
continuations or an independently atomic list-edit API.

`tests.compiler_bounded --cold` covers recoverable compilation refusal,
220 durable locals, warm-cache host-depth reduction, prior-run preservation,
program and Console reconstruction refusal, no unchanged-policy retries, and
separate-process recovery without repeating the completed prefix.

`tests.compiler_native_memory --cold` adds lowered host-memory refusal to those
same program/Console lanes, preserving the original work-refusal cold case.
Its memory case measures both frontends and observes actual lowering entry (not
an allocation-size proxy), permits the compiler owner but refuses inside lowering, then
cold-resumes the unchanged program and command without repeating their prefix.
`tests.resource_policy_compilation_cache` checks equal warm/cold memory refusals,
one-byte-short admission, full-host refusal before parsing, release on parser,
work and native-loader failures, and retry after either raising the setting or
releasing other host ownership.
It additionally checks initial graph, block, operand, quoted-literal, liveness and final generated-text
reservations with memory pressure alone and competing work pressure, including
exact diagnostic fields and release of every temporary reservation. The source
exercises nested closures, captures, varargs, constructors, both for-loop forms,
while/repeat, branches, concatenation and multiple assignment.

`tests.resource_policy_sources --cold` covers shared source payloads, atomic Save
and activation refusal, grandfathered replacement, ownership across native cold
reload, material restoration and interrupted cleanup. Its legacy-enrollment case
uses a constructed pre-ownership record, not a pre-release save migration.
`tests.lifecycle_engine --production-context --cold` additionally exercises real
robot mining/replacement with saved and active documents above the former 16 KiB
ceiling in base and Space Age.

Existing cache/activation/runtime, protected nested-call cold and production
program/Console cold fixtures remain applicable. Connected `nested-console`
acceptance uses `tools/resource_policy_multiplayer.py` with two full clients and
independently compared server/client state. This does not cover partial broadcast
joining, audible output or complete UI acceptance.

## Remaining implementation boundaries

Pinned-engine allocation observations are preserved in
`/home/siredvin/artifacts/tweaked-computers/compiler-headroom-2d7ye56w`.
The test-only observer measures ordinary-GC and GC-paused Lua-accounted growth,
plus matched whole-engine peak RSS; it never uses GC readings in production
admission. The accepted 900-increment declaration case grows about 36.97 MiB
across native loading with GC paused, versus 4.07 MiB in native accounting units.
A 3,000-increment source refused for compile work still reaches about 117.69 MiB
of ordinary-GC sampled growth before refusal. These cases disprove treating the
existing weight as a calibrated heap bound. Paused-GC growth includes garbage,
ordinary samples can miss intra-call peaks, and process RSS includes engine
startup/map generation; none is a universal worst-case bound. No multiplier or
production budget was raised to fit these observations.

This is not completion of the full resource-policy change or task 4.4. Console
ingress and other downstream storage guards still need reconciliation. Compiler
temporary allocation coverage (later parser AST mutations/validation, closures, diagnostic text
and proof metadata) and measured native headroom remain incomplete; lexical,
AST-constructor, lowering-table, emitted-payload
and native-load reservations do not establish them. Full migration and host-domain
enrollment also remain open. Resolve these before claiming complete resource
safety; do not restore the deleted compiler machine to solve them.
