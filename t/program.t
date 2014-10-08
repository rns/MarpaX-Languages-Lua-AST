#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua program and test its execution results
# returned by the lua interpreter for the original source code and
# for the source code parsed to AST that is then serialized

# source of programs: http://lua-users.org/wiki/SampleCode

use 5.010;
use warnings;
use strict;

use Test::More;
use Test::Output;

use File::Temp qw{ tempfile };

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;

use Cwd qw();
my $pwd = Cwd::cwd();

my @lua_prog_files = qw{

    other-lua-tests/coroutine.lua

    lua5.1-tests/api.lua
    lua5.1-tests/attrib.lua
    lua5.1-tests/big.lua
    lua5.1-tests/calls.lua
    lua5.1-tests/checktable.lua
    lua5.1-tests/closure.lua
    lua5.1-tests/code.lua
    lua5.1-tests/constructs.lua
    lua5.1-tests/db.lua
    lua5.1-tests/errors.lua
    lua5.1-tests/events.lua
    lua5.1-tests/files.lua
    lua5.1-tests/gc.lua
    lua5.1-tests/literals.lua
    lua5.1-tests/locals.lua
    lua5.1-tests/main.lua
    lua5.1-tests/math.lua
    lua5.1-tests/nextvar.lua
    lua5.1-tests/pm.lua
    lua5.1-tests/sort.lua
    lua5.1-tests/strings.lua
    lua5.1-tests/vararg.lua
    lua5.1-tests/verybig.lua
};

for my $lua_fn (@lua_prog_files){
    # prepend t if running under prove
    $lua_fn = 't/' . $lua_fn unless $pwd =~ m{ /t$ }x;

    diag $lua_fn;

    # As an example, consider the following code:
    my $coroutine = slurp_file( $lua_fn );

    # When you run it, it produces the following output:
    my $expected_stdout = slurp_file( qq{$lua_fn.out} );

    # parse and write ast serialized to tokens to a temporary file
    my $ast = $p->parse($coroutine);

SKIP: {
        skip "Can't parse $lua_fn yet", 1 unless defined $ast;
        my $lua_file = whip_up_lua_file( $p->tokens($ast) );
        combined_is sub { system 'lua', $lua_file }, $expected_stdout, $lua_fn;
    };
}

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_text) = @_;
    my ($fh, $filename) = tempfile();
    say $fh $lua_text;
    close $fh;
    return $filename;
}

done_testing();

