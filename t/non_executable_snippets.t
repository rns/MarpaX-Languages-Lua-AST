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

my $input = <<END;
a = '\\\'' -- 1 escaped \ 1 escaped '
END
#'

my $expected_fmt = <<END;
END

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse( $input );
unless (defined $ast){
    $p->parse( $input, { trace_terminals => 1 } );
    BAIL_OUT "Can't parse:\n$input";
}

my $fmt = $p->serialize( $ast );
say $fmt;

TODO: {
    todo_skip "ast serialization to formatted source shelved until lua test suite parsing is done", 1;
    is $fmt, $expected_fmt, 'format by seralizing lua code ast';
}

done_testing();

