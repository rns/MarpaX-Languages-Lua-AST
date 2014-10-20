#!perl
# Copyright 2014 Ruslan Shvedov

#
use v5.14.2;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# test extension of lua parses grammar

my $bnf = q{

## BNF statement
stat ::= BNF

# There is only one BNF statement,
# combining priorities, sequences, and alternation
BNF ::= lhs '::=' <prioritized alternatives>
<prioritized alternatives> ::= <prioritized alternative>+ separator => <double bar>
<prioritized alternative> ::= <alternative>+ separator => <bar>
<alternative> ::= rhs | rhs ',' <alternative fields>
<alternative fields> ::= <alternative field>+ separator => comma
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
#<symbol name> ~ [a-zA-Z_] <symbol name chars>
#<symbol name chars> ~ [-\w]*
<symbol name> ::= Name

#<nonnegative integer> ~ [\d]+
<nonnegative integer> ::= Number

# <symbol name>, <symbol name chars>, <nonnegative integer> rules
# are commented out from Jeffrey Kegler's BNF because
# MarpaX::Languages::Lua::AST::extend() doesn't support character classes.
# For the moment, suitable tokens from Lua grammar (Name and Number) are used instead
# TODO: support charclasses per https://gist.github.com/rns/2ae390a2c7d235687287

## end of BNF statement spec
};

# create Lua parser and extend it with BNF rules above
my $p = MarpaX::Languages::Lua::AST->new( { discard_comments => 1 } );
$p->extend({
    # these rules will be incorporated into grammar source
    rules => $bnf,
    # these literals will be made tokens for external lexing
    literals => {
            '%%' => 'Perl separation',
            '::=' => 'op declare bnf',
            '?' => 'question',
            'action' => 'action literal',
            '[]' => 'empty symbol',
    },
    # these must return ast subtrees serialized to valid lua
    handlers => {
        # node_id => sub {}
    },
});

# test lua bnf
my @tests = (

[ 'bare Marpa::R2 synopsys BNF in lua function', q{
-- BNF rules
function lua_bnf_bare()
  Script ::= Expression+ % comma
  Expression ::=
    Number
    | left_paren Expression right_paren
   || Expression exp Expression
   || Expression mul Expression
    | Expression div Expression
   || Expression add Expression
    | Expression sub Expression
end
},
<<EOS
function lua_bnf_bare()
  local bnf = {
    { lhs = 'Script',   rhs = { 'Expression+' }, separator = comma, proper = 1  },
    { lhs = 'Expression', rhs = { 'Number' }                    },
    { lhs = 'Expression', rhs = { 'left_paren', 'Expression', 'right_paren' }     },
    { lhs = 'Expression', rhs = { 'Expression', 'op_exp', 'Expression' }      },
    { lhs = 'Expression', rhs = { 'Expression', 'op_mul', 'Expression' }      },
    { lhs = 'Expression', rhs = { 'Expression', 'op_div', 'Expression' }      },
    { lhs = 'Expression', rhs = { 'Expression', 'op_add', 'Expression' }      },
    { lhs = 'Expression', rhs = { 'Expression', 'op_sub', 'Expression' }      },
  }
end
EOS
],

[ 'Marpa::R2 synopsys with actions in Lua functions',
q{
function lua_bnf_actions()
  Script ::= Expression+ % comma
  Expression ::=
    Number
    | left_paren Expression right_paren
   || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
   || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
    | Expression op_div Expression, action (e1, e2) return e1 / e2 end
   || Expression op_add Expression, action (e1, e2) return e1 + e2 end
    | Expression op_sub Expression,  action (e1, e2) return e1 - e2 end
end
},
<<EOS
function lua_bnf_actions()
  local bnf = {
    { lhs = 'Script', rhs = { 'Expression+' }, separator = comma, proper = 1 },
    { lhs = 'Expression', rhs = { 'Number' } },
    { lhs = 'Expression', rhs = { 'left_paren', 'Expression', 'right_paren' } } ,
    { lhs = 'Expression', rhs = { 'Expression', 'op_exp', 'Expression' },
        action = function (e1, e2) return e1 ^ e2 end } ,
    { lhs = 'Expression', rhs = { 'Expression', 'op_mul', 'Expression' },
        action  = function (e1, e2) return e1 * e2 end } ,
    { lhs = 'Expression', rhs = { 'Expression', 'op_div', 'Expression' },
        action  = function (e1, e2) return e1 / e2 end } ,
    { lhs = 'Expression', rhs = { 'Expression', 'op_add', 'Expression' },
        action  = function (e1, e2) return e1 + e2 end } ,
    { lhs = 'Expression', rhs = { 'Expression', 'op_sub', 'Expression' },
        action  = function (e1, e2) return e1 - e2 end } ,
  }
end
EOS
],
#[ '...', q{...}, q{...} ],
);

for my $test (@tests){
    my ($name, $lua_bnf, $subtree ) = @$test;
    my $ast = $p->parse( $lua_bnf );
    unless (defined $ast){
        fail "Can't parse:\n$lua_bnf";
        next;
    }
    my $lua_bnf_ast = $p->serialize( $ast );
#    say $lua_bnf_ast;
    like $lua_bnf_ast, qr/\Q$subtree\E/xms, $name;
}

done_testing();

