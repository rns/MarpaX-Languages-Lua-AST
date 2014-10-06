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

    $parser->{grammar} = Marpa::R2::Scanless::G->new( { source         => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    # source: 8 – The Complete Syntax of Lua Lua 5.1 Reference Manual, http://www.lua.org/manual/5.1/manual.html
    # discussion on #marpa -- http://irclog.perlgeek.de/marpa/2014-10-06#i_9463520
    # * -- 0 or more: { ... }
    # + -- 1 or more: [ ... ]
    # keywords are in <>'s

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

#    laststat ::= <return> [explist] | <break>
    laststat ::= <return> [explist] | <break>

#    funcname ::= Name {'.' Name} [':' Name]
    funcname ::= Name {'.' Name} [':' Name]

#    varlist ::= var {',' var}
    varlist ::= var {',' var}

    var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name

#    namelist ::= Name {',' Name}
    namelist ::= Name {',' Name}

#    explist ::= {exp ','} exp
    explist ::= {exp ','} exp

    exp ::=  <nil> | <false> | <true> | Number | String | '...' | function |
         prefixexp | tableconstructor | exp binop exp | unop exp

    prefixexp ::= var | functioncall | '(' exp ')'

    functioncall ::=  prefixexp args | prefixexp ':' Name args

#    args ::=  '(' [explist] ')' | tableconstructor | String
    args ::=  '(' [explist] ')' | tableconstructor | String

    function ::= <function> funcbody

#    funcbody ::= '(' [parlist] ')' block <end>
    funcbody ::= '(' [parlist] ')' block <end>

#    parlist ::= namelist [',' '...'] | '...'
    parlist ::= namelist [',' '...'] | '...'

#    tableconstructor ::= '{' [fieldlist] '}'
    tableconstructor ::= '{' [fieldlist] '}'

#    fieldlist ::= field {fieldsep field} [fieldsep]
    fieldlist ::= field {fieldsep field} [fieldsep]

#    field ::= '[' exp ']' '=' exp | Name '=' exp | exp
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
    my ( $parser, $source ) = @_;

    my $r = Marpa::R2::Scanless::R->new( {
        grammar => $parser->{grammar},
        trace_terminals => 1,
    });
    $r->read( \$source );
    my $ast = ${ $r->value() };
    return $ast;
} ## end sub parse

sub serialize{
    my ($parser) = @_;

}

1;
