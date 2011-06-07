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
local tns = require 'tnetstrings'
local tns_parse = tns.parse

local util = require 'mongrel2.util'

local pcall, setmetatable, tonumber, unpack = pcall, setmetatable, tonumber, unpack

-- Use our own split mechanism, but put it into string so we can call it on strings directly.
local string = string
string.split = util.split

local Request = {}
Request.__index = Request

-- Returns true if the request object is a disconnect event.
function Request:is_disconnect()
    return self.headers['METHOD'] == 'JSON' and self.data.type == 'disconnect'
end

-- Checks if the request was for a connection close.
function Request:should_close()
    if self.headers['connection'] == 'close' then
        return true
    elseif self.headers['VERSION'] == 'HTTP/1.0' then
        return true
    else
        return false
    end
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

    if obj.headers['METHOD'] == 'JSON' then
        obj.data = json.decode(body)
    end

    return setmetatable(obj, Request)
end

-- Parses a request and returns a new request object describing it.
local function parse(msg)
        local sender, conn_id, path, rest = unpack(msg:split(' ', 4))
        
        local headers, rest_idx = tns_parse(rest)
        if headers == nil then return nil, rest_idx end

        local header_type = type(headers)

        if header_type == 'string' then
            local success, headers = pcall(json.decode, headers)
            if not success then return nil, headers end
        elseif header_type ~= 'table' then -- We have to be a string or a table here.
            return nil, 'got invalid headers type'
        end

        local body, rest_idx = tns_parse(rest, rest_idx)

        return new(sender, conn_id, path, headers, body)
end

return {
    parse = parse;
}
