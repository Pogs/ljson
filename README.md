# jsua - a JSON encoder/decoder

## Usage

```lua

local jsua = require('jsua')

local lua =
	{
		a1 = { 1, 2, 3 },
		a2 = { true, false, jsua.null },
		d1 = { a = math.huge, b = math.huge * 0, c = -9.88485e-10, d = 9.38E+33 }
	}

local json = jsua.write(lua)
local lua2 = jsua.read(json)
```

### jsua.read(s):
s: (string) the json to be interpreted as lua

returns: (?) the lua object

note: error()'s on syntax issues, use with pcall()

```lua
> = jsua.read('[ 1, 2, 3 ]')
table: 0x170ca90
```

### jsua.write(v):
v: (?) the lua object to serialize as json

returns: (string) the json representation of v

note: error()'s on things like circular references and unknown types, use with pcall()

```lua
> = jsua.write({ 1, 2, 3 })
[1, 2, 3]
```
### jsua.new_array(t):
t: (table) this is optional, its metatable will be modified

returns: (table) the array-marked table

```lua
> = jsua.new_array({ 1, 2, 3 })
table: 0x170ca90
> = jsua.new_array()
table: 0x170cc00
```

### jsua.new_object(t):
t: (table) this is optional, its metatable will be modified for to-JSON object conversion

returns: (table) the object-marked table

```
> = jsua.new_object({ 1, 2, 3 })
table: 0x170ca90
> = jsua.new_object()
table: 0x170cc00
```

### jsua.is_array(v):
v: (?) the value to test for array status

returns: (boolean) true if table with no holes in sequence, false if empty table

```lua
> = jsua.is_array({ 1, 2, 3 })
true
> = jsua.is_array(jsua.new_array())
true
> = jsua.is_array({})
false
```

### jsua.is_null(v):
v: (?) the object to test for null status

returns: (boolean) true if v is null (nil or json.null)

```lua
> = json.is_null(nil) and json.is_null(json.null))
true
```

### jsua.is_object(v):
v: (?) the object to test for....object status

returns: (boolean) this function is literally the logical-not of `jsua.is_array()`

```lua
> = json.is_object({})
true
> = json.is_object({ cats = 'dogs' })
true
> = json.is_object({ 'a', 'b', 'c' })
false
```

### jsua.null:
This is a value you can assign within a table for later to-JSON conversion (it becomes 'null').

# Implementation Notes
`jsua.is_array()` will try to detect Lua tables that should become JSON arrays by asserting there are no string keys.  Also, if the number of total keys is greater than the number of numeric keys, this is interpreted as there being a "hole" in the sequence, which will make the table be interpreted as a object instead.

When encoding a table that has both a sequence portion and a has portion ({ 'a', 'b', 'c', cats = 'dogs' }) this will be interpreted as a JSON dict.  When the table is written out as a JSON string the numeric keys are converted to string keys, which as the potential for clobbering string keys that already existed and their associated values.  The result of which is not defined, as this is done with pairs() it can't be predicted if the numeric keys will supersede the existing string keys.

