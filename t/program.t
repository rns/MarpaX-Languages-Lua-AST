#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua program and test its execution results
# returned by the lua interpreter for the original source code and
# for the source code parsed to AST that is then serialized

# source of programs: http://lua-users.org/wiki/SampleCode

use 5.010;
use warnings;
use strict;

use Test::More;
use Test::Output;

use File::Temp qw{ tempfile };

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;

use Cwd qw();
my $pwd = Cwd::cwd();

#   file name                       flags:  1 default: do nothing
#                                           2 reparse with diagnostics
#                                           3 reparse and show ast
#                                           4 test with like()
#                                           5 stderr is expected -- lua file runs with errors
#                                           6 strings issue -- will parse with external lexing
my %lua_files = qw{

    lua-tests/coroutine.lua         1

    lua5.1-tests/api.lua            1
    lua5.1-tests/attrib.lua         1
    lua5.1-tests/big.lua            5
    lua5.1-tests/calls.lua          1
    lua5.1-tests/checktable.lua     1
    lua5.1-tests/closure.lua        5
    lua5.1-tests/code.lua           1
    lua5.1-tests/constructs.lua     1
    lua5.1-tests/db.lua             1
    lua5.1-tests/errors.lua         6
    lua5.1-tests/events.lua         1
    lua5.1-tests/files.lua          1
    lua5.1-tests/gc.lua             1
    lua5.1-tests/literals.lua       6
    lua5.1-tests/locals.lua         1
    lua5.1-tests/main.lua           6
    lua5.1-tests/math.lua           1
    lua5.1-tests/nextvar.lua        1
    lua5.1-tests/pm.lua             1
    lua5.1-tests/sort.lua           4
    lua5.1-tests/strings.lua        1
    lua5.1-tests/vararg.lua         6
    lua5.1-tests/verybig.lua        6
};

# shell script run lua interpreter on ast serialized to tokens
my $run_lua_test = 'run_lua_test.sh';
# prepend t if running under prove
$run_lua_test = 't/' . $run_lua_test unless $pwd =~ m{ /t$ }x;

# this is used below to silence "Deep recursion warning ... on tokens()"
# todo: check if the recursion is really deep
my $DOWARN;
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN } }

LUA_FILE:
    for my $lua_fn (sort keys %lua_files){

        # get flags
        my $flag = $lua_files{$lua_fn};

SKIP: {
        skip "$lua_fn strings issue -- will parse with external lexing", 1 if $flag == 6;

        # prepend t if running under prove
        $lua_fn = 't/' . $lua_fn unless $pwd =~ m{ /t$ }x;

        # As an example, consider the following code:
        my $lua_slurp = slurp_file( $lua_fn );

        # strip 'special comment on the first line'
        # todo: do it with external lexing
        $lua_slurp =~ s{^#.*\n}{};

        # When you run it, it produces the following output:
        my $expected_stdout = slurp_file( qq{$lua_fn.out} );

        # parse
        my $ast = $p->parse($lua_slurp);
        # check for parse error, fail and proceed as flagged if any
        unless (defined $ast){
            fail "parse $lua_fn";
            if ($flag eq 2){ # reparse with diagnostics
                $ast = $p->parse(
                    $lua_slurp,
                    { trace_terminals => 1 },
                    { show_progress => 1 }
                    );
            }
            next LUA_FILE;
        }

        # serialize ast to tokens and write to temporary file
$DOWARN = 0; # see above
        my $tokens = $p->tokens($ast);
$DOWARN = 1;
        my $lua_file = whip_up_lua_file( $tokens );

        # run lua file
        system("./$run_lua_test $lua_file 1>$lua_file.stdout 2>$lua_file.stderr");
        my ($stdout, $stderr) = map { slurp_file($_) } qq{$lua_file.stdout}, qq{$lua_file.stderr};

        # check for run error, fail and proceed as flagged if any
        if
        (
                $stderr         # there was run error
            and $flag != 5      # and it is NOT expected
        ){
            fail "run $lua_fn:\n$stderr";
            if ($flag eq 3){ # reparse and show ast
                $ast = $p->parse( $lua_slurp );
                warn "# ast of $lua_fn: ", $p->serialize( $ast );
            }
            next LUA_FILE;
        }
        # file parses and runs, test against its output
        if ($flag == 4){
            if ( $lua_fn =~ m{ lua5.1-tests/sort.lua$ }x ){
                # turn $expected_stdout to a regex and test against it
                $expected_stdout =~ s{[\d\.]+}{[\\d\\.]+}gx;
                like $stdout, qr/$expected_stdout/, $lua_fn;
                next LUA_FILE;
            }
        }
        is $stdout, $expected_stdout, $lua_fn;
} # SKIP
    } ## for my $lua_fn (@lua_files){

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_text) = @_;
    my ($fh, $filename) = tempfile();
    say $fh $lua_text;
    close $fh;
    return $filename;
}

done_testing();

