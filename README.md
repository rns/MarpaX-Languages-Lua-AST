MarpaX-Languages-Lua-AST
========================

Lua 5.1 Parser in barebones SLIF

Test Suite Organization
-----------------------

Testing is now done by serializing ASTs to a stream of tokens `' '`-separated 
where appropriate (e.g. not after opening ( `'`, `"`, `[` ) or before closing 
(`'`, `"`, `]`) string quotes.

Tests of Lua code are split to executable snippets (code fragments 
that can be wrapped to a function returning single scalar value, e.g. 
assignment), non-executable snippets (code fragments that can be wrapped 
as aforesaid), programs (files external to test scripts including Lua 5.1 
test suite), and functions (code fragments returning values).
