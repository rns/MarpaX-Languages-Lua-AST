#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

# Lua 5.1 Parser in barebones (no priotitized rules, external scanning) SLIF

package MarpaX::Languages::Lua::AST;

use 5.010;
use strict;
use warnings;

use Marpa::R2;

sub new {

    my ($class) = @_;

    my $parser = bless {}, $class;

    $parser->{grammar} = Marpa::R2::Scanless::G->new(
        {
            source         => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    # source: 8 – The Complete Syntax of Lua Lua 5.1 Reference Manual, http://www.lua.org/manual/5.1/manual.html
    # * -- 0 or more: { ... }
    # + -- 1 or more: [ ... ]
#    chunk ::= {stat [';']} [laststat [';']]
    chunk ::= {stat [';']} [laststat [';']]

    block ::= chunk

    stat ::=  varlist '=' explist |
         functioncall |
         <do> block <end> |
         <while> exp <do> block <end> |
         <repeat> block <until> exp |

#         <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |
         <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |

#         <for> Name '=' exp ',' exp [',' exp] <do> block <end> |
         <for> Name '=' exp ',' exp [',' exp] <do> block <end> |

         <for> namelist <in> explist <do> block <end> |
         <function> funcname funcbody |
         <local> <function> Name funcbody |

#         <local> namelist ['=' explist]
         <local> namelist ['=' explist]

    laststat ::= <return> [explist] | <break>

    funcname ::= Name {'.' Name} [':' Name]

    varlist ::= var {',' var}

    var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name

    namelist ::= Name {',' Name}

    explist ::= {exp ','} exp

    exp ::=  <nil> | <false> | <true> | Number | String | '...' | function |
         prefixexp | tableconstructor | exp binop exp | unop exp

    prefixexp ::= var | functioncall | '(' exp ')'

    functioncall ::=  prefixexp args | prefixexp ':' Name args

    args ::=  '(' [explist] ')' | tableconstructor | String

    function ::= <function> funcbody

    funcbody ::= '(' [parlist] ')' block <end>

    parlist ::= namelist [',' '...'] | '...'

    tableconstructor ::= '{' [fieldlist] '}'

    fieldlist ::= field {fieldsep field} [fieldsep]

    field ::= '[' exp ']' '=' exp | Name '=' exp | exp

    fieldsep ::= ',' | ';'

    binop ::= '+' | '-' | '*' | '/' | '^' | '%' | '..' |
         '<' | '<=' | '>' | '>=' | '==' | '~=' |
         <and> | <or>

    unop ::= '-' | <not> | '#'

END_OF_SOURCE
        }
    );

    return $parser;
}

sub parse {
    my ( $parser, $string ) = @_;

    my $re = Marpa::R2::Scanless::R->new(
        {   grammar           => $parser->{grammar},
        }
    );
    $re->read( \$string );
    my $ast = ${ $re->value() };
} ## end sub parse


1;
