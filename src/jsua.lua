local jsua = {}

jsua.null = {}

local numchars = '-0123456789.eE'

local escapes =
{
	['\\'] = '\\',
	['/']  = '/',
	['"']  = '"',
	b      = '\b',
	f      = '\f',
	n      = '\n',
	r      = '\r',
	t      = '\t'
}

local impl = {}

impl.array  = {} -- only used for
impl.object = {} -- identity matching

impl.is_whitespace_char = function (c) return string.find(' \n\r\t',  c, 1, true) ~= nil end
impl.is_number_char     = function (c) return string.find(numchars,   c, 1, true) ~= nil end

impl.read =
	function (peek, read)
		impl.skip_whitespace(peek, read)

		local value = impl.read_value(peek, read)

		impl.skip_whitespace(peek, read)

		assert(not peek())

		return value
	end

impl.read_value =
	function (peek, read)
		local char = peek()

		if     char == '"'               then return impl.read_string  (peek, read)
		elseif char == '{'               then return impl.read_object  (peek, read)
		elseif char == '['               then return impl.read_array   (peek, read)
		elseif char == 't'               then return impl.read_constant(peek, read, 'true',  true     )
		elseif char == 'f'               then return impl.read_constant(peek, read, 'false', false    )
		elseif char == 'n'               then return impl.read_constant(peek, read, 'null',  jsua.null)
		elseif impl.is_number_char(char) then return impl.read_number  (peek, read)
		else
			assert()
		end
	end

impl.skip_whitespace =
	function (peek, read)
		while true do
			local char = peek()

			if not char then
				break
			elseif char == '/' then
				impl.skip_comment(peek, read)
			elseif impl.is_whitespace_char(char) then
				read()
			else
				break
			end
		end
	end

impl.skip_comment =
	function (peek, read)
		local char = read()

		assert(char == '/')

		char = read()

		if char == '/' then
			read('[^\n]*')
			return
		elseif char == '*' then
			local star = false

			while true do
				char = assert(read())

				if char == '*' then
					star = true
				elseif star and char == '/' then
					return
				else
					star = false
				end
			end
		else
			assert()
		end
	end

local utf8_encode =
	function (cp)
		local n, mask = nil, nil

		if cp < 0x80 then
			return string.char(cp)
		elseif i < 0x800 then
			n, mask = 2, 0xC0
		else
			n, mask = 3, 0xE0
		end

		local bytes = {}

		while n > 1 do
			bytes[n] = string.char(0x80 + bit32.band(i, 0x3F))
			i = bit32.rshift(i, 6)
			n = n - 1
		end

		return table.concat(bytes)
	end

impl.read_string =
	function (peek, read)
		local buf = {}

		local char = read()

		assert(char == '"')

		while true do
			char = assert(read())

			if char == '"' then
				break
			elseif char == '\\' then
				char = read()

				if escapes[char] then
					table.insert(buf, escapes[char])
				elseif char == 'u' then
					char = assert(read('%x%x%x%x'))

					local tmp = tonumber(char, 16)

					table.insert(utf8_encode(tmp))
				else
					table.insert(buf, char)
				end
			else
				table.insert(buf, char)
			end
		end

		impl.skip_whitespace(peek, read)

		return table.concat(buf)
	end

impl.read_number =
	function (peek, read)
		local buf = {}

		while peek() and impl.is_number_char(peek()) do
			table.insert(buf, read())
		end

		impl.skip_whitespace(peek, read)

		return tonumber(table.concat(buf))
	end

impl.read_number =
	function (peek, read)
		local num = read('[' .. numchars .. ']+')

		impl.skip_whitespace(peek, read)

		return assert(tonumber(num))
	end

impl.read_object =
	function (peek, read)
		local obj  = jsua.new_object()
		local char = read()

		assert(char == '{')

		while true do
			impl.skip_whitespace(peek, read)

			char = assert(peek())

			if char == '}' then
				read()
				break
			end

			local key = impl.read_value(peek, read)

			impl.skip_whitespace(peek, read)

			local char = read()

			assert(char == ':')

			impl.skip_whitespace(peek, read)

			local value = impl.read_value(peek, read)

			obj[key] = value

			char = read()

			if char == '}' then
				break
			end

			assert(char == ',')
		end

		impl.skip_whitespace(peek, read)

		return obj
	end

impl.read_array =
	function (peek, read)
		local arr = jsua.new_array()

		local char = read()

		assert(char == '[')

		while true do
			impl.skip_whitespace(peek, read)

			char = assert(peek())

			if char == ']' then
				read()
				break
			end

			table.insert(arr, impl.read_value(peek, read))

			impl.skip_whitespace(peek, read)

			char = read()

			assert(char)

			if char == ']' then
				break
			end

			assert(char == ',')
		end

		impl.skip_whitespace(peek, read)

		return arr
	end

impl.read_constant =
	function (peek, read, name, value)
		assert(read(name))

		impl.skip_whitespace(peek, read)

		return value
	end

impl.write_value =
	function (value, write)
		local t = type(value)

		if     t == 'string'       then write(string.format('%q', value))
		elseif t == 'boolean'      then write(tostring(value))
		elseif t == 'number'       then impl.write_num(value, write)
		elseif jsua.is_null(value) then write('null')
		elseif t == 'table' then
			if jsua.is_array(value) then
				impl.write_array(value, write)
			else
				impl.write_object(value, write)
			end
		else
			assert()
		end
	end

impl.write_num =
	function (num, write)
		if math.abs(num) == math.huge or num ~= num then
			write('null')
			return
		end

		write(tostring(num))
	end

impl.write_array =
	function (arr, write)
		local len = #arr

		write('[')

		for i = 1, len - 1 do
			local value = arr[i]

			impl.write_value(value, write)
			write(', ')
		end

		impl.write_value(arr[len], write)

		write(']')
	end

local merge_numkeys =
	function (obj)
		local t = {}

		for k, v in pairs(obj) do
			obj[k] = nil
			t[tostring(k)] = v
		end

		for k, v in pairs(t) do
			obj[k] = v
		end

		return obj
	end

impl.write_object =
	function (obj, write)
		obj = merge_numkeys(obj)

		write('{')

		local keys = {}

		for key in pairs(obj) do
			table.insert(keys, key)
		end

		table.sort(keys)

		local len = #keys

		for i = 1, len - 1 do
			local key = keys[i]

			impl.write_value(key, write)
			write(': ')
			impl.write_value(obj[key], write)
			write(', ')
		end

		impl.write_value(keys[len], write)
		write(': ')
		impl.write_value(obj[keys[len]], write)

		write('}')
	end

jsua.new_array  = function (arr) return setmetatable(arr or {}, impl.array ) end
jsua.new_object = function (obj) return setmetatable(obj or {}, impl.object) end

jsua.is_array =
	function (value)
		local t  = type(value)
		local mt = getmetatable(value)

		if t ~= 'table' then
			return false
		end

		if value == jsua.null then
			return false
		end

		if mt and mt == impl.array then
			return true
		end

		local keys = 0

		for k in pairs(value) do
			keys = keys + 1

			if type(k) ~= 'number' then
				return false
			end
		end

		if keys == 0 then
			return false
		end

		local sequential = 0

		for i in ipairs(value) do
			sequential = sequential + 1
		end

		if sequential < keys then
			return false
		end

		return true
	end

jsua.is_object =
	function (value)
		return not jsua.is_array(value)
	end

jsua.is_null =
	function (obj)
		return obj == nil or obj == jsua.null
	end

jsua.read =
	function (str)
		local pos  = 1
		local len  = #str

		local peek =
			function (what)
				what = what or 1

				if pos > len then
					return
				end

				if type(what) == 'string' then
					return string.match(str, what, pos) or nil
				end

				return string.sub(str, pos, pos + (what - 1))
			end

		local read =
			function (what)
				local s = peek(what)

				pos = pos  + #s

				return s
			end

		local ok, result = pcall(impl.read, peek, read)

		if not ok then
			local tmp  = string.sub(str, 1, pos)
			local at   = #(string.match(tmp, '[^\n]*$'))
			local line = select(2, string.gsub(tmp, '\n', '%0')) + 1

			error(string.format('syntax error: line %d, column %d', line, at))
		end

		return result
	end

local is_circular =
	function (val)
		local seen = {}

		local descend = nil
		descend =
			function (t)
				seen[t] = true

				for _, v in pairs(t) do
					if type(v) == 'table' then
						if seen[v] then
							error()
						end

						descend(v)
					end
				end
			end

		return not pcall(descend, val)
	end

jsua.write =
	function (val)
		if type(val) == 'table' and is_circular(val) then
			assert(false, 'object has circular references')
		end

		local buf = {}

		impl.write_value(val, function (s) table.insert(buf, s) end)

		return table.concat(buf)
	end

return jsua
