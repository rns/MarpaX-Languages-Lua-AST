: run a file from Lua 5.1 test suite

: Lua Test Suite's README:
: go to the test directory
: set LUA_PATH to "?;./?.lua" (or, better yet, set LUA_PATH to "./?.lua;;"
: and LUA_INIT to "package.path = '?;'..package.path")
: run "lua all.lua"

: check if we are in the test suite dir
@echo off
if exist ".\t\%1" cd "%1"
if exist "%1" cd "%1"

: prepare to run
set LUA_PATH="./?.lua;;"
:set LUA_INIT="package.path = '?;'..package.path"

: run
lua %2
