#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

#
use 5.010;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# non-executable snippets which can't be wrapped to a function
# will be tested by comparison with formatted ast

my @tests = (
[ q{
-- the below line parses ok
a = '\\\'' -- 1 escaped \ 1 escaped '
-- the below lines are currently misparsed as
-- x = '"нlo"\n\\'
-- assert(string.format(' ...
x = '"нlo"\n\\'
assert(string.format('%q%s', x, x) == '"\\"нlo\\"\\\n\\\\""нlo"\n\\')
},
q{
}
],

);

my $p = MarpaX::Languages::Lua::AST->new;

for my $test (@tests){
    my ($snippet, $expected_fmt) = @{ $test };
    my $ast = $p->parse( $snippet );
    unless (defined $ast){
        $p->parse( $snippet, { trace_terminals => 1 } );
        BAIL_OUT "Can't parse:\n$snippet";
    }

    my $fmt = $p->serialize( $ast );
    say $fmt;

    TODO: {
        todo_skip "ast serialization to formatted source shelved until lua test suite parsing is done", 1;
        is $fmt, $expected_fmt, 'format by seralizing lua code ast';
    }
}

done_testing();

