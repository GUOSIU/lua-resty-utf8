
-- utf8字符串处理模块 v20.1.16
-- https://github.com/blitmap/lua-utf8-simple

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
-- 110xxxxx 10xxxxxx                   | 07FF   (2047)
-- 1110xxxx 10xxxxxx 10xxxxxx          | FFFF   (65535)
-- 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx | 10FFFF (1114111)

local pattern = '[%z\1-\127\194-\244][\128-\191]*'

-- helper function
local posrelat = function (pos, len)
    if pos < 0 then
        pos = len + pos + 1
    end

    return pos
end

local utf8 = {}

-- THE MEAT

-- maps f over s's utf8 characters f can accept args: (visual_index, utf8_character, byte_index)
utf8.map = function (s, f, no_subs)
    local i = 0

    if no_subs then
        for b, e in s:gmatch('()' .. pattern .. '()') do
            i = i + 1
            local c = e - b
            f(i, c, b)
        end
    else
        for b, c in s:gmatch('()(' .. pattern .. ')') do
            i = i + 1
            f(i, c, b)
        end
    end
end

-- THE REST

-- generator for the above -- to iterate over all utf8 chars
utf8.chars = function (s, no_subs)
    return coroutine.wrap(function () return utf8.map(s, coroutine.yield, no_subs) end)
end

-- returns the number of characters in a UTF-8 string
utf8.len = function (s)
    -- count the number of non-continuing bytes
    return select(2, s:gsub('[^\128-\193]', ''))
end

-- replace all utf8 chars with mapping
utf8.replace = function (s, map)
    return (s:gsub(pattern, map))
end

-- reverse a utf8 string
utf8.reverse = function (s)
    -- reverse the individual greater-than-single-byte characters
    s = s:gsub(pattern, function (c) return #c > 1 and c:reverse() end)

    return (s:reverse())
end

-- strip non-ascii characters from a utf8 string
utf8.strip = function (s)
    return (s:gsub(pattern, function (c) return #c > 1 and '' end))
end

-- like string.sub() but i, j are utf8 strings
-- a utf8-safe string.sub()
utf8.sub = function (s, i, j)
    local l = utf8.len(s)

    i =       posrelat(i, l)
    j = j and posrelat(j, l) or l

    if i < 1 then i = 1 end
    if j > l then j = l end

    if i > j then return '' end

    local diff = j - i
    local iter = utf8.chars(s, true)

    -- advance up to i
    for _ = 1, i - 1 do iter() end

    local c, b = select(2, iter())

    -- i and j are the same, single-charaacter sub
    if diff == 0 then
        return (string.sub(s, b, b + c - 1))
    end

    i = b

    -- advance up to j
    for _ = 1, diff - 1 do iter() end

    c, b = select(2, iter())

    return (string.sub(s, i, b + c - 1))
end

---------- 以下方法是新增的 ------------

-- 过滤 mb4 及以上的字符
utf8.strip_mb4 = function (s)
    return (s:gsub(pattern, function (c) return #c > 3 and '' end))
end

-- 截取左边字符
utf8.left = function (s, n)
    return utf8.sub(s, 0, n)
end

-- 截取右边字符
utf8.right = function (s, n)
    return utf8.sub(s, 0-n)
end

-- 去掉左右两边的空白符号
utf8.trim = function (s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 去掉左边空白符号
utf8.ltrim = function (s)
    return (s:gsub("^%s+", ""))
end

-- 去掉右边空白符号
utf8.rtrim = function (s)
    return (s:gsub("%s+$", ""))
end

-- 单字节或双字节算一个宽度
-- 三字节及以上算两个宽度，如中文、emoji符号
utf8.width = function(s)

    local width, children = 0, 0

    for i=1, #s do
        local byte = string.byte(s, i, i)
        if byte < 128 or byte > 193 then
            width = width + 1
            children = 0
        else
            children = children + 1
            if children == 2 then
                width = width + 1
            end
        end
    end

    return width
end

return utf8
