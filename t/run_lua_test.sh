#! /usr/bin/sh
# run a file from Lua 5.1 test suite

# Lua Test Suite's README:
# go to the test directory
# set LUA_PATH to "?;./?.lua" (or, better yet, set LUA_PATH to "./?.lua;;"
# and LUA_INIT to "package.path = '?;'..package.path")
# run "lua all.lua"

cd lua5.1-tests
export LUA_PATH="./?.lua;;"
export LUA_INIT="package.path = '?;'..package.path"
lua $1
