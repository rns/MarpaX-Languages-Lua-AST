#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

#
use 5.010;
use warnings;
use strict;

use Test::More  skip_all => "extension not implemented yet";

use MarpaX::Languages::Lua::AST;

# test extension of lua parses grammar

my $bnf = {

## BNF statement
stat ::= BNF

# There is only one BNF statement,
# combining priorties, sequences, and alternation
BNF ::= lhs '::=' <prioritized alternatives>
<prioritized alternatives> ::= <prioritized alternative>+ separator => <double bar>
<prioritized alternative> ::= <alternative>+ separator => <bar>
<alternative> ::= rhs | rhs ',' <alternative fields>
<alternative fields> ::= <alternative field>* separator => comma
<alternative field> ::= field | action
action ::= 'action' '(' <action parlist> ')' block <end>
<action parlist> ::= <symbol parameter> | <action parlist> ',' <symbol parameter>
<symbol parameter> ::= <named RH symbol>
  | <named RH symbol> '[' <nonnegative integer> ']'
  | <named RH symbol> '[]'

<named RH symbol> ::= <named symbol>
lhs ::= <named symbol>

<double bar> ~ '||'
bar ~ '|'
comma ~ ','

rhs ::= <RH atom>+
<RH atom> ::=
     '[]' # for empty symbol
   | <separated sequence>
   | <named symbol>
   | '(' alternative ')'

# The sequence notation is extended to counted sequences,
# and a separator notation adopted from Perl 6 is used

<named symbol> ::= <symbol name>
<separated sequence> ::=
      sequence
| sequence '%' separator # proper separation
| sequence '%%' separator # Perl separation

separator ::= <named symbol>

sequence ::=
     <named symbol> '+'
   | <named symbol> '*'
   | <named symbol> '?'
   | <named symbol> '*' <nonnegative integer> '..' <nonnegative integer>
   | <named symbol> '*' <nonnegative integer> '..' '*'

# symbol name is any valid Lua name, plus those with
# non-initial hyphens
# TODO: add angle bracket variation
<symbol name> ~ [a-zA-Z_] <symbol name chars>
<symbol name chars> ~ [-\w]*

<nonnegative integer> ~ [\d]+

## end of BNF statement spec
};

# example of Lua extended with BNF
my $input = <<END;
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

print("enter a number:")
a = io.read("*number")        -- read a number
print(fact(a))
END

my $expected_fmt = <<END;
END

my $p = MarpaX::Languages::Lua::AST->new;

my $p->extend({

    #
    rules => $bnf,
    # these must return ast subtrees serialized to valid lua
    handlers => {
        # node_id => sub {}

    },

});

my $ast = $p->parse( $input );

unless (defined $ast){
    $p->parse( $input, { trace_terminals => 1 } );
    fail "Can't parse:\n$input";
}

my $fmt = $p->serialize( $ast );
say $fmt;

TODO: {
    todo_skip "ast serialization to formatted source shelved until lua test suite parsing is done", 1;
    is $fmt, $expected_fmt, 'format by seralizing lua code ast';
}

done_testing();

