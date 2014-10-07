#! /usr/bin/sh
# run Lua 5.1 test suite

# Lua Test Suite's README:
# go to the test directory
# set LUA_PATH to "?;./?.lua" (or, better yet, set LUA_PATH to "./?.lua;;"
# and LUA_INIT to "package.path = '?;'..package.path")
# run "lua all.lua"

cd lua5.1-tests
export LUA_PATH="./?.lua;;"
export LUA_INIT="package.path = '?;'..package.path"
# lua all.lua fails at main.lua hence the tests are run
lua api.lua
lua attrib.lua
lua big.lua
lua calls.lua
lua checktable.lua
lua closure.lua
lua code.lua
lua constructs.lua
lua db.lua
lua errors.lua
lua events.lua
lua files.lua
lua gc.lua
lua literals.lua
lua locals.lua
lua main.lua
lua math.lua
lua nextvar.lua
lua pm.lua
lua sort.lua
lua strings.lua
lua vararg.lua
lua verybig.lua



