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
local zmq = require 'zmq'

local request = require 'mongrel2.request'
local util = require 'mongrel2.util'

local pairs, setmetatable, tostring = pairs, setmetatable, tostring
local string, table = string, table

module 'mongrel2.connection'

--[[
    A Connection object manages the connection between your handler
    and a Mongrel2 server (or servers).  It can receive raw requests
    or JSON encoded requests whether from HTTP or MSG request types,
    and it can send individual responses or batch responses either
    raw or as JSON.  It also has a way to encode HTTP responses
    for simplicity since that'll be fairly common.
]]

-- (code) (status)\r\n(headers)\r\n\r\n(body)
local HTTP_FORMAT = 'HTTP/1.1 %s %s\r\n%s\r\n\r\n%s'

local function http_response(body, code, status, headers)
    headers['content-length'] = body:len()
    
    local raw = {}
    for k, v in pairs(headers) do
        table.insert(raw, ('%s: %s'):format(k, v))
    end
    
    return HTTP_FORMAT:format(code, status, table.concat(raw, '\r\n'), body)
end

local meta = {}
meta.__index = meta

--[[
    Receives a raw mongrel2.request object that you can then work with.
]]
function meta:recv()
    return request.parse(self.reqs:recv())
end

--[[
    Same as regular recv, but assumes the body is JSON and 
    creates a new attribute named req.data with the decoded
    payload.  This will throw an error if it is not JSON.

    Normally Request just does this if the METHOD is 'JSON'
    but you can use this to force it for say HTTP requests.
]]
function meta:recv_json()
    local recv = self:recv()
    
    if not recv.data then
        recv.data = json.decode(recv.body)
    end

    return recv
end

--[[
    Raw send to the given connection ID at the given uuid, mostly 
    used internally.
]]
function meta:send(uuid, conn_id, msg)
    conn_id = tostring(conn_id)
    local header = ('%s %d:%s,'):format(uuid, conn_id:len(), conn_id)
    self.resp:send(header .. ' ' .. msg)
end

--[[
    Does a reply based on the given Request object and message.
    This is easier since the req object contains all the info
    needed to do the proper reply addressing.
]]
function meta:reply(req, msg)
    self:send(req.sender, req.conn_id, msg) 
end

--[[
    Same as reply, but tries to convert data to JSON first.
]]
function meta:reply_json(req, data)
    self:reply(req, json.encode(data))
end

--[[
    Basic HTTP response mechanism which will take your body,
    any headers you've made, and encode them so that the 
    browser gets them.
]]
function meta:reply_http(req, body, code, status, headers)
    code = code or 200
    status = status or 'OK'
    headers = headers or {}
    self:reply(req, http_response(body, code, status, headers))
end

--[[
    This lets you send a single message to many currently
    connected clients.  There's a MAX_IDENTS that you should
    not exceed, so chunk your targets as needed.  Each target
    will receive the message once by Mongrel2, but you don't have
    to loop which cuts down on reply volume.
]]
function meta:deliver(uuid, idents, data)
    self:send(uuid, table.concat(idents, ' '), data)
end

--[[
    Same as deliver, but converts to JSON first.
]]
function meta:deliver_json(uuid, idents, data)
    self:deliver(uuid, idents, json.encode(data))
end

--[[
    Same as deliver, but builds a HTTP response.
]]
function meta:deliver_http(uuid, idents, body, code, status, headers)
    code = code or 200
    status = status or 'OK'
    headers = headers or {}
    self:deliver(uuid, idents, http_response(body, code, status, headers))
end

--[[
-- Tells Mongrel2 to explicitly close the HTTP connection.
--]]
function meta:close(req)
    self:reply(req, "")
end

--[[
-- Sends and explicit close to multiple idents with a single message.
--]]
function meta:deliver_close(uuid, idents)
    self:deliver(uuid, idents, "")
end

--[[
    Creates a new connection object.
    Internal use only, call ctx:new_context instead.
]]
function new(ctx, sender_id, sub_addr, pub_addr)
    local reqs = ctx:socket(zmq.PULL)
    reqs:connect(sub_addr)

    local resp = ctx:socket(zmq.PUB)
    resp:connect(pub_addr)
    resp:setopt(zmq.IDENTITY, sender_id)

    local obj = {
        ctx = ctx;
        sender_id = sender_id;

        sub_addr = sub_addr;
        pub_addr = pub_addr;

        reqs = reqs;
        resp = resp;
    }

    return setmetatable(obj, meta)
end

