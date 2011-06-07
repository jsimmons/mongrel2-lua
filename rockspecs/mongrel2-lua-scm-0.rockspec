package = "mongrel2-lua"
version = "scm-0"

source = {
   url = "git://github.com/jsimmons/mongrel2-lua.git",
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
   "tnetstrings",
   "lsqlite3"
}

build = {
  type = "none",
  install = {
    lua = {
      ["mongrel2.lua"]        = "mongrel2/init.lua",
      ["mongrel2.connection"] = "mongrel2/connection.lua",
      ["mongrel2.request"]    = "mongrel2/request.lua",
      ["mongrel2.util"]       = "mongrel2/util.lua",
      ["mongrel2.config"]     = "mongrel2/config.lua",
    };
  };
}
