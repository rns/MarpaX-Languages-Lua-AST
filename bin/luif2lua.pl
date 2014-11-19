#!perl
# Copyright 2014 Ruslan Shvedov

# read LUIF source from standard input, transpile it to lua
# and print the result to standard output

use v5.14.2;
use warnings;
use strict;

use MarpaX::Languages::Lua::LUIF;
my $p = MarpaX::Languages::Lua::LUIF->new();

my $luif = do { local $/ = undef; <> };

unless ($luif){
    say "Usage: perl luif2lua.pl < input.luif > output.lua";
    exit 1;
}

my $ast = $p->parse( $luif );
unless (defined $ast){
    die "Can't transpile input: parse error";
    next;
}
my $lua_bnf = $p->fmt( $ast );
say $lua_bnf;
