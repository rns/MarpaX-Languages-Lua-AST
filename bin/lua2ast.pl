#!perl
# Copyright 2015 Ruslan Shvedov

# print lua ast on stdout

use 5.010;
use warnings;
use strict;

my ($fn) = @ARGV;

#do { say "Usage: $0 filespec"; exit 1 } unless $fn;

$fn = '../t/lua5.1-tests/api.lua';

open my $fh, $fn or die "Can't open $fn: $@.";
my $lua_src = do { local $/ = undef; <$fh> };
close $fh;

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new();

use lib qw{/home/Ruslan/MarpaX-AST/lib};
use lib qw{c:/cygwin/home/Ruslan/MarpaX-AST/lib};
use MarpaX::AST;

use Data::Dumper;
my $ast = $p->parse( $lua_src );
say Dumper( $p->parse( $lua_src ) );


