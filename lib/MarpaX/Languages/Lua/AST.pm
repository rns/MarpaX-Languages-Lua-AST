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

use Marpa::R2 2.096;

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
        || exp <less than> exp name => 'binop'
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
    String ::= <double quoted string>
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
    '<double quoted string>',
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
    '<less than>',
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

            '.' =>  'concatenation',    '<' =>  'less than',
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
    [ 'long_nestable_comment' => qr/--\[(={4,})\[.*?\]\1\]/xms, ],
    [ 'long_nestable_comment' => qr/--\[===\[.*?\]===\]/xms,    ],
    [ 'long_nestable_comment' => qr/--\[==\[.*?\]==\]/xms,      ],
    [ 'long_nestable_comment' => qr/--\[=\[.*?\]=\]/xms,        ],
    [ 'long_unnestable_comment' => qr/--\[\[.*?\]\]/xms,        ],
    [ 'short_comment' => qr/--[^\n]*\n/xms,                     ],

#   strings -- short, long (nestable)
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

    [ 'single_quoted_string' => qr
        /'(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^']
           )*
         '/xms, ],

    [ 'double quoted string' => qr
        /"(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^"]
           )*
         "/xms, ],
#'
    [ 'long_unnestable_string' => qr/\[\[.*?\]\]/xms,        ],
    [ 'long_nestable_string' => qr/\[=\[.*?\]=\]/xms,        ],
    [ 'long_nestable_string' => qr/\[==\[.*?\]==\]/xms,      ],
    [ 'long_nestable_string' => qr/\[===\[.*?\]===\]/xms,    ],
    [ 'long_nestable_string' => qr/\[====\[.*?\]====\]/xms,  ],
    [ 'long_nestable_string' => qr/\[(={5,})\[.*?\]\1\]/xms, ],

#   numbers -- int, float, and hex
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
    [ 'Float' => qr/[0-9]+\.?[0-9]+([eE][-+]?[0-9]+)?/xms, "Floating-point number" ],
    [ 'Float' => qr/[0-9]+[eE][-+]?[0-9]+/xms, "Floating-point number" ],
    [ 'Float' => qr/[0-9]+\./xms, "Floating-point number" ],
    [ 'Float' => qr/\.[0-9]+/xms, "Floating-point number" ],
    [ 'Hex' => qr/0x[0-9a-fA-F]+/xms, "Hexadecimal number" ],
    [ 'Int' => qr/[\d]+/xms, "Integer number" ],

#   identifiers
    [ 'Name' => qr/\b[a-zA-Z_][\w]*\b/xms, "Name" ],

);

sub _capture_group_regex{
    my ($terminals) = @_;

    my %tokens;
    my @match_regex;
    for my $t ( @{ $terminals } ) {
        warn $t;
        my ($token, $regex) = @{$t};
        warn $regex;
#        $token =~ s/[^a-zA-Z_0-9]/_/g;
#        $tokens{$token} = $lexeme->[0] if $token ne $lexeme->[0];
#        push @match_regex, qq{(?<$token>$regex)};
    }
#    my $match_regex = join '|', @match_regex;
#    say $match_regex;
#    say %tokens;
}

sub terminals{
    my ($parser) = @_;

    # add keywords
    push @terminals, [ $_, qr/$_/xms ] for @keywords;

    # add operators and punctuation
    push @terminals, [ $op_punc->{$_}, qr/\Q$_\E/xms ]
        for sort { length($b) <=> length($a) } keys %$op_punc;

    # build capture group regexp

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

# todo: re-implement extension via SLIF ast transform and capture groups
sub extend{
    my ($parser, $opts) = @_;

    my $rules = $opts->{rules};

    $parser->{handlers} = $opts->{handlers};

    # todo: this is quick hack, use metag.bnf
    # add new literals, keywords and unicorns
    for my $literal (keys %{ $opts->{literals} }){
        my $symbol = $opts->{literals}->{$literal};
#        say "new literal: $symbol, $literal";
        # save new literal to keywords or other lexemes
        if ($literal =~ /^[\w]+$/){
            $parser->{new_keywords}->{$literal} = $symbol;
        }
        else{
            $op_punc->{$literal} = $symbol;
        }
        # add unicorn
        $symbol = qq{<$symbol>} if $symbol =~ / /;
        push @unicorns, $symbol;
    }

    # replace known literals to lexemes
    my %literals = map { $_ => undef } $rules =~ m/'([^\#'\n]+)'/gms; #'
LITERAL: while (my ($literal, undef) = each %literals){
        my $symbol = $op_punc->{$literal} || $parser->{new_keywords}->{$literal};
        if (defined $symbol){
            $symbol = qq{<$symbol>} if $symbol =~ / /;
            # remove L0 rules if any
            $rules =~ s/<?[\w_ ]+>?\s*~\s*'\Q$literal\E'\n?//ms; #'
            # replace known literals with symbols
            $rules =~ s/'\Q$literal\E'/$symbol/gms;
            # now the literal is known
            delete $literals{$literal};
        }
    }

    # find symbol ~ '...' L0 rules and see if they have names for unknown literals
    # todo: the same thing for character classes once/if general lexing
    # (https://gist.github.com/rns/2ae390a2c7d235687287) is supported

#    say "# unknown literals:\n  ", join "\n  ", keys %literals;
    my @L0_rules = $rules =~ m/<?([\w_ ]+)>?\s*~\s*'([^\#'\n]+)'/gms; #'
    for(my $ix = 0; $ix <= $#L0_rules; $ix += 2) {
        my $symbol = $L0_rules[$ix];
        $symbol =~ s/\s+$//;
        my $literal = $L0_rules[$ix + 1];
#        say "<$symbol> ~ '$literal'";
        # add symbol and literal to external lexing
        $op_punc->{$literal} = $symbol;
        # remove L0 rule
        $rules =~ s/<?$symbol>?\s*~\s*'\Q$literal\E'\n?//ms; #'
        # add new symbol as unicorn
        $symbol = qq{<$symbol>} if $symbol =~ / /;
        push @unicorns, $symbol;
        # now we know the literal
        delete $literals{$literal};
    }
    # todo: support charclasses?

    die "# unknown literals:\n  ", join "\n  ", keys %literals if keys %literals;

    # terminals for external lexing will be rebuilt when parse()
    # now append $rules and try to create new grammar
    $parser->{grammar} = grammar( $rules );
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

        my %terminals_expected = map { $_ => 1 }
            @{ $recce->terminals_expected },
            # comments are not in the grammar, so we need to add them
            'long_nestable_comment', 'long_unnestable_comment', 'short_comment';
# todo: investigate constructs.lua:83:3 failure with terminals_expected
#        warn "\n# ", join ', ', keys %terminals_expected;
        TOKEN_TYPE: for my $t (@terminals) {

            my ( $token_name, $regex ) = @{$t};
#            warn $token_name;

            if (exists $parser->{opts}->{use_terminals_expected}){
                next TOKEN_TYPE unless exists $terminals_expected{$token_name};
            }

            next TOKEN_TYPE if not $string =~ m/\G($regex)/gcxms;
            my $lexeme = $1;
            my $length_of_lexeme = length $lexeme;
            # Name cannot be a keyword so treat strings matching Name's regex as keywords
            if ( $token_name eq "Name" and exists $keywords->{$lexeme} ){
                $token_name = $keywords->{$lexeme};
            }
            # check for group matching
            if (ref $token_name eq "HASH"){
                $token_name = $token_name->{$lexeme};
                die "No token defined for lexeme <$lexeme>"
                    unless $token_name;
            }

#            warn qq{$token_name: '$lexeme' \@$start_of_lexeme:$length_of_lexeme ($line:$column)\n};
            $parser->{start_to_line_column}->{$start_of_lexeme} = [ $line, $column ];
            ($line, $column) = next_line_column($lexeme, $length_of_lexeme, $line, $column);

            if ($token_name =~ /comment/i){
#                warn qq{'$lexeme' \@$start_of_lexeme:$length_of_lexeme};
                if ($roundtrip){
                    $discardables->post(
                        $token_name, $start_of_lexeme, $length_of_lexeme, $lexeme);
                }
                next TOKEN;
            }

#            warn "# <$token_name>:\n'$lexeme'";
            if ( not defined $recce->lexeme_alternative($token_name) ) {
                my ($l, $c) = $parser->line_column($start_of_lexeme);
                warn qq{Parser rejected token $token_name ("$lexeme") at $l:$c\n},
                    "after \"", substr( $string, $start_of_lexeme - 40, 40), "\"\n",
                    "before \"", substr( $string, $start_of_lexeme + length($lexeme), 40 ), '"';
                my $err = MarpaX::Languages::Lua::AST::Error->new($recce, $parser->{grammar});
#                warn join "\n", $err->longest_spans(\@unicorns);
                $err->show();
                return
            }
            next TOKEN
                if $recce->lexeme_complete( $start_of_lexeme,
                        ( length $lexeme ) );

        } ## end TOKEN_TYPE: for my $t (@terminals)
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

sub fmt{
    my ($parser, $ast, $opts) = @_;
    if (defined $opts and ref $opts ne "HASH"){
        warn "arg 2 to fmt() must be a hash ref, not ", ref $opts;
    }
    else{ # check for options and set defaults if missing
        $opts->{indent} //= '  ';
    }
    $opts->{handlers} = $parser->{handlers};
    $opts->{parser}   = $parser;
    my $fmt = do_fmt( $ast, $opts );
    $fmt =~ s/^\n//ms;
    $fmt =~ s{[ ]+\n}{\n}gms;
    return $fmt;
}

sub do_fmt{
    my ($ast, $opts) = @_;
    my $s;
    # options
    state $indent   = $opts->{indent};
    state $handlers = $opts->{handlers};
    state $parser   = $opts->{parser};
    # context
    state $current_node //= '';
    state $current_parent_node //= '';
    state $previous_literal_node //= '';
    # indenting
    state $indent_level //= 0;
    state @indent_level_blocks; # $indent_level_stats[0] is block node_id at level 0
    # node is a literal or has children?
    if (ref $ast){
        my ($node_id, undef, undef, @children) = @$ast;
        # save context for nodes down the ast
        $current_node = $node_id;
        # current node as parent of its children literal nodes
        if ( $node_id =~ m{^(binop|Number|String|Comment|unop)$}xms ){
            $current_parent_node = $node_id;
        }
        # save stat/functioncall
        elsif ( $node_id eq 'stat' and $children[0]->[0] eq 'functioncall' ){
            $current_parent_node = 'functioncall';
        }
        elsif ( $node_id eq 'stat' ){
            $current_parent_node = $node_id;
        }
        # indenting
        if ($node_id =~ /^(function|if|else|elseif|then|for|while|repeat)$/) {
            $indent_level_blocks[$indent_level] = $node_id;
        }
        $indent_level++ if $node_id eq 'block';

        # if the node can be processed by handler passed via extend(), doit
        if (    ref $children[0] eq "ARRAY"
            and exists $handlers->{ $children[0]->[0] }
            and    ref $handlers->{ $children[0]->[0] } eq "CODE"
            ){
            # call handler
            $s .= $handlers->{ $children[0]->[0] }->(
                $parser,
                $ast,
                {
                    indent       => $indent,
                    indent_level => $indent_level,
                }
            );
        }
        else { # proceed as usual
            $s .= join '', grep { defined } do_fmt( $_ ) for @children;
        }
        # indenting
        $indent_level-- if $node_id eq 'block';
    }
    else{ # handlers: order matters
        # print literal and its context
#        say "# $current_node: '$ast'";
#        say "  current parent node   : '$current_parent_node'" if $current_parent_node;
#        say "  indent level          : $indent_level";
#        say "  indent level blocks   : ", join ' ', @indent_level_blocks if @indent_level_blocks;
#        say "  previous literal node : '$previous_literal_node'" if $previous_literal_node;
        # append current literal
        if    ( $ast =~ /^(function|for|while|repeat)$/   ){
            $s .= ( $previous_literal_node !~ /^(short_comment)$/ ? "\n" : '' )
                . $indent x $indent_level . $ast . ' '
        }

        elsif ( $ast =~ /^if$/         ){ $s .= "\n" . $indent x $indent_level . $ast . ' ' }
        elsif ( $ast =~ /^local$/      ){ $s .= "\n" . $indent x $indent_level . $ast . ' ' }
        elsif ( $ast =~ /^elseif$/     ){ $s .= "\n" . $indent x $indent_level . $ast . ' ' }
        elsif ( $ast =~ /^until$/      ){ $s .= "\n" . $indent x $indent_level . $ast . ' ' }
        elsif ( $ast =~ /^return$/     ){ $s .= "\n" . $indent x $indent_level . $ast . ' ' }

        elsif ( $ast =~ /^else$/       ){ $s .= "\n" . $indent x $indent_level . $ast }

        elsif ( $ast =~ /^do$/         ){ $s .= ' ' . $ast . ' ' }
        elsif ( $ast =~ /^then$/       ){ $s .= ' ' . $ast }

        elsif ( $ast =~ /^end$/        ){
            $s .= $indent_level_blocks[$indent_level] eq 'handler' ? '' : "\n";
            $s .= $indent x $indent_level . $ast;
            # add newline after function/local/do end
            $s .= $indent_level_blocks[$indent_level] =~ /^(function|local|do)$/ ? "\n" : '';
            $indent_level_blocks[$indent_level] = '';
        }
        elsif ( $previous_literal_node eq 'function' ){
#            say "# $current_node: '$ast'";
            $s .= $ast . ' ';
        }
        elsif ( $current_node eq 'short_comment' ){
#            say "# $current_parent_node/$current_node: '$ast'";
#            chomp $ast;
            $s .= '  ' . $ast;
        }
        elsif ( $current_node eq 'assignment'   ){ $s .= ' ' . $ast . ' ' }
        # stat/functioncall/Name
        elsif ( $current_node eq 'Name'
            and $current_parent_node =~ /^(stat|functioncall)$/
            and $previous_literal_node ne 'assignment'
            and $previous_literal_node ne 'if'
            and $previous_literal_node ne 'for'
            and $previous_literal_node ne 'local'
            ){
            $s .= ( $previous_literal_node !~ /^(short_comment|comma)$/ ? "\n" : '' ) .
                $indent x $indent_level . $ast;
        }
        elsif ( $current_node =~ m{(^
                    double\ quoted\ string|single\ quoted\ string|
                    left\ paren|right\ paren|left\ bracket|right\ bracket|
                    left\ curly|right\ curly|semicolon|
                    Name|period
                $)
                }xms
            or  $current_parent_node =~ m{^
                    String|Number
                $}xms
            ){
        # for now just substitute
#            say "# $current_parent_node/$current_node: '$ast'";
            if ($current_node =~ /string$/){
                $ast =~ s/ ,/,/gms;
            }
#            say "# $current_node: '$ast'";
            $s .= $ast;
            $current_parent_node = '';
        }
        elsif ( $current_parent_node eq 'unop' or $current_node eq 'comma' ){
            $s .= $ast . ' ';
        }
        elsif ( $current_parent_node eq 'binop'
            and $current_node eq 'subtraction' ){
            $s .= ' ' . $ast . ' '
        }
        elsif ( $current_parent_node eq 'binop' or
                $current_node =~ /^(in|and|or)$/
            ){
            $s .= ' ' . $ast . ' '
            }
        else{
            $s .= $indent x $indent_level . $ast;
        }
        # set context item
        $previous_literal_node = $current_node;
    }
    return $s;
}

sub serialize{
    my ($parser, $ast) = @_;
    state $depth++;
    my $s;
    my $indent = "  " x ($depth - 1);
    if (ref $ast){
        my ($node_id, undef, undef, @children) = @$ast;
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
