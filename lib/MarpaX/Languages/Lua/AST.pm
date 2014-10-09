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

# G1 Lexemes
# ==========

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

#   numbers todo: more realistic numbers
    Number ::= int
    Number ::= float
    Number ::= hex

#   identifier
    Name ::= <name>

#   String
#    String ::= <single quoted string>
#    String ::= <double quoted string>
#    String ::= <long unnestable string>
#    String ::= <long nestable string>

    String ~ unicorn
    <greater or equal> ~ unicorn
    <percent> ~ unicorn
#    <double quoted string> ~ unicorn
#    <single quoted string> ~ unicorn
    <not> ~ unicorn
    <less or equal> ~ unicorn
    <name> ~ unicorn
    <and> ~ unicorn
    <int> ~ unicorn
    <division> ~ unicorn
    <float> ~ unicorn
#    <long unnestable string> ~ unicorn
    <length> ~ unicorn
    <or> ~ unicorn
    <exponentiation> ~ unicorn
    <greater than> ~ unicorn
    <multiplication> ~ unicorn
    <addition> ~ unicorn
    <less than> ~ unicorn
    <hex> ~ unicorn
#    <long nestable string> ~ unicorn
    <equality> ~ unicorn
    <concatenation> ~ unicorn
    <minus> ~ unicorn
    <negation> ~ unicorn
    <semicolon> ~ unicorn
    <if> ~ unicorn
    <break> ~ unicorn
    <period> ~ unicorn
    <comma> ~ unicorn
    <colon> ~ unicorn
    <repeat> ~ unicorn
    <function> ~ unicorn
    <left curly> ~ unicorn
    <do> ~ unicorn
    <true> ~ unicorn
    <local> ~ unicorn
    <left bracket> ~ unicorn
    <then> ~ unicorn
    <ellipsis> ~ unicorn
    <false> ~ unicorn
    <in> ~ unicorn
    <nil> ~ unicorn
    <assignment> ~ unicorn
    <for> ~ unicorn
    <else> ~ unicorn
    <right bracket> ~ unicorn
    <left paren> ~ unicorn
    <end> ~ unicorn
    <right curly> ~ unicorn
    <elseif> ~ unicorn
    <right paren> ~ unicorn
    <return> ~ unicorn
    <until> ~ unicorn
    <while> ~ unicorn

    unicorn ~ [^\s\S]

END_OF_SOURCE
        }
    );

my $tokens = q{
# ===>============ cut here after external lexer is implemented =====>======
# Tokens
# ======
# Lexeme name are shown in comments before their token groups
# External lexing starts here
# tokens sorted longest possible to shortest possible

#   long nestable comment/string
    <long nestable comment> ~ <comment start> <long nestable string>

#   strings -- long string, double and single quoted, with escaping
    <long nestable string> ~ '[=[' <long nestable string characters> ']=]'
    <long nestable string> ~ '[==[' <long nestable string characters> ']==]'
    <long nestable string> ~ '[===[' <long nestable string characters> ']===]'
    <long nestable string> ~ '[====[' <long nestable string characters> ']====]'
    <long nestable string characters> ~ <long nestable string character>*
    <long nestable string character> ~ [^\]]

#   long unnestable comment/string
    <long unnestable comment> ~ <comment start> <long unnestable string>

    <long unnestable string> ~ '[[' <long unnestable string characters> ']]'
    <long unnestable string characters> ~ <long unnestable string character>
    <long unnestable string character> ~ [^\]]*

#   double and single quoted
    <double quoted string> ~ <double quote> <double quoted string chars> <double quote>
    <double quoted string chars> ~ <double quoted string char>*
    <double quoted string char> ~ [^"] | '\"' | '\\' # "

    <single quoted string> ~ <single quote> <single quoted string chars> <single quote>
    <single quoted string chars> ~ <single quoted string char>*
    <single quoted string char> ~ [^'] | '\' ['] | '\\' #'

    <double quote> ~ '"'
    <single quote> ~ ['] #'

#   short comments
    <short comment> ~ <comment start> <short comment chars>
    <short comment chars> ~ [^\n]*

#   Name
    <name> ~ [a-zA-Z_] <Name chars>
    <Name chars> ~ [\w]*

# keywords
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
    <repeat>    ~ 'repeat'
    <return>    ~ 'return'
    <then>      ~ 'then'
    <true>      ~ 'true'
    <until>     ~ 'until'
    <while>     ~ 'while'

#   Number
    int   ~ [\d]+
    hex ~ '0x' [A-Fa-f0-9] [A-Fa-f0-9]
    float ~ <integer part> [\.]
    float ~ <integer part> <fractional part>
    float ~ <fractional part>
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
    float ~ <fractional part> <exponent> <plus or minus> int
    float ~ <integer part> <fractional part> <exponent> <plus or minus> int
    float ~ <integer part> <exponent> <plus or minus> int
    float ~ <integer part> <fractional part> <exponent> int
    float ~ <fractional part> <exponent> int
    float ~ <integer part> <exponent> int

    <integer part>      ~ int
    <fractional part>   ~ [\.] int
    <plus or minus>     ~ [+-]
    <exponent>          ~ [eE]

# operators from lower to higher priority as per refman 2.5.6

    <or>                ~ 'or'
    <and>               ~ 'and'
    <less than>         ~ '<'
    <less or equal>     ~ '<='
    <greater than>      ~ '>'
    <greater or equal>  ~ '>='
    <negation>          ~ '~='
    <equality>          ~ '=='
    <concatenation>     ~ '..'
    <addition>          ~ '+'
    <minus>             ~ '-'
    <multiplication>    ~ '*'
    <division>          ~ '/'
    <percent>           ~ '%'
    <not>               ~ 'not'
    <length>            ~ '#'
    <exponentiation>    ~ '^'

#   punctuation
    <colon>             ~ ':'
    <left bracket>      ~ '['
    <right bracket>     ~ ']'
    <ellipsis>          ~ '...'
    <left paren>        ~ '('
    <right paren>       ~ ')'
    <left curly>        ~ '{'
    <right curly>       ~ '}'
    <comment start>     ~ '--'
    <assignment>        ~ '='
    <semicolon>         ~ ';'
    <comma>             ~ ','
    <period>            ~ '.'

:discard ~ Comment
:discard ~ whitespace
whitespace ~ [\s]+
};

#   show L0 rules
#    warn $parser->{grammar}->show_symbols(1, 'L0');
    return $parser;
}

sub read{
    my ($self, $recce, $string) = @_;

my @terminals = (
#    [ Number   => qr/\d+/xms,    "Number" ],
#    [ 'op pow' => qr/[\^]/xms,   'Exponentiation operator' ],
#    [ 'op pow' => qr/[*][*]/xms, 'Exponentiation' ],          # order matters!
#    [ 'op times' => qr/[*]/xms, 'Multiplication operator' ],  # order matters!
#    [ 'op divide'   => qr/[\/]/xms, 'Division operator' ],
#    [ 'op add'      => qr/[+]/xms,  'Addition operator' ],
#    [ 'op subtract' => qr/[-]/xms,  'Subtraction operator' ],
#    [ 'op lparen'   => qr/[(]/xms,  'Left parenthesis' ],
#    [ 'op rparen'   => qr/[)]/xms,  'Right parenthesis' ],
#    [ 'op comma'    => qr/[,]/xms,  'Comma operator' ],

#   long nestable comment/string
#    <long nestable comment> ~ <comment start> <long nestable string>
    [ 'long nestable comment' => qr/--\[(=*)\[.*?\]\1\]/xms, "long nestable comment" ],

#   strings -- long string, double and single quoted, _with escaping_
    [ 'String' => qr/\[(=*)\[.*?\]\1\]/xms, "long nestable string" ],
#    <long nestable string> ~ '[==[' <long nestable string characters> ']==]'
#    <long nestable string> ~ '[===[' <long nestable string characters> ']===]'
#    <long nestable string> ~ '[====[' <long nestable string characters> ']====]'
#    <long nestable string characters> ~ <long nestable string character>*
#    <long nestable string character> ~ [^\]]

#   long unnestable comment/string
#    <long unnestable comment> ~ <comment start> <long unnestable string>
    [ 'long unnestable comment' => qr/--\[\[.*?\]\]/xms, "long unnestable comment" ],

#    <long unnestable string> ~ '[[' <long unnestable string characters> ']]'
    [ 'String' => qr/\[\[.*?\]\]/xms, "long unnestable string" ],
#    <long unnestable string characters> ~ <long unnestable string character>
#    <long unnestable string character> ~ [^\]]*

#   double and single quoted
    [ 'String' => qr/"(?>(?:(?>[^"\\]+)|\\.)*)"/xms, "double quoted string" ], #"
#    <double quoted string chars> ~ <double quoted string char>*
#    <double quoted string char> ~ [^"] | '\"' | '\\' # "

    [ 'String' => qr/'(?>(?:(?>[^'\\]+)|\\.)*)'/xms, "single quoted string" ], #'
#    <single quoted string chars> ~ <single quoted string char>*
#    <single quoted string char> ~ [^'] | '\' ['] | '\\' #'

#    <double quote> ~ '"'
#    <single quote> ~ ['] #'

#   short comments
    [ 'Comment' => qr/--[^\n]*\n/xms, "Comment" ],

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

#   Name
    [ 'name'        => qr/\b[a-zA-Z_][\w]*\b/xms, "name" ],

#   Number
    [ 'int' => qr/[\d]+/xms, "Integer number" ],
    [ 'hex' => qr/0[x][0-9a-fA-F]+/xms, "Hexadecimal number" ],
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
#   todo: check if this is ensured
    [ 'float' => qr/[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?/xms, "Floating-point number" ],

#    float ~ <integer part> <fractional part>
#    float ~ <fractional part>
#    float ~ <fractional part> <exponent> <plus or minus> int
#    float ~ <integer part> <fractional part> <exponent> <plus or minus> int
#    float ~ <integer part> <exponent> <plus or minus> int
#    float ~ <integer part> <fractional part> <exponent> int
#    float ~ <fractional part> <exponent> int
#    float ~ <integer part> <exponent> int

#    <integer part>      ~ int
#    <fractional part>   ~ [\.] int
#    <plus or minus>     ~ [+-]
#    <exponent>          ~ [eE]

# operators from lower to higher priority as per refman 2.5.6

    [ 'or'                  => qr/\bor\b/xms,   "or"    ],
    [ 'and'                 => qr/\band\b/xms,  "and"   ],
    [ 'less than'           => qr/</xms,        ""      ],
    [ 'less or equal'       => qr/<=/xms,       ""      ],
    [ 'greater than'        => qr/>/xms,        ""      ],
    [ 'greater or equal'    => qr/>=/xms,       ""      ],
    [ 'negation'            => qr/~=/xms,       ""      ],
    [ 'equality'            => qr/==/xms,       ""      ],
    [ 'concatenation'       => qr/\.\./xms,       ""      ],
    [ 'addition'            => qr/\+/xms,        ""      ],
    [ 'minus'               => qr/-/xms,        ""      ],
    [ 'multiplication'      => qr/\*/xms,        ""      ],
    [ 'division'            => qr/\//xms,       ""      ],
    [ 'percent'             => qr/%/xms,        ""      ],
    [ 'not'                 => qr/\bnot\b/xms,      ""      ],
    [ 'length'              => qr/\#/xms,        ""      ],
    [ 'exponentiation'      => qr/\^/xms,        ""      ],

#   punctuation
    [ 'colon'               => qr/:/xms,        ""      ],
    [ 'left bracket'        => qr/\[/xms,        ""      ],
    [ 'right bracket'       => qr/\]/xms,        ""      ],
    [ 'ellipsis'            => qr/\.\.\./xms,      ""      ],
    [ 'left paren'          => qr/\(/xms,        ""      ],
    [ 'right paren'         => qr/\)/xms,        ""      ],
    [ 'left curly'          => qr/\{/xms,        ""      ],
    [ 'right curly'         => qr/\}/xms,        ""      ],
#    [ 'comment start'  => qr/--/xms,   ""    ],
    [ 'assignment'          => qr/=/xms,        ""      ],
    [ 'semicolon'           => qr/;/xms,        ""      ],
    [ 'comma'               => qr/,/xms,        ""      ],
    [ 'period'              => qr/\./xms,       ""      ],

);

    $recce->read( \$string, 0, 0 );

    my $length = length $string;
    pos $string = 0;
    TOKEN: while (1) {
        my $start_of_lexeme = pos $string;
        last TOKEN if $start_of_lexeme >= $length;
        next TOKEN if $string =~ m/\G\s+/gcxms;    # skip whitespace
        TOKEN_TYPE: for my $t (@terminals) {
            my ( $token_name, $regex, $long_name ) = @{$t};
            next TOKEN_TYPE if not $string =~ m/\G($regex)/gcxms;
            my $lexeme = $1;

            warn "$token_name, <$lexeme>";

            next TOKEN if $token_name =~ /comment/i; # skip comments

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
        return qq{No token found at position $start_of_lexeme, before "},
            substr( $string, pos $string, 40 ), q{"};
    } ## end TOKEN: while (1)

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
    my $recce = Marpa::R2::Scanless::R->new( \%default_recce_opts );

    $parser->read($recce, $source);
#
=pod internal lexing
    eval { $recce->read(\$source) };
    if ( defined $parse_opts and $parse_opts->{show_progress} ){
        warn "$@Progress report is:\n" . $recce->show_progress;
    }
=cut

    # return ast or undef on parse failure
    my $value_ref = $recce->value();
    return unless defined $value_ref;
    return ${ $value_ref };

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
