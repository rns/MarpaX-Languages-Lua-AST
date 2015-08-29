# Copyright 2015 Ruslan Shvedov

# Lua 5.1 Parser in SLIF with left recursion instead of sequences and external scanning

package MarpaX::Languages::Lua::AST;

use v5.10.1;
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Deepcopy = 1;

use Marpa::R2;

# todo: remove once MarpaX-AST is released
use lib qw{/home/Ruslan/MarpaX-AST/lib};
use lib qw{c:/cygwin/home/Ruslan/MarpaX-AST/lib};
use MarpaX::AST;
use MarpaX::AST::Discardables;

use MarpaX::Languages::Lua::AST::Error;

# Lua 5.1 Grammar
# ===============

my $lua_grammar_source = q{

:default ::= action => [ name, start, length, values ]
lexeme default = action => [ name, start, length, value ] latm => 1

    # source: 8 – The Complete Syntax of Lua, Lua 5.1 Reference Manual
    # http://www.lua.org/manual/5.1/manual.html

    # {a} means 0 or more a's, and [a] means an optional a

    # symbols in <> are <keywords> and <lexemes>
    # original rules are commented above the grammar rules
    # Capitalized symbols (Name) are from the lua grammar cited above

#   chunk ::= {stat [';']} [laststat [';']]
    chunk ::=
    chunk ::= statements
    chunk ::= statements laststat
    chunk ::= statements laststat <semicolon>
    chunk ::= laststat <semicolon>
    chunk ::= laststat

#   {stat [';']}
    statements ::= stat
    statements ::= stat <semicolon>
    statements ::= statements stat rank => -1
    statements ::= statements stat <semicolon>

    block ::= chunk

    stat ::= varlist <assignment> explist

    # ranks (below and above) resolve ambiguity with exp, e.g. t = loadstring('s = 1')()
    stat ::= functioncall rank => -1

    stat ::= <do> block <end>
    stat ::= <while> exp <do> block <end>
    stat ::= <repeat> block <until> exp

#   <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end>
    stat ::= <if> exp <then> block <end>
    stat ::= <if> exp <then> block <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <end>

    <one or more elseifs> ::= <one elseif>
    <one or more elseifs> ::= <one or more elseifs> <one elseif>
    <one elseif> ::= <elseif> exp <then> block

#   <for> Name <assignment> exp ',' exp [',' exp] <do> block <end>
    stat ::= <for> Name <assignment> exp <comma> exp <comma> exp <do> block <end>
    stat ::= <for> Name <assignment> exp <comma> exp <do> block <end>
    stat ::= <for> namelist <in> explist <do> block <end>

    stat ::= <function> funcname funcbody

    stat ::= <local> <function> Name funcbody

#   <local> namelist [<assignment> explist]
    stat ::= <local> namelist <assignment> explist
    stat ::= <local> namelist

#   laststat ::= <return> [explist] | <break>
    laststat ::= <return>
    laststat ::= <return> explist
    laststat ::= <break>

#   funcname ::= Name {'.' Name} [':' Name]
    funcname ::= qualifiedname
    funcname ::= qualifiedname <colon> Name

    qualifiedname ::= Name
    qualifiedname ::= qualifiedname <period> Name

#   varlist ::= var {',' var}
    varlist ::= var
    varlist ::= varlist <comma> var

    var ::= Name
    var ::= prefixexp <left_bracket> exp <right_bracket>
    var ::= prefixexp <period> Name

#   namelist ::= Name {',' Name}
    namelist ::= Name
    namelist ::= namelist <comma> Name

#   explist ::= {exp ','} exp
    explist ::= exp
    explist ::= explist <comma> exp

# todo: add more meaningful names than 'exp' once roundtripping works
    exp ::=
           var
         | <left_paren> exp <right_paren> assoc => group name => 'exp'
        || exp args assoc => right name => 'functioncall'
        || exp <colon> Name args assoc => right name => 'functioncall'
         | <nil> name => 'exp'
         | <false> name => 'exp'
         | <true> name => 'exp'
         | Number name => 'exp'
         | String name => 'exp'
         | <ellipsis> name => 'exp'
         | tableconstructor name => 'exp'
         | function funcbody name => 'exp'
        # exponentiation based on Jeffrey’s solution
        # -- https://github.com/ronsavage/MarpaX-Languages-Lua-Parser/issues/2
        || exp <exponentiation> exponent assoc => right name => 'binop'
        || <subtraction> exp name => 'unop' assoc => right
         | <length> exp name => 'unop'
         | <not> exp name => 'unop'
        || exp <multiplication> exp name => 'binop'
         | exp <division> exp name => 'binop'
         | exp <modulo> exp name => 'binop'
        || exp <addition> exp name => 'binop'
         | exp <subtraction> exp name => 'binop'
        || exp <concatenation> exp assoc => right name => 'binop'
        || exp <less_than> exp name => 'binop'
         | exp <less_or_equal> exp name => 'binop'
         | exp <greater_than> exp name => 'binop'
         | exp <greater_or_equal> exp name => 'binop'
         | exp <equality> exp name => 'binop'
         | exp <negation> exp name => 'binop'
        || exp <and> exp name => 'binop'
        || exp <or> exp name => 'binop'

    exponent ::=
           var name => 'exp'
         | <left_paren> exp <right_paren> name => 'exp'
        || exponent args name => 'exp'
        || exponent <colon> Name args name => 'exp'
         | <nil> name => 'exp'
         | <false> name => 'exp'
         | <true> name => 'exp'
         | Number name => 'exp'
         | String name => 'exp'
         | <ellipsis> name => 'exp'
         | tableconstructor name => 'exp'
         | function name => 'exp'
        || <not> exponent name => 'exp'
         | <length> exponent name => 'exp'
         | <subtraction> exponent name => 'exp'

    prefixexp ::= var
    prefixexp ::= functioncall
    prefixexp ::= <left_paren> exp <right_paren>

# todo: As an exception to the free-format syntax of Lua, you cannot put a line break
# before the '(' in a function call. This restriction avoids some
# ambiguities in the language.

    functioncall ::= prefixexp args
    functioncall ::= prefixexp <colon> Name args

#   args ::=  '(' [explist] ')' | tableconstructor | String
    args ::= <left_paren> <right_paren>
    args ::= <left_paren> explist <right_paren>
    args ::= tableconstructor
    args ::= String

#   funcbody ::= '(' [parlist] ')' block <end>
    funcbody ::= <left_paren> parlist <right_paren> block <end>
    funcbody ::= <left_paren> <right_paren> block <end>

#   parlist ::= namelist [',' '...'] | '...'
    parlist ::= namelist
    parlist ::= namelist <comma> <ellipsis>
    parlist ::= <ellipsis>

#   tableconstructor ::= '{' [fieldlist] '}'
    tableconstructor ::= <left_curly> <right_curly>
    tableconstructor ::= <left_curly> fieldlist <right_curly>

#   fieldlist ::= field {fieldsep field} [fieldsep]
    fieldlist ::= field
    fieldlist ::= fieldlist fieldsep field
    fieldlist ::= fieldlist fieldsep field fieldsep

    fieldsep ::= <comma>
    fieldsep ::= <semicolon>

    field ::= <left_bracket> exp <right_bracket> <assignment> exp
    field ::= Name <assignment> exp
    field ::= exp

    Number ::= Int | Float | Hex

    String ::= <long_nestable_string>
    String ::= <long_unnestable_string>
    String ::= <double_quoted_string>
    String ::= <single_quoted_string>

#   unicorns
    # unicorn rules will be added in the constructor
    unicorn ~ [^\s\S]

};

my @unicorns = (

    'Int', 'Float', 'Hex',
    'Name',

    '<long_nestable_string>',
    '<long_unnestable_string>',
    '<double_quoted_string>',
    '<single_quoted_string>',

    '<addition>',
    '<and>',
    '<assignment>',
    '<break>',
    '<colon>',
    '<comma>',
    '<concatenation>',
    '<division>',
    '<do>',
    '<ellipsis>',
    '<else>',
    '<elseif>',
    '<end>',
    '<equality>',
    '<exponentiation>',
    '<false>',
    '<for>',
    '<function>',
    '<greater_or_equal>',
    '<greater_than>',
    '<if>',
    '<in>',
    '<left_bracket>',
    '<left_curly>',
    '<left_paren>',
    '<length>',
    '<less_or_equal>',
    '<less_than>',
    '<local>',
    '<subtraction>',
    '<multiplication>',
    '<negation>',
    '<nil>',
    '<not>',
    '<or>',
    '<modulo>',
    '<period>',
    '<repeat>',
    '<return>',
    '<right_bracket>',
    '<right_curly>',
    '<right_paren>',
    '<semicolon>',
    '<then>',
    '<true>',
    '<until>',
    '<while>',
);

# Terminals
# =========

# group matching regexes

# keywords
my @keywords = qw {
    and break do else elseif end false for function if in local nil not
    or repeat return then true until while
};

my $keywords = { map { $_ => $_ } @keywords };

# operators, punctuation
my $op_punc = {
            '...' =>'ellipsis',         '..' => 'concatenation',

            '<=' => 'less_or_equal',    '>=' => 'greater_or_equal',
            '~=' => 'negation',         '==' => 'equality',

            '.' =>  'concatenation',    '<' =>  'less_than',
            '>' =>  'greater_than',     '+' =>  'addition',
            '-' =>  'subtraction',      '*' =>  'multiplication',
            '/' =>  'division',         '%' =>  'modulo',
            '#' =>  'length',           '^' =>  'exponentiation',
            ':' =>  'colon',            '[' =>  'left_bracket',
            ']' =>  'right_bracket',    '(' =>  'left_paren',
            ')' =>  'right_paren',      '{' =>  'left_curly',
            '}' =>  'right_curly',      '=' =>  'assignment',
            ';' =>  'semicolon',        ',' =>  'comma',
            '.' =>  'period',
};

# terminals are regexes and strings
my @terminals = ( # order matters!

#   comments -- short, long (nestable)
    [ 'long_nestable_comment' => q/--\[(={4,})\[.*?\]\1\]/, ],
    [ 'long_nestable_comment' => q/--\[===\[.*?\]===\]/,    ],
    [ 'long_nestable_comment' => q/--\[==\[.*?\]==\]/,      ],
    [ 'long_nestable_comment' => q/--\[=\[.*?\]=\]/,        ],
    [ 'long_unnestable_comment' => q/--\[\[.*?\]\]/,        ],
    [ 'short_comment' => q/--[^\n]*\n/,                     ],

#   strings -- short, long (nestable)
    [ 'single_quoted_string' => q{'(?:[^'\\\\]|\\\\.)*'}    ], #'
    [ 'double_quoted_string' => q{"(?:[^"\\\\]|\\\\.)*"}    ], #"

    [ 'long_unnestable_string' => q/\[\[.*?\]\]/,           ],
    [ 'long_nestable_string' => q/\[=\[.*?\]=\]/,           ],
    [ 'long_nestable_string' => q/\[==\[.*?\]==\]/,         ],
    [ 'long_nestable_string' => q/\[===\[.*?\]===\]/,       ],
    [ 'long_nestable_string' => q/\[====\[.*?\]====\]/,     ],
    [ 'long_nestable_string' => q/\[(={5,})\[.*?\]\1\]/,    ],

#   numbers -- int, float, and hex
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
    [ 'Float' => q/[0-9]+\.?[0-9]+([eE][-+]?[0-9]+)?/       ],
    [ 'Float' => q/[0-9]+[eE][-+]?[0-9]+/                   ],
    [ 'Float' => q/[0-9]+\./                                ],
    [ 'Float' => q/\.[0-9]+/                                ],
    [ 'Hex' => q/0x[0-9a-fA-F]+/                            ],
    [ 'Int' => q/[\d]+/                                     ],

#   identifiers
    [ 'Name' => q/\b[a-zA-Z_][\w]*\b/, "Name"               ],

);

sub _token_capture_groups{
    my ($terminals) = @_;

    my @match_regex;
    for my $t ( @{ $terminals } ) {
#        warn $t;
        my ($token, $regex) = @{$t};
#        warn $regex;
        # todo: check if $token is a valid capture group name;
        my $lexeme_re = '(?<' . $token . '>' . $regex . ')';
        qr/$lexeme_re/;
        push @match_regex, [ $token, $lexeme_re ];
    }
    return \@match_regex;
}

sub terminals{
    my ($parser) = @_;

    # add keywords
    push @terminals, [ $_, $_ ] for @keywords;

    # add operators and punctuation
    push @terminals, [ $op_punc->{$_}, quotemeta($_)]
        for sort { length($b) <=> length($a) } keys %$op_punc;

#    warn MarpaX::AST::dumper(\@terminals);
    return \@terminals;
}

# add unicorns to grammar source and construct the grammar
sub grammar{
    my ($extension) = @_;
    $extension //= '';
    my $source = $lua_grammar_source . "\n### extension rules ###" . $extension . "\n" . join( "\n", map { qq{$_ ~ unicorn} } @unicorns ) . "\n";
#    say $source if $extension;
    return Marpa::R2::Scanless::G->new( { source => \$source } );
}

sub new {
    my ($class, $opts) = @_;
    my $parser = bless {}, $class;
    $parser->{grammar} = grammar();
    if (ref $opts eq "HASH"){
        $parser->{opts} = $opts;
    }
    $parser->{start_to_line_column} = {};
    return $parser;
}

sub next_line_column{
    my ($lexeme, $length_of_lexeme, $line, $column) = @_;

    # todo: more realistic newlines, per Unicode 4.0.0, 5.8 Newline Guidelines
    my $newlines = $lexeme =~ tr/\n//;
    if ($newlines > 0){
        $line += $newlines;
        $column = $length_of_lexeme - rindex($lexeme, "\n");
    }
    else { $column += $length_of_lexeme }

    return ($line, $column);
}

sub line_column{
    my ($parser, $start) = @_;
    return @{ $parser->{start_to_line_column}->{$start} };
}

sub read{
    my ($parser, $recce, $string) = @_;

    # build terminals
    my @terminals = @{ $parser->terminals() };

    # build capture group regexp
    my $cgre = _token_capture_groups(\@terminals);
    my $match_regex = join "|", map { $_->[1] } @$cgre;

    $recce->read( \$string, 0, 0 );

    # line/column info for $start
    my $line    = 1;
    my $column  = 1;

    # discard special comment on first line
    my $length = length $string;
    if ($string =~ m{^(#.*)\n}){
        my $special_comment = $1;
        my $special_comment_length = length $special_comment;
        $parser->{discardables}->post(
            'special comment on first line', 0, $special_comment_length, $special_comment);
        pos $string = length($special_comment);
        $line++;
    }
    else{
        pos $string = 0;
    }

    # check if we need to roundtrip and set up if we do
    my $roundtrip = $parser->{opts}->{roundtrip};
    my $discardables;
    if ($roundtrip){
        $discardables = $parser->{discardables};
    }

    # match and read tokens
    TOKEN: while (1) {
        my $start_of_lexeme = pos $string;
        last TOKEN if $start_of_lexeme >= $length;
        # handle whitespace
        if ($string =~ m/\G(\s+)/gcxmso){
            my $whitespace = $1;
            my $length_of_lexeme = length $whitespace;

#            warn qq{whitespace: '$whitespace' \@$start_of_lexeme:$length_of_lexeme ($line:$column)\n};
            $parser->{start_to_line_column}->{$start_of_lexeme} = [ $line, $column ];
            ($line, $column) = next_line_column($whitespace, $length_of_lexeme, $line, $column);

            if ($roundtrip){
                $discardables->post(
                    'whitespace', $start_of_lexeme, $length_of_lexeme, $whitespace);
            }

            next TOKEN;
        }
#        warn "# matching at $start_of_lexeme, line: $line:\n'",
#            substr( $string, $start_of_lexeme, 40 ), "'";

        my ( $token_name, $regex, $lexeme );
#            warn $token_name;

        next TOKEN if not $string =~ m/\G($match_regex)/gcxmso;

        warn "multiple match" if keys %+ > 1;
        ($token_name, $lexeme) = each %+;

        my $length_of_lexeme = length $lexeme;
        # Name cannot be a keyword so treat strings matching Name's regex as keywords
        if ( $token_name eq "Name" and exists $keywords->{$lexeme} ){
            $token_name = $keywords->{$lexeme};
        }

#        warn qq{$token_name: '$lexeme' \@$start_of_lexeme:$length_of_lexeme ($line:$column)\n};
        $parser->{start_to_line_column}->{$start_of_lexeme} = [ $line, $column ];
        ($line, $column) = next_line_column($lexeme, $length_of_lexeme, $line, $column);

        if ($token_name =~ /comment/i){
#            warn qq{'$lexeme' \@$start_of_lexeme:$length_of_lexeme};
            if ($roundtrip){
                $discardables->post(
                    $token_name, $start_of_lexeme, $length_of_lexeme, $lexeme);
            }
            next TOKEN;
        }

#        warn "# <$token_name>:\n'$lexeme'";
        if ( not defined $recce->lexeme_alternative($token_name) ) {
            my ($l, $c) = $parser->line_column($start_of_lexeme);
            warn qq{Parser rejected token $token_name ("$lexeme") at $l:$c\n},
                "after \"", substr( $string, $start_of_lexeme - 40, 40), "\"\n",
                "before \"", substr( $string, $start_of_lexeme + length($lexeme), 40 ), '"';
            my $err = MarpaX::Languages::Lua::AST::Error->new($recce, $parser->{grammar});
#            warn join "\n", $err->longest_spans(\@unicorns);
            $err->show();
            return
        }
        next TOKEN if $recce->lexeme_complete( $start_of_lexeme, length($lexeme) );

        warn qq{No token found at position $start_of_lexeme, before "},
            substr( $string, pos $string, 40 ), q{"};
#        warn "Showing progress:\n", $recce->show_progress();
        return
    } ## end TOKEN: while (1)

#   handle ambiguity
    if ($recce->ambiguity_metric() > 1){
        my $max_values = 100;
        my $i = 0;
        my @v;
        while (my $v = $recce->value() and $i <= $max_values){ $i++; push @v, $v }
        warn "Ambiguous parse: ",
            ($i > $max_values ? "over $max_values" : $i), " alternatives.";
        $recce->series_restart();
        warn $recce->ambiguous();
        $recce->series_restart();
        if (wantarray){
            return @v;
        }
    }
    # return ast or undef on parse failure
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        warn "No parse was found, after reading the entire input.\n";
#        warn "Showing progress:\n", $recce->show_progress();
        # todo: options for reparse with diagnostics and show progress, e.g.
=pod
                $ast = $p->parse(
                    $lua_slurp,
                    { trace_terminals => 1 },
                    { show_progress => 1 }
                    );
=cut
        return
    }
    return wantarray ? ( $value_ref ) : ${$value_ref};
}

sub parse {
    my ( $parser, $source, $recce_opts ) = @_;
    $recce_opts //= {};
    $recce_opts->{grammar} = $parser->{grammar};
    my $recce = Marpa::R2::Scanless::R->new( $recce_opts, { ranking_method => 'high_rule_only' } );
    if ( $parser->{opts}->{roundtrip} ) {
        $parser->{discardables} = MarpaX::AST::Discardables->new;
    }
    $parser->{parse_tree} = $parser->read($recce, $source);
    return $parser->{parse_tree};
}

sub roundtrip{
    my ( $parser, $source, $recce_opts ) = @_;
    $parser->{opts}->{roundtrip} //= 1; # roundtripping is off by default
    my $ast = $parser->parse( $source, $recce_opts );
    $ast = MarpaX::AST->new($ast, { CHILDREN_START => 3 } );
    $ast = $ast->distill({
        root => 'chunk',
        skip => [ 'statements', 'chunk' ],
    });
    $parser->{distilled_parse_tree} = $ast;
    return $ast->roundtrip($parser->{discardables});
}

# todo: pretty printing
sub fmt {

}

1;
