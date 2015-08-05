#! /usr/bin/bash
# diff source lua file vs parsed lua file

diff $2 lua5.1-tests/$1.lua lua5.1-roundtripped-tests/$1.lua
