#! /usr/bin/sh
# generate output files by running Lua 5.1 test suite

# Lua Test Suite's README:
# go to the test directory
# set LUA_PATH to "?;./?.lua" (or, better yet, set LUA_PATH to "./?.lua;;"
# and LUA_INIT to "package.path = '?;'..package.path")
# run "lua all.lua"

cd lua5.1-tests
export LUA_PATH="./?.lua;;"
export LUA_INIT="package.path = '?;'..package.path"
# lua all.lua fails at main.lua hence the tests are run individually
lua api.lua > api.lua.out
lua attrib.lua > attrib.lua.out
lua big.lua > big.lua.out
lua calls.lua > calls.lua.out
lua checktable.lua > checktable.lua.out
lua closure.lua > closure.lua.out
lua code.lua > code.lua.out
lua constructs.lua > constructs.lua.out
lua db.lua > db.lua.out
lua errors.lua > errors.lua.out
lua events.lua > events.lua.out
lua files.lua > files.lua.out
lua gc.lua > gc.lua.out
lua literals.lua > literals.lua.out
lua locals.lua > locals.lua.out
lua main.lua > main.lua.out
lua math.lua > math.lua.out
lua nextvar.lua > nextvar.lua.out
lua pm.lua > pm.lua.out
lua sort.lua > sort.lua.out
lua strings.lua > strings.lua.out
lua vararg.lua > vararg.lua.out
lua verybig.lua > verybig.lua.out



