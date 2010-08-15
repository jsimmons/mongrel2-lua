mongrel2-lua
============

A [mongrel2](http://mongrel2.org/index) backend handler for Lua, implemented in Lua, and based on the mongrel2 python backend api.

Dependencies
------------
* [Mongrel2](http://mongrel2.org/index)
* [Lua](http://www.lua.org/)
* [ZeroMQ](http://www.zeromq.org/) tested against 2.0.7
* [ZeroMQ-lua](http://www.zeromq.org/bindings:lua) <strike>but for zmq 2.0.7 you'll need [my fork](http://github.com/jsimmons/lua-zmq) as some constants have changed names.</strike>
* [LuaJSON](http://github.com/harningt/luajson)

Installation
------------
I've included a very simple makefile that should make installation easy.
    sudo make install

Usage
-----
I won't try to describe how mongrel2 or the handlers work, for that there's [the manual](http://mongrel2.org/doc/tip/docs/manual/book.wiki), however this should describe the basic api.
Generated API documentation is on the TODO list.

If in doubt, it's probably exactly the same as the python API.

First of all we need to require the library.
    local mongrel2 = require 'mongrel2'

Then create a context, this takes the number of zmq io threads as an optional parameter.
    local ctx = mongrel2.new()

With the context we create a new connection object.
    local sender_id = '558c92aa-1644-4e24-a524-39baad0f8e78'
    local sub_addr = 'tcp://127.0.0.1:8989'
    local pub_addr = 'tcp://127.0.0.1:8988'
    local conn = ctx:new_connection(sender_id, sub_addr, pub_addr)

Here's a quick list of functions in the connection object with comments ripped directly from Zed's python library. :)
    --[[
        Receives a raw mongrel2.request object that you can then work with.
    ]]
    connection:recv()

    --[[
        Same as regular recv, but assumes the body is JSON and 
        creates a new attribute named req.data with the decoded
        payload.  This will throw an error if it is not JSON.

        Normally Request just does this if the METHOD is 'JSON'
        but you can use this to force it for say HTTP requests.
    ]]
    connection:recv_json()

    --[[
        Raw send to the given connection ID at the given uuid, mostly 
        used internally.
    ]]
    connection:send(uuid, conn_id, msg)

    --[[
        Does a reply based on the given Request object and message.
        This is easier since the req object contains all the info
        needed to do the proper reply addressing.
    ]]
    connection:reply(req, msg)

    --[[
        Same as reply, but tries to convert data to JSON first.
    ]]
    connection:reply_json(req, data)

    --[[
        Basic HTTP response mechanism which will take your body,
        any headers you've made, and encode them so that the 
        browser gets them.
    ]]
    connection:reply_http(req, body, code, status, headers)

    --[[
        This lets you send a single message to many currently
        connected clients.  There's a MAX_IDENTS that you should
        not exceed, so chunk your targets as needed.  Each target
        will receive the message once by Mongrel2, but you don't have
        to loop which cuts down on reply volume.
    ]]
    connection:deliver(uuid, idents, msg)

    --[[
        Same as deliver, but converts to JSON first.
    ]]
    connection:deliver_json(uuid, idents, data)

    --[[
        Same as deliver, but builds a HTTP response.
    ]]
    connection:deliver_http(uuid, idents, body, code, status, headers)

Finally there is a very basic demo in examples/test.lua and the code itself should be easy enough to follow.
