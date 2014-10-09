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

    # source: 8 – The Complete Syntax of Lua, Lua 5.1 Reference Manual
    # discussion on #marpa -- http://irclog.perlgeek.de/marpa/2014-10-06#i_9463520
    #    -- http://www.lua.org/manual/5.1/manual.html
    # The Lua Book -- http://www.lua.org/pil/contents.html
    # More parser tests: http://lua-users.org/wiki/LuaGrammar

    # * -- 0 or more: { ... }
    # ? -- 0 or 1:    [ ... ]

    # keywords are symbols in <> having no spaces
    # original rules are commented if converted; what follows is their converted form
    # Capitalized symbols (Name) are from the lua grammar cited above

#    chunk ::= {stat [';']} [laststat [';']]
    chunk ::=               # e.g. function () end, api.lua:126
    chunk ::= stats
    chunk ::= stats laststat
    chunk ::= laststat ';'
    chunk ::= laststat
    stats ::= stat | stats stat | stats ';' stat

    block ::= chunk

    stat ::=  varlist <eq> explist |

        functioncall |

        <do> block <end> |

        <while> exp <do> block <end> |

        <repeat> block <until> exp |

#        <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |
        <if> exp <then> block elseifs <else> block <end> |
        <if> exp <then> block elseifs <end> |

#        <for> Name <eq> exp ',' exp [',' exp] <do> block <end> |
        <for> Name <eq> exp ',' exp [',' exp] <do> block <end> |

        <for> namelist <in> explist <do> block <end> |

        <function> funcname funcbody |

        <local> <function> Name funcbody |

#        <local> namelist [<eq> explist]
        <local> namelist <eq> explist |
        <local> namelist

    elseifs ::= elseif_item*
    elseif_item ::= <elseif> exp <then> block

#    laststat ::= <return> [explist] | <break>
    laststat ::= <return> | <return> explist | <break>

#    funcname ::= Name {'.' Name} [':' Name]
    funcname ::= names ':' Name
    funcname ::= names
#    Names ::= Name+ separator => [\.]
    names ::= Name | names '.' Name

#    varlist ::= var {',' var}
#    varlist ::= var+ separator => [,]
    varlist ::= var | varlist ',' var

    var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name

#    namelist ::= Name {',' Name}
#    namelist ::= Name+ separator => [,]
    namelist ::= Name | namelist ',' Name

#    explist ::= {exp ','} exp
#    explist ::= exp+ separator => [,]
   explist ::= exp | explist ',' exp


    exp ::=  <nil> | <false> | <true> | Number | String | '...' | functionexp |
         prefixexp | tableconstructor | exp binop exp | unop exp

    prefixexp ::= var | functioncall | '(' exp ')'

    functioncall ::=  prefixexp args | prefixexp ':' Name args

#    args ::=  '(' [explist] ')' | tableconstructor | String
    args ::=  '(' ')' | '(' explist ')' | tableconstructor | String

    functionexp ::= <function> funcbody

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

#    fields ::= field+ separator => fieldsep
    fields ::= field | fields fieldsep field
    fieldsep ~ ',' | ';'

    field ::= '[' exp ']' <eq> exp | Name <eq> exp | exp


    binop ~ '+' | '-' | '*' | '/' | '^' | '%' | '..' |
         '<' | '<=' | '>' | '>=' | '==' | '~=' |
         <and> | <or>

    unop ~ '-' | <not> | '#'

#   comments
    comment ~ <short comment>
    comment ~ <long comment>

    <short comment> ~ '--' <short comment chars>
    <short comment chars> ~ [^\n]*

#   todo: nestable long comments -- see nestable long strings
#   The long string/long comment syntax ([[string]]) does not allow nesting. -- refman 7.1
    <long comment> ~ <long unnestable comment>
    <long comment> ~ <long nestable comment>
    <long unnestable comment> ~ '--' <long unnestable string>
    <long nestable comment> ~ '--' <long nestable string>

#   identifier
    Name ~ [a-zA-Z_] <Name chars>
    <Name chars> ~ [\w]*

#   numbers
#   todo: more realistic numbers
    Number ~ int
    Number ~ float
    Number ~ hex

    int   ~ [\d]+
    float ~ int '.' int
    float ~ int '.' int 'e' [+-] int
    float ~ int '.' int 'E' int
    hex ~ '0x' <hex chars>
    <hex chars> ~ [A-Fa-f0-9] [A-Fa-f0-9]

#   long strings in long brackets (LB) [[ ]] with ='s
#   todo: long strings can be nested with [=[ ... ]=]
#         and cannot be nested with [[ .. ]] -- http://lua-users.org/wiki/StringsTutorial
#         as external lexing will eventually be used, they are postponed until then
#    <opening non-nesting long bracket> ~ '[['
#    <closing non-nesting long bracket> ~ '[['
#    <opening long bracket> ~ '[' <equal signs> '['
#    <equal signs> ~ [=]+
    String ~ <long string>

    <long string> ~ <long unnestable string>
    <long string> ~ <long nestable string>

    <long unnestable string> ~ '[[' <long unnestable string characters> ']]'
    <long unnestable string characters> ~ <long unnestable string character>
    <long unnestable string character> ~ [^\]]*
#   this is not really nestable; nesting will be handled by external lexing
    <long nestable string> ~ '[=[' <long nestable string characters> ']=]'
    <long nestable string> ~ '[==[' <long nestable string characters> ']==]'
    <long nestable string> ~ '[===[' <long nestable string characters> ']===]'
    <long nestable string> ~ '[====[' <long nestable string characters> ']====]'
    <long nestable string characters> ~ <long nestable string character>*
    <long nestable string character> ~ [^\]]

    String ~ '"' <double quoted String chars> '"'
    <double quoted String chars> ~ <double quoted String char>*
    <double quoted String char> ~ [^"] | '\"' | '\\' # "

    String ~ ['] <single quoted String chars> [']
    <single quoted String chars> ~ <single quoted String char>*
    <single quoted String char> ~ [^'] | '\' ['] | '\\' #'

# keywords
    <and>       ~ 'and'
    <break>     ~ 'break'
    <do>        ~ 'do'
    <else>      ~ 'else'
    <elseif>    ~ 'elseif'
    <end>       ~ 'end'
    <false>     ~ 'false'
    <for>       ~ 'for'
    <function>  ~ 'function'
    <if>        ~ 'if'
    <in>        ~ 'in'
    <local>     ~ 'local'
    <nil>       ~ 'nil'
    <not>       ~ 'not'
    <or>        ~ 'or'
    <repeat>    ~ 'repeat'
    <return>    ~ 'return'
    <then>      ~ 'then'
    <true>      ~ 'true'
    <until>     ~ 'until'
    <while>     ~ 'while'

# other tokens
# todo: use them instead of to rpepare for external lexing
    <eq> ~ '='

:discard ~ comment
:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
        }
    );

    return $parser;
}

sub parse {
    my ( $parser, $source, $recce_opts, $parse_opts ) = @_;

    my %default_recce_opts = (
        grammar => $parser->{grammar},
        trace_terminals => 0,
    );

    # merge recognizer options passed by the caller, if any
    if (defined $recce_opts and ref $recce_opts eq "HASH"){
        @default_recce_opts{keys %$recce_opts} = values %$recce_opts;
    }

    # parse showing progress on failure if so requested in $parse_opts
    my $r = Marpa::R2::Scanless::R->new( \%default_recce_opts );
    eval { $r->read(\$source) };
    if ( defined $parse_opts and $parse_opts->{show_progress} ){
        warn "$@Progress report is:\n" . $r->show_progress;
    }

    # return ast or undef on parse failure
    my $v = $r->value();
    return unless defined $v;
    return ${ $v };

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

# quick hack to test against Inline::Lua:
# serialize $ast to a stream of tokens separated with a space
sub tokens{
    my ($parser, $ast) = @_;
    my $tokens;
    if (ref $ast){
        my ($node_id, @children) = @$ast;
        $tokens .= join q{}, map { $parser->tokens( $_ ) } @children;
    }
    else{
        my $separator = ' ';
        if ( # no spaces before and after ' and "
               defined $tokens and $tokens =~ m{['"\[]$} #'
            or defined $ast    and $ast    =~ m{^['"\]]} #'
        ){
            $separator = '';
        }
        $tokens .= $separator . $ast;
    }
    return $tokens;
}
1;
