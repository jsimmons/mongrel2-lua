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

--[[
    This code, although (hopefully) working, is very horrible.
    It's no replacement for a proper database system really, but until then it might do.
]]

local sqlite = require 'lsqlite3'

local error, io, next, pairs, table, tostring, type = error, io, next, pairs, table, tostring, type

module 'mongrel2.config'

local prep = [[
begin transaction;

DROP TABLE IF EXISTS server;
DROP TABLE IF EXISTS host;
DROP TABLE IF EXISTS handler;
DROP TABLE IF EXISTS proxy;
DROP TABLE IF EXISTS route;
DROP TABLE IF EXISTS statistic;
DROP TABLE IF EXISTS mimetype;
DROP TABLE IF EXISTS setting;
DROP TABLE IF EXISTS directory;

CREATE TABLE server (id INTEGER PRIMARY KEY,
    uuid TEXT,
    access_log TEXT,
    error_log TEXT,
    chroot TEXT DEFAULT '/var/www',
    pid_file TEXT,
    default_host INTEGER,
    name TEXT DEFAULT "",
    bind_addr TEXT DEFAULT "0.0.0.0",
    port INTEGER);

CREATE TABLE host (id INTEGER PRIMARY KEY, 
    server_id INTEGER,
    maintenance BOOLEAN DEFAULT 0,
    name TEXT,
    matching TEXT);

CREATE TABLE handler (id INTEGER PRIMARY KEY,
    send_spec TEXT, 
    send_ident TEXT,
    recv_spec TEXT,
    recv_ident TEXT,
    raw_payload INTEGER DEFAULT 0,
    protocol TEXT DEFAULT 'json');

CREATE TABLE proxy (id INTEGER PRIMARY KEY,
    addr TEXT,
    port INTEGER);

CREATE TABLE directory (id INTEGER PRIMARY KEY,
    base TEXT, index_file TEXT, default_ctype TEXT);

CREATE TABLE route (id INTEGER PRIMARY KEY,
    path TEXT,
    reversed BOOLEAN DEFAULT 0,
    host_id INTEGER,
    target_id INTEGER,
    target_type TEXT);

CREATE TABLE setting (id INTEGER PRIMARY KEY, key TEXT, value TEXT);

CREATE TABLE statistic (id SERIAL, 
    other_type TEXT,
    other_id INTEGER,
    name text,
    sum REAL,
    sumsq REAL,
    n INTEGER,
    min REAL,
    max REAL,
    mean REAL,
    sd REAL,
    primary key (other_type, other_id, name));

CREATE TABLE mimetype (id INTEGER PRIMARY KEY, mimetype TEXT, extension TEXT);

CREATE TABLE IF NOT EXISTS log(id INTEGER PRIMARY KEY,
    who TEXT,
    what TEXT,
    location TEXT,
    happened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    how TEXT,
    why TEXT);
    
commit;
]]

local function sql_tostring(obj)
        local t = type(obj)

        if t == 'boolean' then
            return v and '1' or '0'
        elseif t == 'number' then
            return tostring(obj)
        elseif t == 'string' then
            return ('%q'):format(obj)
        elseif t == 'nil' then
            return 'NULL'
        else
            error('could not handle type')
        end
end

local function db_insert(db, name, data)
    local values = {}
    local keys = {}
    local i = 1
    for k, v in pairs(data) do
        if k and v then
            keys[i] = k
            values[i] = sql_tostring(v)
            i = i + 1
        end
    end

    -- Nothing to write.
    if i == 1 then
        return 0
    end

    local fmt = 'INSERT INTO %s(%s) VALUES(%s)'
    local query = fmt:format(name, table.concat(keys, ','), table.concat(values, ','))

    local result = db:exec(query)

    if result ~= sqlite.OK then
        error('error writing sql: ' .. db:errmsg())
    end

    return db:last_insert_rowid()
end

local function db_select(db, name, predicate)
    local query

    if predicate then
        local conditions = {}
        for k, v in pairs(predicate) do
            local condition = ('%s = %s'):format(k, sql_tostring(v))
            table.insert(conditions, condition)
        end

        query = ('SELECT * FROM %s WHERE %s'):format(name, table.concat(conditions, ' AND '))
    else
        query = ('SELECT * FROM %s'):format(name)
    end

    local results = {}
    local function handle_results(data, columns, values, names)
        local row = {}
        for k, v in pairs(names) do
            row[v] = values[k]
        end

        table.insert(results, row)

        return 0
    end

    db:exec(query, handle_results)

    return results
end

local function create_simple_writer(name, ...)
    local args = {...}
    return function(db, obj, state)
        if not state[obj] then
            local data = {}
            for _, key in pairs(args) do
                data[key] = obj[key]
            end

            state[obj] = db_insert(db, name, data)
        end

        return state[obj]
    end
end

local WRITERS = {
    proxy = create_simple_writer('proxy', 'addr', 'port');
    dir = create_simple_writer('directory', 'base', 'index_file', 'default_ctype');
    handler = create_simple_writer('handler', 'send_spec', 'send_ident', 'recv_spec', 'recv_ident', 'raw_payload', 'protocol');
    server = create_simple_writer('server', 'uuid', 'access_log', 'error_log', 'chroot', 'pid_File', 'default_host', 'name', 'bind_addr', 'port');
}

function WRITERS.route(db, obj, state)
        local path = obj.path
        local target = obj.target
        local target_id = WRITERS[target.type](db, target, state)
        db_insert(db, 'route', {path = path; reversed = false; host_id = obj.host_id; target_id = target_id; target_type = target.type})
end

function WRITERS.host(db, obj, state)
        local host = obj.host
        if not state[host] then
            state[host] = db_insert(db, 'host', {server_id = obj.server_id; maintenance = host.maintenance or false; name = host.name; matching = host.matching or host.name})
        end

        return state[host]
end

function WRITERS.setting(db, obj)
    return db_insert(db, 'setting', {key = obj.key; value = obj.value})
end

-- Writes a config to sqlite.
function write(db_file, conf)
    local db = sqlite.open(db_file)

    -- Create a new write cache, otherwise we'd not know what to write, and stuff.
    write_cache = {}

    db:exec(prep)

    for _, server in pairs(conf.servers) do
        local server_id = WRITERS.server(db, server, write_cache)
        for _, host in pairs(server.hosts) do
            local host_id = WRITERS.host(db, {server_id = server_id; host = host}, write_cache)
            for path, target in pairs(host.routes) do
                WRITERS.route(db, {host_id = host_id; path = path; target = target}, write_cache)
            end
        end
    end

    -- Make sure we have settings before we try writing them.
    if conf.settings then
        for _, setting in pairs(conf.settings) do
            WRITERS.setting(db, setting)
        end
    end

    db:close()
end

-- Read a config from sqlite.
function read(db_file)
    local db = sqlite.open(db_file)

    local backends = {}

    local function read_all(t)
        if not backends[t] then backends[t] = {} end
        for _, thing in pairs(db_select(db, t)) do
            thing.type = t
            backends[t][thing.id] = thing
        end
    end

    read_all('handler');
    read_all('proxy');
    read_all('dir');

    local servers = {}
    for _, server in pairs(db_select(db, 'server')) do
        server.hosts = {}
        for _, host in pairs(db_select(db, 'host', {server_id = server.id})) do
            host.routes = {}
            for _, route in pairs(db_select(db, 'route', {host_id = host.id})) do
                host.routes[route.path] = backends[route.target_type][route.target_id]
            end
            table.insert(server.hosts, host)
        end
        table.insert(servers, server)
    end

    local settings = {}
    for _, setting in pairs(db_select(db, 'setting')) do
        settings[setting.key] = setting.value
    end

    db:close()

    return {servers = servers; settings = settings}
end
