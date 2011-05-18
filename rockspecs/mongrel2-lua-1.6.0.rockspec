package = "mongrel2-lua"
version = "1.6.0"
source = {
   url = "https://github.com/jsimmons/mongrel2-lua/tarball/v1.6.0",
}
description = {
   summary = "A mongrel2 backend handler for Lua.",
   license = "MIT/X11",
   homepage = "http://github.com/jsimmons/mongrel2-lua"
}
dependencies = {
   "lua >= 5.1",
   "lua-zmq",
   "luajson",
   "lsqlite3"
}

build = {
  type = "none",
  install = {
    lua = {
      ["mongrel2.lua"]        = "init.lua",
      ["mongrel2.connection"] = "connection.lua",
      ["mongrel2.request"]    = "request.lua",
      ["mongrel2.util"]       = "util.lua",
      ["mongrel2.config"]     = "config.lua",
    };
  };
}
