local mongrel2 = require 'mongrel2'

local sender_id = '558c92aa-1644-4e24-a524-39baad0f8e78'
local sub_addr = 'tcp://127.0.0.1:8989'
local pub_addr = 'tcp://127.0.0.1:8988'
local io_threads = 1

local response_string = [[
<pre>
SENDER: %s
IDENT: %s
PATH: %s
HEADERS: %s
BODY: %s
</pre>
]]

-- Create new mongrel2 context
-- This is basically just a wrapper around the zeromq context so we can
-- properly terminate it, and set a number of threads to use.
local ctx = assert(mongrel2.new(io_threads))

-- Creates a new connection object using the mongrel2 context
local conn = assert(ctx:new_connection(sender_id, sub_addr, pub_addr))

local assert = assert
local format = string.format
local recv = conn.recv
local reply_http = conn.reply_http

local function dump(tab)
    local out = ''
    for k, v in pairs(tab) do
        out = format('%s\n-- [%s]: %s)', out, k, v)
    end
    return out
end

while true do
    local req = assert(recv(conn))

    local response = format(response_string, req.sender, req.conn_id, req.path, dump(req.headers), req.body)

    assert(reply_http(conn, req, response))
end

assert(ctx:term())

