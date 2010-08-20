local m2 = require 'mongrel2'

local sender_id = 'd1e9838e-a1e3-4c94-81b8-9d54360cccff'
local sub_addr = 'tcp://127.0.0.1:3010'
local pub_addr = 'tcp://127.0.0.1:3011'
local io_threads = 1

local ctx = mongrel2.new(io_threads)

local conn = ctx:new_connection(sender_id, sub_addr, pub_addr)

local users = {}

local function get_values(tab)
    local res = {}
    for k, v in pairs(tab) do
        table.insert(res, v)
    end
    return res
end

local function get_keys(tab)
    local res = {}
    for k, v in pairs(tab) do
        table.insert(res, k)
    end
    return res
end

while true do
    local request = conn:recv_json()
print 'got request!'
    local data = request.data

    if data['type'] == 'join' then
        print(data.user, 'joined!')
        -- Propagage the join to all existing clients.
        conn:deliver_json(request.sender, get_keys(users), data)
        -- Maintain id<->nick mapping.
        users[request.conn_id] = data.user
        -- Send out the full userlist to our new client.
        conn:reply_json(request, {['type'] = 'userList', ['users'] = get_values(users)})
    elseif not users[request.conn_id] then
        users[request.conn_id] = data.user
    elseif data['type'] == 'disconnect' then
        local id = request.conn_id
        local nick = users[id]
        print(('%d:%s disconnected'):format(id, nick))
        users[id] = nil
        -- Propagate the disconnect.
        conn:deliver_json(request.sender, get_keys(users), data)
    elseif data['type'] == 'msg' then
        print(('%d:%s claiming to be %s said: %s'):format(request.conn_id, users[request.conn_id], data['user'], data['msg']))
        conn:deliver_json(request.sender, get_keys(users), data)
    end
end


