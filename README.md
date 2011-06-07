mongrel2-lua
============

A [mongrel2](http://mongrel2.org/index) backend handler for Lua, implemented in Lua, and based on the mongrel2 python backend api.

Versions are tagged and match the mongrel2 version they should work with. ie v1.3[.x] should work with mongrel2 version 1.3. HEAD is kept in rough sync with the latest changes in the mongrel2 trunk.

Dependencies
------------
* [Mongrel2](http://mongrel2.org/index)
* [Lua](http://www.lua.org/)
* [ZeroMQ](http://www.zeromq.org/) requires at least 2.1.4 (not 2.1.6!)
* [ZeroMQ-lua](http://github.com/iamaleksey/lua-zmq)
* [LuaJSON](http://github.com/harningt/luajson)
* [tnetstrings.lua](https://github.com/jsimmons/tnetstrings.lua)

Installation
------------
m2-lua ships with a very basic Makefile that should install the required files somewhere useful.
    > sudo make install
    > sudo make uninstall

Usage
-----

One may be more interested in using one of the web frameworks that are listed [here](https://github.com/jsimmons/mongrel2-lua/wiki/Some-frameworks-using-mongrel2-lua)
as this library is a low level interface.

Otherwise I won't try to describe how mongrel2 or the handlers work, for that there's [the manual](http://mongrel2.org/doc/tip/docs/manual/book.wiki), however this should describe the basic api.

If in doubt, it's probably exactly the same as the python API.

There is a very basic demo in examples/test.lua and the code itself should be easy enough to follow.
