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

use Data::Dumper::Concise;
# create Lua parser and extend it with BNF rules above
my $p = MarpaX::Languages::Lua::AST->new( { discard_comments => 1 } );

# [ lhs, [ rhs ], adverbs
sub ast_traverse{
    my ($ast, $context) = @_;
    if (ref $ast){
        my ($node_id, @children) = @$ast;
        if ($node_id eq 'stat'){
            ast_traverse(@children);
        }
        elsif ($node_id eq 'BNF'){
#            say Dumper \@children;
            my ($lhs, $op, $alternatives) = @children;
            return {
                lhs => ast_traverse( $lhs ),
                rhs => ast_traverse( $alternatives ),
            }
        }
        elsif ( $node_id eq 'lhs' ){
            return $children[0]->[1]->[1]->[1];
        }
        elsif ( $node_id eq 'prioritized alternatives' ){
#            say "$node_id: ", Dumper \@children;
            return {
                'prioritized alternatives' => [ map { ast_traverse( $_ ) } @children ]
            }
        }
        elsif ( $node_id eq 'prioritized alternative' ){
#            say "$node_id: ", Dumper \@children;
            return {
                'prioritized alternative' => [
                    map { ast_traverse( $_ ) } @children
                ]
            }
        }
        elsif ( $node_id eq 'alternative' ){
#            say "$node_id: ", Dumper \@children;
            return [ map { ast_traverse( $_ ) } grep { $_->[0] ne 'comma' } @children ];
        }
        elsif ( $node_id eq 'separated sequence' ){
#            say "$node_id: ", Dumper \@children;
            my ($sequence, $separator_sign, $separator_symbol) = @children;
            my $symbol           = $sequence->[1]->[1]->[1]->[1];
            my $quantifier       = $sequence->[2]->[1];
               $separator_sign   = $separator_sign->[1];
               $separator_symbol = $separator_symbol->[1]->[1]->[1]->[1];
            return {
                item => $symbol,
                quantifier => $quantifier,
                separator => $separator_symbol,
                proper => $separator_sign eq '%' ? 1 : 0
            };
        }
        elsif ( $node_id eq 'rhs'){
#            say "$node_id: ", Dumper \@children;
            return map { ast_traverse( $_ ) } @children
        }
        elsif ( $node_id eq 'RH atom'){
#            say "$node_id: ", Dumper \@children;
            return map { ast_traverse( $_ ) } @children
        }
        elsif ( $node_id eq 'action'){
#            say "$node_id: ", Dumper \@children;
            $children[0]->[1] = 'function'; # action becomes function in lua
            my $action = join ' ', map { ast_traverse( $_ ) } @children;
            $action =~ s/\(\s+/(/;  # these will apply to the first occurence
            $action =~ s/\s+\)/)/;  # that is the action parlist
            $action =~ s/\s+,/,/;
            $action =~ s/\)\s+/) /;
            return { action => $action };
        }
        elsif ($node_id eq 'alternative fields'){
            return {
                fields => map { ast_traverse( $_ ) } @children
            }
        }
        elsif ($node_id eq 'field'){
            return $p->fmt($ast); # this is pure lua
        }
        elsif ( $node_id eq 'action parlist'){
#            say "$node_id: ", Dumper \@children;
            return join ' ', map { ast_traverse( $_ ) } @children;
        }
        elsif ( $node_id eq 'block'){
            return $p->fmt($ast); # this is pure lua too
        }
        return ast_traverse( $_ ) for @children;
    }
    else{
#        say "unhandled scalar $ast";
        return $ast;
    }
}

sub bnf2lua {
    my ($ast, $indent, $indent_level) = @_;
#    say "ast:", Dumper $ast;
    # gather data
    my $bnf = ast_traverse($ast);
#    say Dumper $bnf;
    # translate bnf data to lua tables
    my $lhs = $bnf->{lhs};
    my $prioritized_alternatives = $bnf->{rhs}->{"prioritized alternatives"};
#    say "# rule:\nlhs: ", $lhs;
    my $lua_bnf = "bnf_rule_$lhs = {\n";
    # prioritized_alternatives are joined with double bar ||, loosen precedence
    $indent_level++;
    for my $pa ( @{ $prioritized_alternatives } ){
        my @alternatives = $pa->{"prioritized alternative"};
        # alternatives are joined with bar |, same precedence
        for my $alternative (@alternatives){
#            say "alternative:\n", Dumper $alternative;
            for my $rhs (@$alternative){
#                say "rhs:\n", Dumper $rhs;
                # rhs layout
                # [
                #   [ rhs_sym1, rhs_sym2, ..., { fields } ]
                #   or
                #   [ { rhs_as_hash_ref }, { fields } ]
                # ]
                # first extract fields, if any
                my $fields = (pop @$rhs)->{fields} if @$rhs > 1 and ref $rhs->[-1] eq "HASH";
                # then set rhs to its hash ref rhs
                $rhs = $rhs->[0] if ref $rhs->[0] eq "HASH";
                # add array ref rule
                if (ref $rhs eq "ARRAY"){
#                    say "rhs array:\n", Dumper $rhs;
                    $lua_bnf .= $indent x $indent_level . "$lhs = { " .
                        join(', ', map { "'$_'" } @$rhs );
                }
                # add hash ref rule
                elsif (ref $rhs eq "HASH"){
#                    say "rhs hash:\n", Dumper $rhs;
                    # separated sequence
                    if ( exists $rhs->{quantifier} ){
                        my @kv = ();
                        for my $k ( qw{ item quantifier separator proper } ){
                            my $kv = [ $k ];
                            push @$kv, $k eq 'proper' ? $rhs->{$k} : "'$rhs->{$k}'";
                            push @kv, $kv;
                        }
                        $lua_bnf .= $indent x $indent_level . "$lhs = { " .
                            join( ', ', map { "$_->[0] = $_->[1]" } @kv );
#                        say $lua_bnf;
                    }
                    else{
                        warn "bnf2lua: unknown rhs type: " . Dumper $rhs;
                    }
                }
                else{
                    warn "bnf2lua: unknown rhs type $rhs.";
                }
                # add fields, if any
                if (defined $fields){
#                    say "fields: ", Dumper $fields;
                    $lua_bnf .=
                        ",\n" .
                        $indent x $indent_level . "fields = {\n" .
                        $indent x ($indent_level + 1)  .
                        join (
                            ( ",\n" . $indent x ($indent_level + 1) ),
                            map { "$_ = $fields->{$_}" } sort keys %$fields
                        ) .
                    $indent x $indent_level . "}\n";
                }
                # close the table
                $lua_bnf .= $indent x $indent_level . "},\n"
            }
        }
    }
    $indent_level--;
    $lua_bnf .= $indent x $indent_level . "}";
    return $lua_bnf;
}

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
        BNF => \&bnf2lua
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
function lua_bnf_bare ()
  bnf_rule_Script = {
    Script = { item = 'Expression', quantifier = '+', separator = 'comma', proper = 1    },
  }
  bnf_rule_Expression = {
    Expression = { 'Number'    },
    Expression = { 'left_paren', 'Expression', 'right_paren'    },
    Expression = { 'Expression', 'exp', 'Expression'    },
    Expression = { 'Expression', 'mul', 'Expression'    },
    Expression = { 'Expression', 'div', 'Expression'    },
    Expression = { 'Expression', 'add', 'Expression'    },
    Expression = { 'Expression', 'sub', 'Expression'    },
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
function lua_bnf_actions ()
  bnf_rule_Script = {
    Script = { item = 'Expression', quantifier = '+', separator = 'comma', proper = 1    },
  }
  bnf_rule_Expression = {
    Expression = { 'Number'    },
    Expression = { 'left_paren', 'Expression', 'right_paren'    },
    Expression = { 'Expression', 'op_exp', 'Expression',
    fields = {
      action = function (e1, e2) return e1 ^ e2 end    }
    },
    Expression = { 'Expression', 'op_mul', 'Expression',
    fields = {
      action = function (e1, e2) return e1 * e2 end    }
    },
    Expression = { 'Expression', 'op_div', 'Expression',
    fields = {
      action = function (e1, e2) return e1 / e2 end    }
    },
    Expression = { 'Expression', 'op_add', 'Expression',
    fields = {
      action = function (e1, e2) return e1 + e2 end    }
    },
    Expression = { 'Expression', 'op_sub', 'Expression',
    fields = {
      action = function (e1, e2) return e1 - e2 end    }
    },
  }
end
EOS
],
#[ '...', q{...}, q{...} ],
);

for my $test (@tests){
    my ($name, $bnf_extended_lua, $expected_lua_bnf ) = @$test;
    my $ast = $p->parse( $bnf_extended_lua );
    unless (defined $ast){
        fail "Can't parse:\n$bnf_extended_lua";
        next;
    }
#    my $lua_bnf_ast = $p->serialize( $ast );
#    say $lua_bnf_ast;
    my $lua_bnf = $p->fmt( $ast );
#    say $lua_bnf;
    is $lua_bnf, $expected_lua_bnf, $name;
}

done_testing();

