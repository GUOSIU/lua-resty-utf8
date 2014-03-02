-- ABNF from RFC 3629
--
-- UTF8-octets = *( UTF8-char )
-- UTF8-char = UTF8-1 / UTF8-2 / UTF8-3 / UTF8-4
-- UTF8-1 = %x00-7F
-- UTF8-2 = %xC2-DF UTF8-tail
-- UTF8-3 = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
-- %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
-- UTF8-4 = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
-- %xF4 %x80-8F 2( UTF8-tail )
-- UTF8-tail = %x80-BF

-- 0xxxxxxx                            | 007F   (127)
-- 110xxxxx	10xxxxxx                   | 07FF   (2047)
-- 1110xxxx	10xxxxxx 10xxxxxx          | FFFF   (65535)
-- 11110xxx	10xxxxxx 10xxxxxx 10xxxxxx | 10FFFF (1114111)

local maxitems = 256
local utf8char = '[%z\1-\127\194-\244][\128-\191]*'

local utf8 = {}

-- returns the utf8 character byte length at first-byte i
utf8.clen =
	function (s, i)
		local c = string.match(s, utf8char, i)

		if not c then
			return
		end

		return #c
	end

-- maps f over s's utf8 characters f can accept args: (visual_index, utf8_character, byte_index)
utf8.map =
	function (s, f)
		local i = 0
                
		for b, c in string.gmatch(s, '()(' .. utf8char .. ')') do
			i = i + 1
			f(i, c, b)
		end 
	end

-- generator to iterate over all utf8 chars
utf8.iter =
	function (s)
		return coroutine.wrap(function () return utf8.map(s, coroutine.yield) end)
	end

-- return the utf8 character at the "visual index" 'i' + actual byte index
utf8.at =
	function (s, x)
		for i, c, b in utf8.iter(s) do
			if i == x then
				return c, b
			end
		end
	end

-- returns the number of characters in a UTF-8 string
utf8.len =
	function (s)
		-- count the number of non-continuing bytes
		return select(2, string.gsub(s, '[^\128-\193]', ''))
	end

-- like string.sub() but i, j are utf8 strings
utf8.sub =
	function (s, i, j)
		i = string.find(s, i, 1, true)

		if not i then
			return ''
		end

		if j then
			local tmp = string.find(s, j, 1, true)

			if not tmp then
				return ''
			end

			j = (tmp - 1) + #j
		end

		return string.sub(s, i, j)
	end

-- replace all utf8 chars with mapping
utf8.replace =
	function (s, map)
		local new = {}

		for _, c in utf8.iter(s) do
			table.insert(new, map[c] or c)

			if #new > maxitems then
				new = { table.concat(new) }
			end
		end

		return table.concat(new)
	end

-- reverse a utf8 string
utf8.reverse =
	function (s)
		local new = {}

		for _, c in utf8.iter(s) do
			table.insert(new, 1, c)

			if #new > maxitems then
				new = { table.concat(new) }
			end
		end

		return table.concat(new)
	end

-- strip utf8 characters from a string
utf8.strip =
	function (s)
		local new = {}

		for _, c in utf8.iter(s) do
			if #c == 1 then
				table.insert(new, c)

				if #new > maxitems then
					new = { table.concat(new) }
				end
			end
		end

		return table.concat(new)
	end

return utf8
