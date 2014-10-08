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
    my $lua_file = whip_up_lua_file( $p->tokens($ast) );

    stdout_is sub { system 'lua', $lua_file }, $expected_stdout, $lua_fn;
}

sub slurp_file{
    my ($fn) = @_;
    open my $fh, "<", $fn or die "Can't open $fn: $@.";
    binmode( $fh, ":utf8" );
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_text) = @_;
    my ($fh, $filename) = tempfile();
    binmode( $fh, ":utf8" );
    say $fh $lua_text;
    close $fh;
    return $filename;
}

done_testing();

