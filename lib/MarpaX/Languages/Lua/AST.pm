#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

# Lua 5.1 Parser in barebones (no priotitized rules, external scanning) SLIF

package MarpaX::Languages::Lua::AST;

use 5.010;
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Deepcopy = 1;

use Marpa::R2;

sub new {

    my ($class) = @_;

    my $parser = bless {}, $class;

    $parser->{grammar} = Marpa::R2::Scanless::G->new( { source         => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, values ]
lexeme default = action => [ name, value ] latm => 1

    # source: 8 – The Complete Syntax of Lua Lua 5.1 Reference Manual, http://www.lua.org/manual/5.1/manual.html
    # discussion on #marpa -- http://irclog.perlgeek.de/marpa/2014-10-06#i_9463520
    # * -- 0 or more: { ... }
    # ? -- 0 or 1:    [ ... ]
    # keywords are in <>'s
    # original rules are commented if converted; what follows is their converted form

#    chunk ::= {stat [';']} [laststat [';']]
    chunk ::= stats laststat
    chunk ::= laststat ';'
    chunk ::= laststat
    chunk ::= stats
    stats ::= stat+ separator => semicolon_or_newlines

    semicolon_or_newlines ~ ';' newlines
    semicolon_or_newlines ~ newlines
    newlines ~ [\n]+

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
        <local> namelist

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
    parlist ::= namelist | namelist ',' '...' | '...'

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
    comment ~ '--' comment_chars
    comment_chars ~ comment_char+
    comment_char ~ [^\n]+

#   lexemes
    Name ~ [a-zA-Z_] Name_chars
    Name_chars ~ [\w]*
    # 3   3.0   3.1416
    # todo: 314.16e-2   0.31416E1   0xff   0x56
    Number ~ int | float
    int ~ [\d]+
    float ~ int '.' int

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

:discard ~ comment
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
#        trace_terminals => 99,
    });
    eval {$r->read(\$source)} || warn "Parse failure, progress report is:\n" . $r->show_progress;
    my $ast = ${ $r->value() };
    say Dumper $ast;
    return $ast;
} ## end sub parse

sub serialize{
    my ($parser, $ast) = @_;
    state $depth++;
    my $s;
    my $indent = "  " x ($depth - 1);
    if (ref $ast){
        my ($node_id, @children) = @$ast;
        if (@children == 1 and not ref $children[0]){
            $s .= $indent . "$node_id '$children[0]'" . "\n";
        }
        else{
            $s .= $indent . "$node_id\n";
            $s .= join '', map { $parser->serialize( $_ ) } @children;
        }
    }
    else{
        $s .= $indent . "'$ast'"  . "\n";
    }
    $depth--;
    return $s;
}


1;
