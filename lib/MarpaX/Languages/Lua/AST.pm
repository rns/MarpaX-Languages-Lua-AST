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

    # {a} means 0 or more a's, and [a] means an optional a
    # * -- 0 or more: { ... }
    # ? -- 0 or 1:    [ ... ]

    # keywords and lexemes are symbols in <> having no spaces
    # original rules are commented if converted; what follows is their converted form
    # Capitalized symbols (Name) are from the lua grammar cited above

#    chunk ::= {stat [';']} [laststat [';']]
# e.g. function () end, api.lua:126
    chunk ::=
    chunk ::= statements
    chunk ::= statements laststat
    chunk ::= statements laststat <semicolon>
    chunk ::= laststat <semicolon>
    chunk ::= laststat
#    {stat [';']}
    statements ::= stat
    statements ::= statements stat
    statements ::= statements <semicolon> stat
#   [';'] from {stat [';']}
#   not in line with "There are no empty statements and thus ';;' is not legal"
#   in http://www.lua.org/manual/5.1/manual.html#2.4.1, but api.lua:163
#   doesn't parse without that
#   there is also constructs.lua:58 -- end;
#
#   possible todo: better optional semicolon
    stat ::= <semicolon>

    block ::= chunk

    stat ::= varlist <assignment> explist

    stat ::= functioncall

    stat ::= <do> block <end>
    stat ::= <while> exp <do> block <end>
    stat ::= <repeat> block <until> exp

#    <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |
    stat ::= <if> exp <then> block <end>
    stat ::= <if> exp <then> block <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <end>

#    <for> Name <assignment> exp ',' exp [',' exp] <do> block <end> |
    stat ::= <for> Name <assignment> exp <comma> exp <comma> exp <do> block <end>
    stat ::= <for> Name <assignment> exp <comma> exp <do> block <end>
    stat ::= <for> namelist <in> explist <do> block <end>

    stat ::= <function> funcname funcbody

    stat ::= <local> <function> Name funcbody

#    <local> namelist [<assignment> explist]
    stat ::= <local> namelist <assignment> explist
    stat ::= <local> namelist

    <one or more elseifs> ::= <one elseif>
    <one or more elseifs> ::= <one or more elseifs> <one elseif>
    <one elseif> ::= <elseif> exp <then> block

#    laststat ::= <return> [explist] | <break>
    laststat ::= <return>
    laststat ::= <return> explist
    laststat ::= <break>

#    funcname ::= Name {'.' Name} [':' Name]
    funcname ::= names <colon> Name
    funcname ::= names
#    Names ::= Name+ separator => [\.]
    names ::= Name | names <period> Name

#    varlist ::= var {',' var}
#    varlist ::= var+ separator => [,]
    varlist ::= var | varlist <comma> var

    var ::=  Name | prefixexp <left bracket> exp <right bracket> | prefixexp <period> Name

#    namelist ::= Name {',' Name}
#    namelist ::= Name+ separator => [,]
    namelist ::= Name
    namelist ::= namelist <comma> Name

#    explist ::= {exp ','} exp
#    explist ::= exp+ separator => [,]
    explist ::= exp
    explist ::= explist <comma> exp


    exp ::= <nil>
    exp ::= <false>
    exp ::= <true>
    exp ::= Number
    exp ::= String
    exp ::= <ellipsis>
    exp ::= functionexp
    exp ::= prefixexp
    exp ::= tableconstructor
    exp ::= exp binop exp
    exp ::= unop exp

    prefixexp ::= var
    prefixexp ::= functioncall
    prefixexp ::= <left paren> exp <right paren>

    functioncall ::= prefixexp args
    functioncall ::= prefixexp <colon> Name args

#    args ::=  '(' [explist] ')' | tableconstructor | String
    args ::= <left paren> <right paren>
    args ::= <left paren> explist <right paren>
    args ::= tableconstructor
    args ::= String

    functionexp ::= <function> funcbody

#    funcbody ::= '(' [parlist] ')' block <end>
    funcbody ::= <left paren> parlist <right paren> block <end>
    funcbody ::= <left paren> <right paren> block <end>

#    parlist ::= namelist [',' '...'] | '...'
    parlist ::= namelist
    parlist ::= namelist <comma> <ellipsis>
    parlist ::= <ellipsis>

#    tableconstructor ::= '{' [fieldlist] '}'
    tableconstructor ::= <left curly> fieldlist <right curly>
    tableconstructor ::= <left curly> <right curly>

#    fieldlist ::= field {fieldsep field} [fieldsep]
    fieldlist ::= field
    fieldlist ::= fieldlist fieldsep field
    fieldlist ::= fieldlist fieldsep field fieldsep

    fieldsep ::= <comma>
    fieldsep ::= <semicolon>

    field ::= <left bracket> exp <right bracket> <assignment> exp
    field ::= Name <assignment> exp
    field ::= exp

#   binary operators
    binop ::= <addition>
    binop ::= <minus>
    binop ::= <multiplication>
    binop ::= <division>
    binop ::= <exponentiation>
    binop ::= <percent>
    binop ::= <concatenation>
    binop ::= <less than>
    binop ::= <less or equal>
    binop ::= <greater than>
    binop ::= <greater or equal>
    binop ::= <equality>
    binop ::= <negation>
    binop ::= <and>
    binop ::= <or>

#   unary operators
    unop ::= <minus>
    unop ::= <not>
    unop ::= <length>

#   unicorns
    String ~ unicorn
    Number ~ unicorn
    Name ~ unicorn

    <addition> ~ unicorn
    <and> ~ unicorn
    <assignment> ~ unicorn
    <break> ~ unicorn
    <colon> ~ unicorn
    <comma> ~ unicorn
    <concatenation> ~ unicorn
    <division> ~ unicorn
    <do> ~ unicorn
    <ellipsis> ~ unicorn
    <else> ~ unicorn
    <elseif> ~ unicorn
    <end> ~ unicorn
    <equality> ~ unicorn
    <exponentiation> ~ unicorn
    <false> ~ unicorn
    <for> ~ unicorn
    <function> ~ unicorn
    <greater or equal> ~ unicorn
    <greater than> ~ unicorn
    <if> ~ unicorn
    <in> ~ unicorn
    <left bracket> ~ unicorn
    <left curly> ~ unicorn
    <left paren> ~ unicorn
    <length> ~ unicorn
    <less or equal> ~ unicorn
    <less than> ~ unicorn
    <local> ~ unicorn
    <minus> ~ unicorn
    <multiplication> ~ unicorn
    <negation> ~ unicorn
    <nil> ~ unicorn
    <not> ~ unicorn
    <or> ~ unicorn
    <percent> ~ unicorn
    <period> ~ unicorn
    <repeat> ~ unicorn
    <return> ~ unicorn
    <right bracket> ~ unicorn
    <right curly> ~ unicorn
    <right paren> ~ unicorn
    <semicolon> ~ unicorn
    <then> ~ unicorn
    <true> ~ unicorn
    <until> ~ unicorn
    <while> ~ unicorn

    unicorn ~ [^\s\S]

END_OF_SOURCE
        }
    );
    return $parser;
}

my @terminals = (

    [ 'Comment' => qr/--\[(={4,})\[.*?\]\1\]/xms,   "long nestable comment" ],
    [ 'Comment' => qr/--\[===\[.*?\]===\]/xms,      "long nestable comment" ],
    [ 'Comment' => qr/--\[==\[.*?\]==\]/xms,        "long nestable comment" ],
    [ 'Comment' => qr/--\[=\[.*?\]=\]/xms,          "long nestable comment" ],
    [ 'Comment' => qr/--\[\[.*?\]\]/xms,            "long unnestable comment" ],
    [ 'Comment' => qr/--[^\n]*\n/xms,               "short comment" ],

# 2.1 – Lexical Conventions, refman
# Literal strings can be delimited by matching single or double quotes, and can contain the
# following C-like escape sequences: '\a' (bell), '\b' (backspace), '\f' (form feed), '\n' (
# newline), '\r' (carriage return), '\t' (horizontal tab), '\v' (vertical tab), '\\'
# (backslash), '\"' (quotation mark [double quote]), and '\'' (apostrophe [single quote]).
# Moreover, a backslash followed by a real newline results in a newline in the string. A
# character in a string can also be specified by its numerical value using the escape sequence
# \ddd, where ddd is a sequence of up to three decimal digits. (Note that if a numerical escape
# is to be followed by a digit, it must be expressed using exactly three digits.) Strings in
# Lua can contain any 8-bit value, including embedded zeros, which can be specified as '\0'.

    [ 'String' => qr
        /'(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^']
           )*
         '/xms, "single quoted string" ],

    [ 'String' => qr
        /"(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^"]
           )*
         "/xms, "double quoted string" ],
#'
    [ 'String' => qr/\[\[.*?\]\]/xms,           "long unnestable string" ],
    [ 'String' => qr/\[=\[.*?\]=\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[==\[.*?\]==\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[===\[.*?\]===\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[(={3,})\[.*?\]\1\]/xms,     "long nestable string" ],

# keywords
    [ 'break'       => qr/\bbreak\b/xms,    "break"     ],
    [ 'do'          => qr/\bdo\b/xms,       "do"        ],
    [ 'else'        => qr/\belse\b/xms,     "else"      ],
    [ 'elseif'      => qr/\belseif\b/xms,   "elseif"    ],
    [ 'end'         => qr/\bend\b/xms,      "end"       ],
    [ 'false'       => qr/\bfalse\b/xms,    "false"     ],
    [ 'for'         => qr/\bfor\b/xms,      "for"       ],
    [ 'function'    => qr/\bfunction\b/xms, "function"  ],
    [ 'if'          => qr/\bif\b/xms,       "if"        ],
    [ 'in'          => qr/\bin\b/xms,       "in"        ],
    [ 'local'       => qr/\blocal\b/xms,    "local"     ],
    [ 'nil'         => qr/\bnil\b/xms,      "nil"       ],
    [ 'repeat'      => qr/\brepeat\b/xms,   "repeat"    ],
    [ 'return'      => qr/\breturn\b/xms,   "return"    ],
    [ 'then'        => qr/\bthen\b/xms,     "then"      ],
    [ 'true'        => qr/\btrue\b/xms,     "true"      ],
    [ 'until'       => qr/\buntil\b/xms,    "until"     ],
    [ 'while'       => qr/\bwhile\b/xms,    "while"     ],

    [ 'not'                 => qr/\bnot\b/xms,  "not"   ],
    [ 'or'                  => qr/\bor\b/xms,   "or"    ],
    [ 'and'                 => qr/\band\b/xms,  "and"   ],

#   Name
    [ 'Name'        => qr/\b[a-zA-Z_][\w]*\b/xms, "Name" ],

#   Number
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
#   todo: check if this is ensured
    [ 'Number' => qr/[0-9]+\.?[0-9]+([eE][-+]?[0-9]+)?/xms, "Floating-point number" ],
    [ 'Number' => qr/[0-9]+[eE][-+]?[0-9]+/xms, "Floating-point number" ],
    [ 'Number' => qr/[0-9]+\./xms, "Floating-point number" ],
    [ 'Number' => qr/\.[0-9]+/xms, "Floating-point number" ],
    [ 'Number' => qr/0x[0-9a-fA-F]+/xms, "Hexadecimal number" ],
    [ 'Number' => qr/[\d]+/xms, "Integer number" ],

#   operators

    [ 'ellipsis'            => qr/\.\.\./xms,   "ellipsis"          ],

    [ 'less or equal'       => qr/<=/xms,       "less or equal"     ],
    [ 'greater or equal'    => qr/>=/xms,       "greater or equal"  ],
    [ 'negation'            => qr/~=/xms,       "negation"          ],
    [ 'equality'            => qr/==/xms,       "equality"          ],
    [ 'concatenation'       => qr/\.\./xms,     "concatenation"     ],
    [ 'less than'           => qr/</xms,        "less than"         ],
    [ 'greater than'        => qr/>/xms,        "greater than"      ],
    [ 'addition'            => qr/\+/xms,       "addition"          ],
    [ 'minus'               => qr/-/xms,        "minus"             ],
    [ 'multiplication'      => qr/\*/xms,       "multiplication"    ],
    [ 'division'            => qr/\//xms,       "division"          ],
    [ 'percent'             => qr/%/xms,        "percent"           ],
    [ 'length'              => qr/\#/xms,       "length"            ],
    [ 'exponentiation'      => qr/\^/xms,       "exponentiation"    ],

#   punctuation
    [ 'colon'               => qr/:/xms,        "colon"             ],
    [ 'left bracket'        => qr/\[/xms,       "left bracket"      ],
    [ 'right bracket'       => qr/\]/xms,       "right bracket"     ],
    [ 'left paren'          => qr/\(/xms,       "left paren"        ],
    [ 'right paren'         => qr/\)/xms,       "right paren"       ],
    [ 'left curly'          => qr/\{/xms,       "left curly"        ],
    [ 'right curly'         => qr/\}/xms,       "right curly"       ],
    [ 'assignment'          => qr/=/xms,        "assignment"        ],
    [ 'semicolon'           => qr/;/xms,        "semicolon"         ],
    [ 'comma'               => qr/,/xms,        "comma"             ],
    [ 'period'              => qr/\./xms,       "period"            ],

);

sub read{
    my ($self, $recce, $string) = @_;

    $recce->read( \$string, 0, 0 );

    my $length = length $string;
    pos $string = 0;
    TOKEN: while (1) {
        my $start_of_lexeme = pos $string;
        last TOKEN if $start_of_lexeme >= $length;
        next TOKEN if $string =~ m/\G\s+/gcxms;     # skip whitespace
#        warn "# matching at $start_of_lexeme:\n", substr( $string, $start_of_lexeme, 40 );
        TOKEN_TYPE: for my $t (@terminals) {
            my ( $token_name, $regex, $long_name ) = @{$t};
            next TOKEN_TYPE if not $string =~ m/\G($regex)/gcxms;
            my $lexeme = $1;

            next TOKEN if $token_name =~ /comment/i; # skip comments

#            warn "# $token_name:\n$lexeme";

            if ( not defined $recce->lexeme_alternative($token_name) ) {
                warn
                    qq{Parser rejected token "$long_name" at position $start_of_lexeme, before "},
                    substr( $string, $start_of_lexeme, 40 ), q{"};
                return
            }
            next TOKEN
                if $recce->lexeme_complete( $start_of_lexeme,
                        ( length $lexeme ) );

        } ## end TOKEN_TYPE: for my $t (@terminals)
        warn qq{No token found at position $start_of_lexeme, before "},
            substr( $string, pos $string, 40 ), q{"};
        return
    } ## end TOKEN: while (1)
    # return ast or undef on parse failure
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        warn "No parse was found, after reading the entire input.\n";
        warn $recce->show_progress();
        return
    }
    return ${$value_ref};
}

sub parse {
    my ( $parser, $source ) = @_;
    my $recce = Marpa::R2::Scanless::R->new( { grammar => $parser->{grammar} } );
    return $parser->read($recce, $source);
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
        $tokens .= join q{}, grep { defined } map { $parser->tokens( $_ ) } @children;
    }
    else{
        my $separator = ' ';
        if ( # no spaces before and after ' and "
               defined $tokens and $tokens =~ m{['"\[]$} #'
            or defined $ast    and $ast    =~ m{^['"\]]} #'
        ){
            $separator = '';
        }
        if (defined $ast and $ast =~ /^function|while|repeat|do|if|else|elseif|for|local$/){
            $separator = "\n";
        }
        $tokens .= $separator . $ast if defined $ast;
        $tokens .= "\n" if defined $ast and $ast eq 'end';
    }
    return $tokens;
}
1;
