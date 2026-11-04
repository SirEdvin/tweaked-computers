---@meta

---Transient guest-owned plain table or detached snapshot. Helpers reject protected
---namespaces/facades and foreign tables. Transient reference keys, aliases/cycles
---are possible, but ordinary Data and Console retention have stricter rules.
---@alias TC.GuestTable table<TC.GuestValue, TC.GuestValue>

---Number or numeric string accepted by guarded numeric helpers only. Strings
---must convert to numbers; finite operands/results are required where stated.
---This helper compatibility does not add coercion to computer/peripheral APIs.
---@alias TC.Numeric number|string

---Packed transient argument tuple, not a dense Data array when it contains nil.
---@class TC.Tuple
---@field n integer Exact number of positions, including trailing nil.
---@field [integer] TC.GuestValue One-based nonnil value at that position; holes represent nil.

---Iterator callback shape. On a present entry returns key,value; termination
---returns exactly one nil, not zero results. Not a persistable function value.
---@alias TC.Iterator fun(t: TC.GuestTable, previous: TC.GuestValue): ...: TC.GuestValue

---Fixed guest language-family label, not unrestricted Lua 5.2 compatibility.
_VERSION = 'Lua 5.2'

---Return the Lua type name; omission is treated as nil. No native object access
---is granted. Standard helpers still pay argument/result tuple/work bounds;
---extra arguments follow each native helper's handling rather than service arity.
---@param value? TC.GuestValue Value to inspect; omission/nil has type nil.
---@return 'nil'|'boolean'|'number'|'string'|'table'|'function' name Guest-visible primitive kind.
function type(value) end

---Stable safe formatting: tables become table, protected handles API handle,
---guest functions guest function, approved callables their stable label. Never
---addresses, recursive inspection or metatable calls. Omission formats nil.
---@param value? TC.GuestValue Approved value to describe without exposing internals.
---@return string text Bounded safe description or primitive representation.
function tostring(value) end

---Convert a number or bounded numeric string, returning exactly one nil for an
---ordinary invalid value. With explicit base, require a string and integer base
---2..36; invalid base/type is a catchable argument failure. Omitted/nil base uses
---ordinary numeric conversion. Conversion does not widen API numeric domains.
---@param value? TC.GuestValue Number/string to convert; other ordinary values yield nil.
---@param base? integer Optional integer radix 2..36; nil uses normal conversion.
---@return number|nil number Converted number, or exactly one nil on invalid text/value.
function tonumber(value, base) end

---On truthy value return value followed by the exact supplied trailing tuple,
---including nil holes. On false/nil raise the first trailing value or the native
---assertion message. This is ordinary failure, not a transaction rollback.
---@param value TC.GuestValue Predicate; only false and nil fail.
---@param ... TC.GuestValue Trailing results; first is used as failure message when truthy.
---@return TC.GuestValue value Identical successful predicate value.
---@return TC.GuestValue ... Identical trailing positions, possibly zero.
function assert(value, ...) end

---Does not return normally. Raise an ordinary guest error, including explicit
---nil or a guest value; no source-level argument is exposed. Protected calls may
---catch it. Prior state/output/peripheral effects remain committed.
---@param value? TC.GuestValue Error value; omission behaves as nil.
function error(value) end

---Call an approved function with exactly the trailing tuple. Success returns
---true followed by every original result; ordinary failure returns false and
---exactly one safe error. Guest-owned table errors preserve identity; unowned
---error records are defensively copied. Unlike xpcall, throwing a protected API
---handle makes pcall's own error-snapshot step refuse with E_ARGUMENT rather than
---returning that handle. Status counts toward tuple width. Fatal
---budget/stop control always escapes and never becomes a guest error value.
---@param fn TC.Callable Approved function, not an arbitrary native callable.
---@param ... TC.GuestValue Exact forwarded arguments, preserving nil and aliases.
---@return boolean ok True on normal completion; false on ordinary failure.
---@return TC.GuestValue ... Success results (possibly zero) or exactly one safe failure value.
function pcall(fn, ...) end

---Protected call with an approved message handler. Forward exact trailing
---arguments; success is true plus exact results. Ordinary failure calls handler
---with one safe error and returns false plus ONLY its first result (one nil when
---it returns no values). Native handler re-entry is bounded; wording of an error
---inside the handler is not stable. A fatal function suppresses the handler;
---a fatal handler suppresses later handlers/effects. Neither can swallow quotas.
---Guest-owned tables and authentic protected-handle errors preserve identity;
---unowned host error records are copied. This differs from pcall's handle refusal.
---@param fn TC.Callable Function to call under ordinary-error protection.
---@param handler TC.Callable Error transformer receiving one safe failure value.
---@param ... TC.GuestValue Exact arguments forwarded only to fn.
---@return boolean ok True on completion; false after ordinary failure handling.
---@return TC.GuestValue ... Exact success tuple or exactly one transformed failure value.
function xpcall(fn, handler, ...) end

---Append one Console entry using safe tostring joined with tabs, without an
---added newline. Zero arguments append an empty entry. Returns no values.
---Complete formatting/admission occurs before append/eviction; oversized output
---is E_LIMIT with no partial entry. Earlier output survives later failures.
---Saved output uses computer.log; Console retains shell attribution. Native
---display shows tabs as spaces without changing raw retained/copyable bytes.
---@param ... TC.GuestValue Ordered values to format; nil and false are retained.
function print(...) end

---Raw lookup in a guest-owned table. Require both arguments; explicit nil or NaN
---key returns one nil. Return the identical stored value, without copying or
---metamethods. Protected namespaces/facades and foreign tables are refused.
---@param t TC.GuestTable Guest-owned plain table, not a protected API handle.
---@param key TC.GuestValue Required key position; explicit nil/NaN means absent.
---@return TC.GuestValue value Exactly one stored value or nil; aliases are retained.
function rawget(t, key) end

---Raw guest-table assignment with ordinary indexed-write ownership, key, value,
---growth, work and allocation checks before mutation. Require all three positions;
---nil value deletes. Nil/NaN keys are invalid. Replacement/deletion at full width
---is allowed when admitted. Refused writes leave every alias unchanged.
---@param t TC.GuestTable Mutable guest-owned plain table.
---@param key TC.GuestValue Valid nonnil, non-NaN guest key, including transient references.
---@param value TC.GuestValue Required value position; nil deletes the key.
---@return TC.GuestTable table Identical input table, not a defensive copy.
function rawset(t, key, value) end

---Require one argument. Byte length for strings; native border for guest tables,
---not map cardinality. Protected API tables and foreign values are refused.
---@param value string|TC.GuestTable Bounded byte string or guest-owned plain table.
---@return integer length Nonnegative byte length or native sequence border.
function rawlen(value) end

---Require both positions, including explicit nil. Compare approved guest values
---with raw identity/equality; no copies or metamethods. Authentic facades and
---functions can be compared without exposing their protected fields.
---@param a TC.GuestValue First approved value.
---@param b TC.GuestValue Second approved value.
---@return boolean equal Whether native raw equality holds.
function rawequal(a, b) end

---Return the trailing tuple width for '#', or its suffix at a nonzero integer
---index. Positive beyond-end index yields zero values; negative indexes count
---from the end. Index/tuple bounds are enforced; zero and too-negative indexes
---fail. Nil positions are never collapsed.
---@param index integer|'#' Required selector; integer within the tuple domain.
---@param ... TC.GuestValue Ordered input tuple, possibly empty.
---@return TC.GuestValue ... Suffix positions or one integer width for '#'.
---@overload fun(index: '#', ...: TC.GuestValue): count: integer # index '#' selects count: the exact number of trailing positions, including nil; returns one integer.
function select(index, ...) end

---Advance native guest-table iteration. No ordering guarantee. First call uses
---omission/nil key. A present entry returns key,value; completion returns exactly
---one nil. Invalid previous key and protected/foreign table access fail normally.
---@param t TC.GuestTable Guest-owned table/snapshot to iterate.
---@param key? TC.GuestValue Previously returned key; omission/nil starts iteration.
---@return TC.GuestValue key Next nonnil key on a present entry.
---@return TC.GuestValue value Identical value at that entry.
---@overload fun(t: TC.GuestTable, key?: TC.GuestValue): absent: nil # Iteration completion returns exactly one nil (absent), with no value position.
function next(t, key) end

---Return exactly iterator,table,nil for generic iteration. Values retain identity;
---this grants no access to protected/private host tables and promises no sorting.
---@param t TC.GuestTable Guest-owned table/snapshot.
---@return TC.Iterator iterator The same approved next helper.
---@return TC.GuestTable state Identical table.
---@return nil initial Explicit initial control value; this position is present.
function pairs(t) end

---Return exactly iterator,table,0. Advance integer indexes from one until the
---first absent slot; false is present. Iterator returns index,value while present
---and exactly one nil at termination. Native Logic arrays retain their domain.
---@param t TC.GuestTable Guest-owned table/snapshot.
---@return TC.Iterator iterator Approved bounded sequence iterator.
---@return TC.GuestTable state Identical table.
---@return integer initial Always zero; explicit third result.
function ipairs(t) end

---Guarded table helpers; never mutate protected facades/namespaces or host tables.
---Sequence helpers require a dense one-based sequence unless stated otherwise.
---All movement, copying, growth and callback comparisons consume existing budgets.
---@class TC.TableLibrary
table = {}

---Pack exact argument arity in n, including trailing nil. Result is a fresh
---guest-owned table; nil positions are holes, not valid persistent Data elements.
---@param ... TC.GuestValue Original ordered argument tuple.
---@return TC.Tuple values New tuple table with exact n.
function table.pack(...) end

---Return positions i..j exactly, including nil holes. Omitted/nil bounds default
---1 and #t, not t.n; use explicit packed.n to retain trailing nil. Empty range
---returns zero values. Current guest table index and tuple ceilings apply.
---@param t TC.GuestTable Guest-owned plain table; may be sparse.
---@param i? integer Start, default 1; domain 1..table_entries+1.
---@param j? integer End, default native #t; domain 0..table_entries.
---@return TC.GuestValue ... Exact requested range, possibly empty and nil-bearing.
function table.unpack(t, i, j) end

---Identical function to table.unpack, with the same stable table function label.
unpack = table.unpack

---Join a dense sequence slice. Only string/number elements are accepted; numbers
---use native conversion. Complete size/work admission precedes the output copy.
---@param t TC.GuestTable Dense sequence containing strings/numbers in the slice.
---@param sep? string Separator; omitted/nil means empty string.
---@param i? integer First position, default 1; domain 1..n+1.
---@param j? integer Last position, default n; domain 0..n.
---@return string text Joined bytes; empty range gives an empty string.
function table.concat(t, sep, i, j) end

---Insert into a dense guest sequence, moving later slots. Returns no values.
---Two-argument form appends; three-argument form inserts at pos. Capacity/work
---admission precedes mutation; no partial shifted result on refusal.
---@param t TC.GuestTable Dense mutable sequence.
---@param pos integer Position 1..n+1 for the three-argument form.
---@param value TC.GuestValue New value; nil follows native table insertion behavior.
---@overload fun(t: TC.GuestTable, value: TC.GuestValue)
function table.insert(t, pos, value) end

---Remove and shift a dense guest sequence. Always returns exactly one value,
---including nil for empty/past-end removal. Position 0 is legal only when empty;
---n+1 is accepted. This is the documented guest arity, not host helper inference.
---@param t TC.GuestTable Dense mutable sequence.
---@param pos? integer Default n; allowed 0..n+1 with the empty-only zero rule.
---@return TC.GuestValue removed Removed identical value or exactly one nil.
function table.remove(t, pos) end

---Sort a staged copy and publish only after comparisons and final capacity
---revalidation succeed. Returns no values. A comparator uses the same guest
---work/depth budget and may have side effects; those effects are not rolled back
---on failure. The table's own staged sorted slots are not partially published.
---@param t TC.GuestTable Dense mutable sequence.
---@param less? fun(a: TC.GuestValue, b: TC.GuestValue): boolean Optional approved comparator; default guarded native less-than.
function table.sort(t, less) end

---Bounded byte-string helpers, not Unicode or Lua-pattern facilities. Strings
---are immutable; input/output/work checks precede opaque native operations.
---Use dot calls: string.sub(s,...) rather than the forbidden string-method syntax.
---@class TC.StringLibrary
string = {}

---Read byte length, not Unicode character count.
---@param s string Bounded byte string.
---@return integer length Byte count including embedded NUL.
function string.len(s) end

---Slice bytes with normalized Lua-style indexes. Negative indexes count from
---the end; finite numeric strings are allowed. Omission/nil defaults i=1,j=#s.
---@param s string Bounded source string.
---@param i? TC.Numeric First byte index, default 1.
---@param j? TC.Numeric Last byte index, default length.
---@return string text Native slice result after bounded admission.
function string.sub(s, i, j) end

---Return each byte in the normalized range. Omitted/nil i defaults 1; j defaults
---i (or 1), NOT string length. Empty range returns zero values; result width is
---bounded by tuple_entries. Embedded NUL returns numeric zero.
---@param s string Bounded source bytes.
---@param i? TC.Numeric First finite byte index, default 1.
---@param j? TC.Numeric Last finite byte index, default i or 1.
---@return integer ... Byte codes 0..255 in order, possibly zero results.
function string.byte(s, i, j) end

---Construct bytes from exact integer codes; zero inputs return an empty string.
---@param ... integer Byte codes 0..255, bounded by tuple_entries.
---@return string text Constructed byte string including any NUL values.
function string.char(...) end

---Return byte-oriented native lowercase conversion, not Unicode case folding.
---@param s string Bounded source bytes.
---@return string text Independent lowercase string value.
function string.lower(s) end

---Return byte-oriented native uppercase conversion, not Unicode case folding.
---@param s string Bounded source bytes.
---@return string text Independent uppercase string value.
function string.upper(s) end

---Reverse byte order, not Unicode grapheme order.
---@param s string Bounded source bytes.
---@return string text Bytes in reverse order.
function string.reverse(s) end

---Repeat a string with separators between copies. Nonpositive n returns an empty
---string; exact safe integer n required. Oversized output fails before allocation.
---@param s string Bounded source bytes.
---@param n integer Safe integer repetition count; nonpositive means empty.
---@param sep? string Omitted/nil means empty separator.
---@return string text Complete repetition, or empty when n is nonpositive.
function string.rep(s, n, sep) end

---Literal search ONLY: plain must be explicitly true. No Lua patterns/captures.
---A match returns first,last (inclusive); no match returns exactly one nil.
---Finite init is normalized; omitted/nil init means 1, negative counts from end.
---@param s string Bounded haystack bytes.
---@param needle string Literal bounded search bytes, including an empty string.
---@param init TC.Numeric|nil Third position; explicit nil selects default 1.
---@param plain true Required fourth position; any other value is refused.
---@return integer first One-based first matching byte when found.
---@return integer last Inclusive final matching byte; empty match may precede first.
---@overload fun(s: string, needle: string, init: TC.Numeric|nil, plain: true): absent: nil # No match returns exactly one nil (absent), not two nil values.
function string.find(s, needle, init, plain) end

---Bounded native formatting. Supports cdiouxXeEfgGqs and literal percent; checks
---width/precision/operand count and conservative output size before formatting.
---%s uses safe tostring, %q requires a string, numeric operands must be finite.
---No recursive table formatting or arbitrary format extension is provided.
---@param format string Bounded format string with supported conversions only.
---@param ... TC.GuestValue Conversion operands; each conversion validates its domain.
---@return string text Complete formatted bytes, never a successful truncated prefix.
function string.format(format, ...) end

---Guarded finite numeric helpers. Numeric strings convert explicitly through the
---helper; all supplied operands (including otherwise ignored extras) are checked.
---Nonfinite operands fail; a nonfinite native result is E_RANGE. No random,
---randomseed, huge or fallback to other host math functions is exposed.
---@class TC.MathLibrary
---@field pi number The host pi constant, read-only; not a random/configurable value.
math = {}

---Absolute value with finite-input/result validation.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Absolute value of x.
function math.abs(x, ...) end

---Round toward positive infinity.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Smallest integral value not below x.
function math.ceil(x, ...) end

---Round toward negative infinity.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Largest integral value not above x.
function math.floor(x, ...) end

---Smallest supplied finite value; at least one operand is required.
---@param x TC.Numeric First finite numeric operand.
---@param ... TC.Numeric Remaining finite operands within tuple width.
---@return number result Minimum converted numeric value.
function math.min(x, ...) end

---Largest supplied finite value; at least one operand is required.
---@param x TC.Numeric First finite numeric operand.
---@param ... TC.Numeric Remaining finite operands within tuple width.
---@return number result Maximum converted numeric value.
function math.max(x, ...) end

---Square root; a negative operand produces refused nonfinite native output.
---@param x TC.Numeric Finite nonnegative operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Nonnegative square root.
function math.sqrt(x, ...) end

---Native remainder using a quotient rounded toward zero; not floor modulo.
---@param x TC.Numeric Finite dividend.
---@param y TC.Numeric Finite nonzero divisor; nonfinite result is refused.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Remainder with the dividend's sign.
function math.fmod(x, y, ...) end

---Split a finite value into integral and fractional parts, preserving two results.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number integral Integral part rounded toward zero.
---@return number fractional Signed remaining fractional part.
function math.modf(x, ...) end

---Native sine of a finite angle in radians.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Sine value.
function math.sin(x, ...) end

---Native cosine of a finite angle in radians.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Cosine value.
function math.cos(x, ...) end

---Native tangent; nonfinite results are refused.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Finite tangent value.
function math.tan(x, ...) end

---Principal inverse sine; outside the native domain is a refused nonfinite result.
---@param x TC.Numeric Finite value in -1..1.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Principal angle in radians.
function math.asin(x, ...) end

---Principal inverse cosine; outside the native domain is refused.
---@param x TC.Numeric Finite value in -1..1.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Principal angle in radians.
function math.acos(x, ...) end

---Principal inverse tangent of one finite value.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Principal angle in radians.
function math.atan(x, ...) end

---Two-argument native inverse tangent, preserving y,x argument order.
---@param y TC.Numeric Finite vertical component.
---@param x TC.Numeric Finite horizontal component.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Quadrant-aware angle in radians.
function math.atan2(y, x, ...) end

---Convert radians to degrees, refusing nonfinite output.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Finite angle in degrees.
function math.deg(x, ...) end

---Convert degrees to radians, refusing nonfinite output.
---@param x TC.Numeric Finite angle in degrees.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number angle Finite angle in radians.
function math.rad(x, ...) end

---Natural exponential; overflow to a nonfinite value is E_RANGE.
---@param x TC.Numeric Finite exponent.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Finite natural exponential value.
function math.exp(x, ...) end

---Natural logarithm when base is omitted; explicit base selects that logarithm.
---Unlike omission, explicitly supplied nil is not a numeric operand and fails.
---Inputs must yield a finite native result; invalid domains are refused.
---@param x TC.Numeric Positive finite numeric operand.
---@param base? TC.Numeric Optional positive finite base other than one; explicit nil refused.
---@param ... TC.Numeric Extra operands are validated/charged, then ignored natively.
---@return number result Finite logarithm value.
function math.log(x, base, ...) end
