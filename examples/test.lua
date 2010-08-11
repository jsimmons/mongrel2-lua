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
local ctx = mongrel2.new(io_threads)

-- Creates a new connection object using the mongrel2 context
local conn = ctx:new_connection(sender_id, sub_addr, pub_addr)

local function dump(tab)
	local out = ''
	for k, v in pairs(tab) do
		out = ('%s\n[%s]: %s)'):format(out, k, v)
	end
	return out
end

while true do
	print 'Waiting for request...'
	local req = conn:recv()

	if req:is_disconnect() then
		print 'Disconnected'
	else
		local response = response_string:format(req.sender, req.conn_id, req.path, dump(req.headers), req.body)
		print(response)
		conn:reply_http(req, response)
	end
end

ctx:term()

