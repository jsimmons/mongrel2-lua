--[[
# Copyright (c) 2010 Joshua Simmons <simmons.44@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
]]

local json = require 'json'
local util = require 'mongrel2.util'

local error = error
local string = string
string.split = util.split
local setmetatable = setmetatable
local tonumber = tonumber
local unpack = unpack

module 'mongrel2.request'

local meta = {}
meta.__index = meta

function meta:is_disconnect()
	return self.headers.METHOD == 'JSON' and self.data.type == 'disconnect'
end

local function new(sender, conn_id, path, headers, body)
	local obj = {
		sender = sender;
		conn_id = conn_id;
		path = path;
		headers = headers;
		body = body;
		data = {};
	}

	if obj.headers.METHOD == 'JSON' then
		obj.data = json.decode(body)
	end

	return setmetatable(obj, meta)
end

local function parse_netstring(ns)
    local length, rest = unpack(ns:split(':', 2, true))
    if not length and rest then error('could not split netsplit length and data', 2) end

    length = tonumber(length)
    if length == nil then error('invalid netstring length specifier', 2) end

    if rest:sub(length + 1, length + 1) ~= ',' then error('netstring did not end in ","', 2) end

    -- Returns the body of the netstring parsed, followed by any left over data.
    return rest:sub(1, length), rest:sub(length + 2)
end

function parse(msg)
        local sender, conn_id, path, rest = unpack(msg:split(' ', 4))
        local headers, rest = parse_netstring(rest)
        body = parse_netstring(rest)
        headers = json.decode(headers)

        return new(sender, conn_id, path, headers, body)
end


