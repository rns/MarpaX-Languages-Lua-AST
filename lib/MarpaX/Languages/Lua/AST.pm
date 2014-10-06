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
    # ? -- 0 or 1:    [ ... ]
    # keywords are in <>'s
    # original rules are commented if converted; what follows is their converted form

#    chunk ::= {stat [';']} [laststat [';']]
    chunk ::= stats laststat optional_semicolon_or_newline
    chunk ::= stats
    stats ::= stat+ separator => optional_semicolon_or_newline

    optional_semicolon_or_newline ~ optional_semicolon [\n]
    optional_semicolon_or_newline ~ [\n]
    optional_semicolon ~ ';'
    optional_semicolon ~

    block ::= chunk

    stat ::=  varlist '=' explist |

        functioncall |

        <do> block <end> |

        <while> exp <do> block <end> |

        <repeat> block <until> exp |

#        <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |
        <if> exp <then> block elseifs <else> block <end> |
        <if> exp <then> block elseifs <end> |

#        <for> Name '=' exp ',' exp [',' exp] <do> block <end> |
        <for> Name '=' exp ',' exp [',' exp] <do> block <end> |

        <for> namelist <in> explist <do> block <end> |

        <function> funcname funcbody |

        <local> <function> Name funcbody |

#        <local> namelist ['=' explist]
        <local> namelist '=' explist |
        <local> namelist |
        comment

    elseifs ::= elseif_item*
    elseif_item ::= <elseif> exp <then> block

#    laststat ::= <return> [explist] | <break>
    laststat ::= <return> | <return> explist | <break>

#    funcname ::= Name {'.' Name} [':' Name]
    funcname ::= Names ':' Name
    funcname ::= Names
    Names ::= Name+ separator => [\.]

#    varlist ::= var {',' var}
    varlist ::= var+ separator => [,]

    var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name

#    namelist ::= Name {',' Name}
    namelist ::= Name+ separator => [,]

#    explist ::= {exp ','} exp
    explist ::= exp+ separator => [,]

    exp ::=  <nil> | <false> | <true> | Number | String | '...' | function_exp |
         prefixexp | tableconstructor | exp binop exp | unop exp

    prefixexp ::= var | functioncall | '(' exp ')'

    functioncall ::=  prefixexp args | prefixexp ':' Name args

#    args ::=  '(' [explist] ')' | tableconstructor | String
    args ::=  '(' ')' | '(' explist ')' | tableconstructor | String

    function_exp ::= <function> funcbody

#    funcbody ::= '(' [parlist] ')' block <end>
    funcbody ::= '(' parlist ')' block <end>
    funcbody ::= '(' ')' block <end>

#    parlist ::= namelist [',' '...'] | '...'
    parlist ::= namelist ',' '...' | '...'
    parlist ::= namelist | '...'

#    tableconstructor ::= '{' [fieldlist] '}'
    tableconstructor ::= '{' fieldlist '}'
    tableconstructor ::= '{' '}'

#    fieldlist ::= field {fieldsep field} [fieldsep]
    fieldlist ::= fields fieldsep
    fieldlist ::= fields

    fields ::= field+ separator => fieldsep

    field ::= '[' exp ']' '=' exp | Name '=' exp | exp

    fieldsep ~ ',' | ';'

    binop ~ '+' | '-' | '*' | '/' | '^' | '%' | '..' |
         '<' | '<=' | '>' | '>=' | '==' | '~=' |
         <and> | <or>

    unop ~ '-' | <not> | '#'

# comments
    comment ~ '--' comment_chars [\n]
    comment ~ '--' [\n]
    comment_chars ~ comment_char+
    comment_char ~ [^\n]+

#   lexemes
    Name ~ [\w]+
    # 3   3.0   3.1416   314.16e-2   0.31416E1   0xff   0x56
    Number ~ [\d+]
    Number ~ [\d+] '.' [\d+]

    String ~ '"' double_quoted_String_chars '"'
    double_quoted_String_chars ~ double_quoted_String_char*
    double_quoted_String_char ~ [^"] #"
    String ~ ['] single_suoted_String_chars [']
    single_suoted_String_chars ~ single_suoted_String_char*
    single_suoted_String_char ~ [^'] #'

# keywords
    <and> ~ 'and'
    <break> ~ 'break'
    <do> ~ 'do'
    <else> ~ 'else'
    <elseif> ~ 'elseif'
    <end> ~ 'end'
    <false> ~ 'false'
    <for> ~ 'for'
    <function> ~ 'function'
    <if> ~ 'if'
    <in> ~ 'in'
    <local> ~ 'local'
    <nil> ~ 'nil'
    <not> ~ 'not'
    <or>  ~ 'or'
    <repeat> ~ 'repeat'
    <return> ~ 'return'
    <then> ~ 'then'
    <true> ~ 'true'
    <until> ~ 'until'
    <while> ~ 'while'

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
        }
    );

    return $parser;
}

sub parse {
    my ( $parser, $source ) = @_;

    my $r = Marpa::R2::Scanless::R->new( {
        grammar => $parser->{grammar},
        trace_terminals => 99,
    });
    $r->read( \$source );
    my $ast = ${ $r->value() };
    return $ast;
} ## end sub parse

sub serialize{
    my ($parser) = @_;

}

1;
