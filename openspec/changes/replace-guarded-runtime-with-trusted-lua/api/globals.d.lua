---@meta

---This type is a transient guest-owned plain table or detached snapshot.
---Helpers reject protected namespaces, protected facades and foreign tables.
---Transient reference keys, aliases and cycles are possible.
---Ordinary Data and Console retention have stricter rules.
---@alias TC.GuestTable table<TC.GuestValue, TC.GuestValue>

---Native numeric helpers accept numbers and convertible numeric strings.
---Temporary numeric results can be nonfinite. Data and device domains remain stricter.
---This helper compatibility does not add coercion to computer or peripheral APIs.
---@alias TC.Numeric number|string

---Native string helpers accept strings and numbers where native coercion applies.
---This type does not widen string-only device or persistence arguments.
---@alias TC.StringInput string|number

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

---Return the Lua type name. Supply a value, including explicit nil.
---Omission causes a native argument error.
---This helper does not grant native object access.
---Temporary arguments and results have no mod tuple or work ceiling.
---Each native helper determines how it handles extra arguments, rather than service arity.
---@param value TC.GuestValue Required value. Explicit nil has type nil.
---@return 'nil'|'boolean'|'number'|'string'|'table'|'function' name Guest-visible primitive kind.
function type(value) end

---This helper uses stable safe formatting.
---Tables become table, protected handles become API handle, and guest functions
---become guest function. Approved callables become their stable label.
---The helper never uses addresses, recursive inspection or metatable calls.
---Omission formats nil.
---@param value? TC.GuestValue Approved value to describe without exposing internals.
---@return string text Safe description or primitive representation. Output APIs apply their own byte limits.
function tostring(value) end

---Convert a number or numeric string with native conversion.
---Supply a value; omission causes a native argument error.
---An ordinary invalid value returns exactly one nil.
---An explicit base requires a string and an integer base in 2..36.
---An invalid base or type causes a catchable argument failure.
---An omitted or nil base uses ordinary numeric conversion.
---Conversion does not widen API numeric domains.
---@param value TC.GuestValue Number/string to convert. Other ordinary values return nil.
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
---Status does not create a mod tuple ceiling.
---Fatal host-work refusal and stop always escape without becoming guest error values.
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
---Handler re-entry follows native Lua limits, not a mod depth ceiling.
---The wording of an error inside the handler is not stable.
---A fatal failure in fn suppresses the handler.
---A fatal failure in handler suppresses later handlers and effects.
---Neither can suppress private host-work or stop controls.
---Pure Lua execution inside either function has no watchdog.
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
---Saved print and computer.log use the same bounded buffer. Console retains shell attribution.
---Output uses the admitted execution owner, not repeated physical discovery for each entry.
---Both byte and entry bounds apply. Canceled executions cannot append guest output.
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
---It rejects protected or foreign tables and applies native key rules.
---All three positions are required. Temporary growth has no mod quota.
---A nil value deletes the key. Nil and NaN keys are invalid.
---
---Insertion, replacement, and deletion use native table behavior.
---An invalid key does not change the table.
---@param t TC.GuestTable Mutable guest-owned plain table.
---@param key TC.GuestValue Valid nonnil, non-NaN guest key, including transient references.
---@param value TC.GuestValue Required value position. Nil deletes the key.
---@return TC.GuestTable table Identical input table, not a defensive copy.
function rawset(t, key, value) end

---This helper requires one argument.
---It returns byte length for strings or the native border for guest tables,
---not map cardinality. It refuses protected API tables and foreign values.
---@param value string|TC.GuestTable Byte string or guest-owned plain table.
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
---Negative indexes count from the end. Native index limits apply.
---No mod tuple ceiling applies.
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
---@return TC.Iterator iterator Approved native sequence iterator.
---@return TC.GuestTable state Identical table.
---@return integer initial Always zero. This is an explicit third result.
function ipairs(t) end

---These helpers reject protected facades, protected namespaces, and foreign tables.
---Native sequence borders determine ranges, including for sparse tables.
---Temporary movement, growth, and comparisons have no mod work or allocation quota.
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
---Native index and stack limits apply, without a mod tuple ceiling.
---@param t TC.GuestTable Guest-owned plain table. This table can be sparse.
---@param i? integer Start, default 1. Native integer-index limits apply.
---@param j? integer End, default native #t. Native integer-index limits apply.
---@return TC.GuestValue ... Exact requested range, possibly empty and nil-bearing.
function table.unpack(t, i, j) end

---This is the identical function to table.unpack, with the same stable table function label.
unpack = table.unpack

---Join a native sequence slice. Its selected elements must be strings or numbers.
---Numbers use native conversion. Temporary output has no mod byte or work ceiling.
---@param t TC.GuestTable Plain table with strings/numbers at each selected index.
---@param sep? string Separator. Omission or nil means an empty string.
---@param i? integer First position, default 1. Native integer-index limits apply.
---@param j? integer Last position, default native #t. Native integer-index limits apply.
---@return string text Joined bytes. An empty range gives an empty string.
function table.concat(t, sep, i, j) end

---Insert into a native guest sequence. The helper moves later slots.
---It returns no values. The two-argument form appends.
---The three-argument form inserts at pos.
---
---Native index and argument rules apply. There is no mod temporary-growth quota.
---@param t TC.GuestTable Mutable plain table using native sequence borders.
---@param pos integer Position 1..n+1 for the three-argument form.
---@param value TC.GuestValue New value. Nil uses native table insertion behavior.
---@overload fun(t: TC.GuestTable, value: TC.GuestValue)
function table.insert(t, pos, value) end

---Remove a value with native table.remove behavior. The helper shifts later slots.
---A present sequence position returns exactly one removed value.
---The pinned engine returns zero values for empty or out-of-range removal.
---It does not add a nil result to preserve the former wrapper behavior.
---@param t TC.GuestTable Mutable plain table using native sequence borders.
---@param pos? integer Default native #t. Native position and conversion rules apply.
---@return TC.GuestValue ... Exactly one removed value, or zero results for empty/out-of-range removal.
function table.remove(t, pos) end

---Sort the table in place with native table.sort. The helper returns no values.
---Comparator calls have no mod execution or depth quota.
---A comparator can have effects. Failure does not roll back effects or table reordering.
---This rule does not change atomic publication through state or device APIs.
---@param t TC.GuestTable Mutable plain table using native sequence borders.
---@param less? fun(a: TC.GuestValue, b: TC.GuestValue): boolean Optional approved comparator. The default is native less-than.
function table.sort(t, less) end

---These approved helpers operate on immutable byte strings, not Unicode.
---Temporary inputs and outputs have no mod byte, allocation, or work ceiling.
---Native errors and coercions apply except for documented safe-format and literal-find rules.
---String indexing exposes only this approved surface, never hidden host string members.
---Use dot calls: string.sub(s,...) instead of the forbidden string-method syntax.
---@class TC.StringLibrary
string = {}

---Read byte length, not Unicode character count.
---@param s TC.StringInput Source byte string or native-coercible number.
---@return integer length Byte count including embedded NUL.
function string.len(s) end

---Slice bytes with native indexes. Negative indexes count from the end.
---The start position is required. Omitted or nil j defaults to string length.
---@param s TC.StringInput Source bytes or native-coercible number.
---@param i TC.Numeric Required first byte index under native conversion rules.
---@param j? TC.Numeric Last byte index, default length.
---@return string text Native slice result without a mod temporary-byte ceiling.
function string.sub(s, i, j) end

---Return each byte in the normalized range.
---Omitted or nil i defaults to 1. The default for j is i (or 1), not string length.
---An empty range returns zero values. Native result-stack limits apply.
---Embedded NUL returns numeric zero.
---@param s TC.StringInput Source bytes or native-coercible number.
---@param i? TC.Numeric First native byte index, default 1.
---@param j? TC.Numeric Last native byte index, default i or 1.
---@return integer ... Byte codes 0..255 in order, possibly zero results.
function string.byte(s, i, j) end

---Construct bytes with native integer conversion. Zero inputs return an empty string.
---@param ... TC.Numeric Byte codes 0..255 after native conversion, subject to native argument limits.
---@return string text Constructed byte string including any NUL values.
function string.char(...) end

---Return byte-oriented native lowercase conversion, not Unicode case folding.
---@param s TC.StringInput Source bytes or native-coercible number.
---@return string text Independent lowercase string value.
function string.lower(s) end

---Return byte-oriented native uppercase conversion, not Unicode case folding.
---@param s TC.StringInput Source bytes or native-coercible number.
---@return string text Independent uppercase string value.
function string.upper(s) end

---Reverse byte order, not Unicode grapheme order.
---@param s TC.StringInput Source bytes or native-coercible number.
---@return string text Bytes in reverse order.
function string.reverse(s) end

---Repeat a string with separators between copies.
---Nonpositive n returns an empty string. Native count conversion and limits apply.
---There is no mod output-size preflight or temporary-allocation quota.
---@param s TC.StringInput Source bytes or native-coercible number.
---@param n integer Native repetition count. A nonpositive value means empty.
---@param sep? TC.StringInput Omitted/nil means empty separator. Native number conversion is permitted.
---@return string text Complete repetition, or empty when n is nonpositive.
function string.rep(s, n, sep) end

---This helper searches only for literal text. The plain argument must be explicitly true.
---The helper supports no Lua patterns or captures.
---A match returns first,last (inclusive). No match returns exactly one nil.
---
---The helper uses native index conversion. Omitted or nil init means 1.
---A negative init counts from the end.
---@param s TC.StringInput Haystack bytes or a native-coercible number.
---@param needle TC.StringInput Literal search bytes or a native-coercible number. Empty strings are permitted.
---@param init TC.Numeric|nil Third position. Explicit nil selects the default 1.
---@param plain true Required fourth position. The helper refuses any other value.
---@return integer first One-based first matching byte when found.
---@return integer last Inclusive final matching byte. An empty match can precede first.
---@overload fun(s: TC.StringInput, needle: TC.StringInput, init: TC.Numeric|nil, plain: true): absent: nil # No match returns exactly one nil (absent), not two nil values.
function string.find(s, needle, init, plain) end

---This helper does native formatting with safe descriptions for %s.
---It supports cdiouxXeEfgGqs and literal percent.
---Native format, width, precision, and operand rules apply without mod output-size admission.
---
---The %s conversion uses safe tostring. The %q conversion requires a string.
---Native numeric domains apply. Temporary nonfinite values are not persistent Data.
---The helper provides no recursive table formatting or arbitrary format extension.
---@param format string Format string with supported conversions only.
---@param ... TC.GuestValue Conversion operands. Each conversion validates its domain.
---@return string text Complete formatted bytes, never a successful truncated prefix.
function string.format(format, ...) end

---These approved math helpers use native conversion, domains, results, and errors.
---Temporary results can be nonfinite. Persistent Data and device arguments still require their documented domains.
---There is no mod work, allocation, tuple, or call-depth quota.
---The library exposes no random, randomseed, huge, or fallback to other host functions.
---@class TC.MathLibrary
---@field pi number Read-only native pi constant.
math = {}

---Return the native absolute value.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Absolute value, including native nonfinite behavior.
function math.abs(x, ...) end

---Round toward positive infinity.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Smallest integral value not below x, under native rules.
function math.ceil(x, ...) end

---Round toward negative infinity.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Largest integral value not above x, under native rules.
function math.floor(x, ...) end

---Return the smallest supplied value. At least one operand is required.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.Numeric Remaining operands used by the native comparison.
---@return number result Native minimum of the converted operands.
function math.min(x, ...) end

---Return the largest supplied value. At least one operand is required.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.Numeric Remaining operands used by the native comparison.
---@return number result Native maximum of the converted operands.
function math.max(x, ...) end

---Return the native square root. Native nonfinite results remain temporary values.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native square-root result.
function math.sqrt(x, ...) end

---Return the native remainder with a quotient rounded toward zero, not floor modulo.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param y TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native remainder, including native nonfinite behavior.
function math.fmod(x, y, ...) end

---Split a value into native integral and fractional parts.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number integral Integral part rounded toward zero.
---@return number fractional Native signed fractional part. This is an explicit second result.
function math.modf(x, ...) end

---Return the native sine of an angle in radians.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native sine result.
function math.sin(x, ...) end

---Return the native cosine of an angle in radians.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native cosine result.
function math.cos(x, ...) end

---Return the native tangent of an angle in radians.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native tangent result.
function math.tan(x, ...) end

---Return the native principal inverse sine.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native principal angle in radians.
function math.asin(x, ...) end

---Return the native principal inverse cosine.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native principal angle in radians.
function math.acos(x, ...) end

---Return the native inverse tangent of one value.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native principal angle in radians.
function math.atan(x, ...) end

---Return the two-argument inverse tangent, preserving y,x argument order.
---@param y TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native quadrant-aware angle in radians.
function math.atan2(y, x, ...) end

---Convert radians to degrees under native rules.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native angle in degrees.
function math.deg(x, ...) end

---Convert degrees to radians under native rules.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number angle Native angle in radians.
function math.rad(x, ...) end

---Return the native natural exponential. Overflow is not a synthetic E_RANGE error.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native exponential result, which can be nonfinite.
function math.exp(x, ...) end

---Return the native logarithm. Omitted or nil base selects the natural logarithm.
---@param x TC.Numeric Native numeric operand; device finite-value rules do not apply here.
---@param base? TC.Numeric Optional base. Omission or nil selects the natural logarithm.
---@param ... TC.GuestValue Extra arguments ignored by the native helper.
---@return number result Native logarithm result, which can be nonfinite.
function math.log(x, base, ...) end
