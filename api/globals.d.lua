---@meta

---This type is a transient guest-owned plain table or detached snapshot.
---Helpers reject protected namespaces, protected facades and foreign tables.
---Transient reference keys, aliases and cycles are possible.
---Ordinary Data and Console retention have stricter rules.
---@alias TC.GuestTable table<TC.GuestValue, TC.GuestValue>

---Only guarded numeric helpers accept this number or numeric string type.
---Strings must convert to numbers.
---Operands and results must be finite where stated.
---This helper compatibility does not add coercion to computer or peripheral APIs.
---@alias TC.Numeric number|string

---This packed transient argument tuple is not a dense Data array when it contains nil.
---@class TC.Tuple
---@field n integer Exact number of positions, including trailing nil.
---@field [integer] TC.GuestValue One-based nonnil value at that position. Holes represent nil.

---This type defines the iterator callback shape.
---For a present entry, the iterator returns key,value.
---At termination, it returns exactly one nil, not zero results.
---This function value cannot persist.
---@alias TC.Iterator fun(t: TC.GuestTable, previous: TC.GuestValue): ...: TC.GuestValue

---This fixed label identifies the guest language family, not unrestricted Lua 5.2 compatibility.
_VERSION = 'Lua 5.2'

---Return the Lua type name. Omission has the same effect as nil.
---This helper does not grant native object access.
---Standard helpers still obey argument/result tuple and work bounds.
---Each native helper determines how it handles extra arguments, rather than service arity.
---@param value? TC.GuestValue Value to inspect. Omission or nil has type nil.
---@return 'nil'|'boolean'|'number'|'string'|'table'|'function' name Guest-visible primitive kind.
function type(value) end

---This helper uses stable safe formatting.
---Tables become table, protected handles become API handle, and guest functions
---become guest function. Approved callables become their stable label.
---The helper never uses addresses, recursive inspection or metatable calls.
---Omission formats nil.
---@param value? TC.GuestValue Approved value to describe without exposing internals.
---@return string text Bounded safe description or primitive representation.
function tostring(value) end

---Convert a number or bounded numeric string.
---An ordinary invalid value returns exactly one nil.
---An explicit base requires a string and an integer base in 2..36.
---An invalid base or type causes a catchable argument failure.
---An omitted or nil base uses ordinary numeric conversion.
---Conversion does not widen API numeric domains.
---@param value? TC.GuestValue Number/string to convert. Other ordinary values return nil.
---@param base? integer Optional integer radix 2..36. Nil uses normal conversion.
---@return number|nil number Converted number, or exactly one nil on invalid text/value.
function tonumber(value, base) end

---For a truthy value, this helper returns value followed by the exact supplied
---trailing tuple, including nil holes. For false or nil, it raises the first
---trailing value or the native assertion message.
---This is ordinary failure, not a transaction rollback.
---@param value TC.GuestValue Predicate. Only false and nil fail.
---@param ... TC.GuestValue Trailing results. The helper uses the first value as the failure message when that value is truthy.
---@return TC.GuestValue value Identical successful predicate value.
---@return TC.GuestValue ... Identical trailing positions, possibly zero.
function assert(value, ...) end

---This helper does not return normally. It raises an ordinary guest error,
---including explicit nil or a guest value. It exposes no source-level argument.
---Protected calls can catch the error.
---Earlier state, output and peripheral effects remain committed.
---@param value? TC.GuestValue Error value. Omission has the same effect as nil.
function error(value) end

---Call an approved function with exactly the trailing tuple.
---Success returns true followed by every original result.
---Ordinary failure returns false and exactly one safe error.
---Guest-owned table errors preserve identity.
---The helper makes defensive copies of unowned error records.
---
---Unlike xpcall, pcall cannot return a protected API handle as an error.
---If the function throws such a handle, pcall's own error-snapshot step refuses with E_ARGUMENT.
---Status counts toward tuple width.
---Fatal budget/stop control always escapes and never becomes a guest error value.
---@param fn TC.Callable Approved function, not an arbitrary native callable.
---@param ... TC.GuestValue Exact forwarded arguments, preserving nil and aliases.
---@return boolean ok True on normal completion. False on ordinary failure.
---@return TC.GuestValue ... Success results (possibly zero) or exactly one safe failure value.
function pcall(fn, ...) end

---This protected call uses an approved message handler.
---It forwards exact trailing arguments. Success returns true plus exact results.
---Ordinary failure calls handler with one safe error.
---It returns false followed by only the handler's first result.
---If the handler returns no values, the second result is one nil.
---
---Native handler re-entry is bounded.
---The wording of an error inside the handler is not stable.
---A fatal failure in fn suppresses the handler.
---A fatal failure in handler suppresses later handlers and effects.
---Neither can suppress quota controls.
---
---Guest-owned tables and authentic protected-handle errors preserve identity.
---The helper copies unowned host error records.
---This differs from pcall's handle refusal.
---@param fn TC.Callable Function to call under ordinary-error protection.
---@param handler TC.Callable Error transformer receiving one safe failure value.
---@param ... TC.GuestValue Exact arguments forwarded only to fn.
---@return boolean ok True on completion. False after ordinary failure handling.
---@return TC.GuestValue ... Exact success tuple or exactly one transformed failure value.
function xpcall(fn, handler, ...) end

---Append one Console entry with safe tostring values joined by tabs, without an added newline.
---Zero arguments append an empty entry. This helper returns no values.
---Complete formatting and admission occur before append or eviction.
---Oversized output causes E_LIMIT with no partial entry.
---Earlier output survives later failures.
---
---Saved output uses computer.log. Console retains shell attribution.
---The native display shows tabs as spaces without changing raw retained/copyable bytes.
---@param ... TC.GuestValue Ordered values to format. Nil and false remain in the output.
function print(...) end

---This helper does a raw lookup in a guest-owned table.
---Both arguments are required. An explicit nil or NaN key returns one nil.
---The helper returns the identical stored value without copying or metamethods.
---It refuses protected namespaces, protected facades and foreign tables.
---@param t TC.GuestTable Guest-owned plain table, not a protected API handle.
---@param key TC.GuestValue Required key position. Explicit nil or NaN means absent.
---@return TC.GuestValue value Exactly one stored value or nil. Aliases remain unchanged.
function rawget(t, key) end

---This helper does a raw guest-table assignment.
---Before mutation, it applies ordinary indexed-write ownership, key, value, growth,
---work and allocation checks. All three positions are required.
---A nil value deletes the key. Nil and NaN keys are invalid.
---
---The helper permits replacement or deletion at full width when admission succeeds.
---Refused writes leave every alias unchanged.
---@param t TC.GuestTable Mutable guest-owned plain table.
---@param key TC.GuestValue Valid nonnil, non-NaN guest key, including transient references.
---@param value TC.GuestValue Required value position. Nil deletes the key.
---@return TC.GuestTable table Identical input table, not a defensive copy.
function rawset(t, key, value) end

---This helper requires one argument.
---It returns byte length for strings or the native border for guest tables,
---not map cardinality. It refuses protected API tables and foreign values.
---@param value string|TC.GuestTable Bounded byte string or guest-owned plain table.
---@return integer length Nonnegative byte length or native sequence border.
function rawlen(value) end

---This helper requires both positions, including explicit nil.
---It compares approved guest values with raw identity/equality, without copies or metamethods.
---It can compare authentic facades and functions without exposing their protected fields.
---@param a TC.GuestValue First approved value.
---@param b TC.GuestValue Second approved value.
---@return boolean equal Whether native raw equality holds.
function rawequal(a, b) end

---Return the trailing tuple width for '#', or its suffix at a nonzero integer index.
---A positive index beyond the end returns zero values.
---Negative indexes count from the end. Index and tuple bounds apply.
---Zero and too-negative indexes cause failure.
---The helper never collapses nil positions.
---@param index integer|'#' Required selector. An integer must be within the tuple domain.
---@param ... TC.GuestValue Ordered input tuple, possibly empty.
---@return TC.GuestValue ... Suffix positions or one integer width for '#'.
---@overload fun(index: '#', ...: TC.GuestValue): count: integer # The index '#' selects count, the exact number of trailing positions, including nil. This overload returns one integer.
function select(index, ...) end

---Advance native guest-table iteration. The helper does not guarantee order.
---The first call uses an omitted or nil key.
---A present entry returns key,value. Completion returns exactly one nil.
---An invalid previous key or access to a protected or foreign table causes ordinary failure.
---@param t TC.GuestTable Guest-owned table/snapshot to iterate.
---@param key? TC.GuestValue Previously returned key. Omission or nil starts iteration.
---@return TC.GuestValue key Next nonnil key on a present entry.
---@return TC.GuestValue value Identical value at that entry.
---@overload fun(t: TC.GuestTable, key?: TC.GuestValue): absent: nil # Iteration completion returns exactly one nil (absent), with no value position.
function next(t, key) end

---Return exactly iterator,table,nil for generic iteration.
---Values retain identity. This helper grants no access to protected or private host tables.
---It does not guarantee sorting.
---@param t TC.GuestTable Guest-owned table/snapshot.
---@return TC.Iterator iterator The same approved next helper.
---@return TC.GuestTable state Identical table.
---@return nil initial Explicit initial control value. This position is present.
function pairs(t) end

---Return exactly iterator,table,0.
---The iterator advances integer indexes from one until the first absent slot.
---False is present. The iterator returns index,value for a present slot.
---At termination, it returns exactly one nil.
---Native Logic arrays retain their domain.
---@param t TC.GuestTable Guest-owned table/snapshot.
---@return TC.Iterator iterator Approved bounded sequence iterator.
---@return TC.GuestTable state Identical table.
---@return integer initial Always zero. This is an explicit third result.
function ipairs(t) end

---These guarded table helpers never mutate protected facades, protected namespaces or host tables.
---Sequence helpers require a dense one-based sequence unless stated otherwise.
---All movement, copying, growth and callback comparisons consume existing budgets.
---@class TC.TableLibrary
table = {}

---Pack exact argument arity in n, including trailing nil.
---The result is a fresh guest-owned table.
---Nil positions are holes, not valid persistent Data elements.
---@param ... TC.GuestValue Original ordered argument tuple.
---@return TC.Tuple values New tuple table with exact n.
function table.pack(...) end

---Return positions i..j exactly, including nil holes.
---Omitted or nil bounds default to 1 and #t, not t.n.
---Use explicit packed.n to retain trailing nil.
---An empty range returns zero values.
---Current guest table index and tuple ceilings apply.
---@param t TC.GuestTable Guest-owned plain table. This table can be sparse.
---@param i? integer Start, default 1. The domain is 1..table_entries+1.
---@param j? integer End, default native #t. The domain is 0..table_entries.
---@return TC.GuestValue ... Exact requested range, possibly empty and nil-bearing.
function table.unpack(t, i, j) end

---This is the identical function to table.unpack, with the same stable table function label.
unpack = table.unpack

---Join a dense sequence slice. Only string and number elements are permitted.
---Numbers use native conversion. Complete size and work admission precede the output copy.
---@param t TC.GuestTable Dense sequence containing strings/numbers in the slice.
---@param sep? string Separator. Omission or nil means an empty string.
---@param i? integer First position, default 1. The domain is 1..n+1.
---@param j? integer Last position, default n. The domain is 0..n.
---@return string text Joined bytes. An empty range gives an empty string.
function table.concat(t, sep, i, j) end

---Insert into a dense guest sequence. The helper moves later slots.
---It returns no values. The two-argument form appends.
---The three-argument form inserts at pos.
---
---Capacity and work admission precede mutation.
---Refusal does not produce a partially shifted result.
---@param t TC.GuestTable Dense mutable sequence.
---@param pos integer Position 1..n+1 for the three-argument form.
---@param value TC.GuestValue New value. Nil uses native table insertion behavior.
---@overload fun(t: TC.GuestTable, value: TC.GuestValue)
function table.insert(t, pos, value) end

---Remove a value from a dense guest sequence. The helper shifts later slots.
---It always returns exactly one value, including nil for empty/past-end removal.
---Position 0 is permitted only when the sequence is empty.
---The helper accepts n+1. This is the documented guest arity, not an inference
---from the host helper.
---@param t TC.GuestTable Dense mutable sequence.
---@param pos? integer Default n. The permitted range is 0..n+1, with the empty-only zero rule.
---@return TC.GuestValue removed Removed identical value or exactly one nil.
function table.remove(t, pos) end

---This helper sorts a staged copy.
---It publishes the copy only after comparisons and final capacity revalidation succeed.
---It returns no values.
---
---A comparator uses the same guest work and depth budget.
---The comparator can have side effects. Failure does not roll back those effects.
---The helper never partially publishes the table's own staged sorted slots.
---@param t TC.GuestTable Dense mutable sequence.
---@param less? fun(a: TC.GuestValue, b: TC.GuestValue): boolean Optional approved comparator. The default is guarded native less-than.
function table.sort(t, less) end

---These bounded helpers operate on byte strings, not Unicode or Lua patterns.
---Strings are immutable. Input, output and work checks precede opaque native operations.
---Use dot calls: string.sub(s,...) instead of the forbidden string-method syntax.
---@class TC.StringLibrary
string = {}

---Read byte length, not Unicode character count.
---@param s string Bounded byte string.
---@return integer length Byte count including embedded NUL.
function string.len(s) end

---Slice bytes with normalized Lua-style indexes.
---Negative indexes count from the end. Finite numeric strings are permitted.
---Omission or nil defaults to i=1,j=#s.
---@param s string Bounded source string.
---@param i? TC.Numeric First byte index, default 1.
---@param j? TC.Numeric Last byte index, default length.
---@return string text Native slice result after bounded admission.
function string.sub(s, i, j) end

---Return each byte in the normalized range.
---Omitted or nil i defaults to 1. The default for j is i (or 1), not string length.
---An empty range returns zero values. The result width cannot exceed tuple_entries.
---Embedded NUL returns numeric zero.
---@param s string Bounded source bytes.
---@param i? TC.Numeric First finite byte index, default 1.
---@param j? TC.Numeric Last finite byte index, default i or 1.
---@return integer ... Byte codes 0..255 in order, possibly zero results.
function string.byte(s, i, j) end

---Construct bytes from exact integer codes. Zero inputs return an empty string.
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

---Repeat a string with separators between copies.
---Nonpositive n returns an empty string. The value n must be an exact safe integer.
---Oversized output causes failure before allocation.
---@param s string Bounded source bytes.
---@param n integer Safe integer repetition count. A nonpositive value means empty.
---@param sep? string Omitted/nil means empty separator.
---@return string text Complete repetition, or empty when n is nonpositive.
function string.rep(s, n, sep) end

---This helper searches only for literal text. The plain argument must be explicitly true.
---The helper supports no Lua patterns or captures.
---A match returns first,last (inclusive). No match returns exactly one nil.
---
---The helper normalizes finite init. Omitted or nil init means 1.
---A negative init counts from the end.
---@param s string Bounded haystack bytes.
---@param needle string Literal bounded search bytes, including an empty string.
---@param init TC.Numeric|nil Third position. Explicit nil selects the default 1.
---@param plain true Required fourth position. The helper refuses any other value.
---@return integer first One-based first matching byte when found.
---@return integer last Inclusive final matching byte. An empty match can precede first.
---@overload fun(s: string, needle: string, init: TC.Numeric|nil, plain: true): absent: nil # No match returns exactly one nil (absent), not two nil values.
function string.find(s, needle, init, plain) end

---This helper does bounded native formatting.
---It supports cdiouxXeEfgGqs and literal percent.
---Before formatting, it checks width, precision, operand count and conservative output size.
---
---The %s conversion uses safe tostring. The %q conversion requires a string.
---Numeric operands must be finite.
---The helper provides no recursive table formatting or arbitrary format extension.
---@param format string Bounded format string with supported conversions only.
---@param ... TC.GuestValue Conversion operands. Each conversion validates its domain.
---@return string text Complete formatted bytes, never a successful truncated prefix.
function string.format(format, ...) end

---These guarded numeric helpers require finite values.
---The helper explicitly converts numeric strings.
---It checks all supplied operands, including extra operands that it otherwise ignores.
---Nonfinite operands cause failure. A nonfinite native result causes E_RANGE.
---The library exposes no random, randomseed, huge or fallback to other host math functions.
---@class TC.MathLibrary
---@field pi number The read-only host pi constant, not a random or configurable value.
math = {}

---This helper returns the absolute value and validates finite input and result.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Absolute value of x.
function math.abs(x, ...) end

---Round toward positive infinity.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Smallest integral value not below x.
function math.ceil(x, ...) end

---Round toward negative infinity.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Largest integral value not above x.
function math.floor(x, ...) end

---This helper returns the smallest supplied finite value.
---It requires at least one operand.
---@param x TC.Numeric First finite numeric operand.
---@param ... TC.Numeric Remaining finite operands within tuple width.
---@return number result Minimum converted numeric value.
function math.min(x, ...) end

---This helper returns the largest supplied finite value.
---It requires at least one operand.
---@param x TC.Numeric First finite numeric operand.
---@param ... TC.Numeric Remaining finite operands within tuple width.
---@return number result Maximum converted numeric value.
function math.max(x, ...) end

---This helper returns the square root.
---A negative operand produces nonfinite native output, which the helper refuses.
---@param x TC.Numeric Finite nonnegative operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Nonnegative square root.
function math.sqrt(x, ...) end

---This helper returns the native remainder with a quotient rounded toward zero,
---not floor modulo.
---@param x TC.Numeric Finite dividend.
---@param y TC.Numeric Finite nonzero divisor. The helper refuses a nonfinite result.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Remainder with the dividend's sign.
function math.fmod(x, y, ...) end

---Split a finite value into integral and fractional parts, preserving two results.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number integral Integral part rounded toward zero.
---@return number fractional Signed remaining fractional part.
function math.modf(x, ...) end

---This helper returns the native sine of a finite angle in radians.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Sine value.
function math.sin(x, ...) end

---This helper returns the native cosine of a finite angle in radians.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Cosine value.
function math.cos(x, ...) end

---This helper returns the native tangent. It refuses nonfinite results.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Finite tangent value.
function math.tan(x, ...) end

---This helper returns the principal inverse sine.
---An operand outside the native domain produces a nonfinite result, which the helper refuses.
---@param x TC.Numeric Finite value in -1..1.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Principal angle in radians.
function math.asin(x, ...) end

---This helper returns the principal inverse cosine.
---It refuses operands outside the native domain.
---@param x TC.Numeric Finite value in -1..1.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Principal angle in radians.
function math.acos(x, ...) end

---This helper returns the principal inverse tangent of one finite value.
---@param x TC.Numeric Finite numeric operand.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Principal angle in radians.
function math.atan(x, ...) end

---This helper returns the two-argument native inverse tangent and preserves y,x argument order.
---@param y TC.Numeric Finite vertical component.
---@param x TC.Numeric Finite horizontal component.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Quadrant-aware angle in radians.
function math.atan2(y, x, ...) end

---Convert radians to degrees. The helper refuses nonfinite output.
---@param x TC.Numeric Finite angle in radians.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Finite angle in degrees.
function math.deg(x, ...) end

---Convert degrees to radians. The helper refuses nonfinite output.
---@param x TC.Numeric Finite angle in degrees.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number angle Finite angle in radians.
function math.rad(x, ...) end

---This helper returns the natural exponential.
---Overflow to a nonfinite value causes E_RANGE.
---@param x TC.Numeric Finite exponent.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Finite natural exponential value.
function math.exp(x, ...) end

---This helper returns the natural logarithm when base is omitted.
---An explicit base selects that logarithm.
---Unlike omission, explicitly supplied nil is not a numeric operand and causes failure.
---Inputs must give a finite native result. The helper refuses invalid domains.
---@param x TC.Numeric Positive finite numeric operand.
---@param base? TC.Numeric Optional positive finite base other than one. The helper refuses explicit nil.
---@param ... TC.Numeric The helper validates and charges extra operands. The native function then ignores them.
---@return number result Finite logarithm value.
function math.log(x, base, ...) end
