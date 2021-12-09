-- vim:filetype=lua:

local key = ngx.var.cookie_ngt -- NGinx Target

if key == nil then
    return "missing"
end

local m = ngx.re.match(key, "^\"?([0-9.]*)/([0-9]*)\\+([0-9a-f]*)\"?$", "io")
if m == nil then
    return "invalid"
end
local payload = m[1] .. "/" .. m[2]
local signature = m[3]

--local str = require "resty.string"
function to_hex(str)
    return str:gsub(".", function(c) return string.format("%02x", c:byte(1)) end)
end

local hmac = to_hex(ngx.hmac_sha1('secret key here', payload))

if hmac ~= signature then
    --return "+" .. payload .. "+" .. hmac .. "+" .. signature
    return "failed"
end

local valid_until = tonumber(m[2])
if valid_until < ngx.time() then
    return "expired"
end

return m[1]
