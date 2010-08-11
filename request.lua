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
        local colon = ns:find(':', 1, true)
        if not colon then error('no colon found in netstring', 2) end

        local length = tonumber(ns:sub(1, colon - 1))
        if length == nil then error('invalid netstring length specifier', 2) end

		local data_begin = colon + 1
		local data_end = colon + length + 1

        if ns:sub(data_end,data_end) ~= ',' then error('netstring did not end in ","', 2) end

        local to_comma = ns:sub(data_begin, data_end - 1)
        local rest = ns:sub(data_end + 1)
        return to_comma, rest
end

function parse(msg)
        local sender, conn_id, path, rest = unpack(msg:split(' ', 4))
        local headers, rest = parse_netstring(rest)
        body = parse_netstring(rest)
        headers = json.decode(headers)

        return new(sender, conn_id, path, headers, body)
end


