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
my %lua_files = qw{

    lua-tests/coroutine.lua         1

    lua5.1-tests/api.lua            2
    lua5.1-tests/attrib.lua         1
    lua5.1-tests/big.lua            1
    lua5.1-tests/calls.lua          1
    lua5.1-tests/checktable.lua     1
    lua5.1-tests/closure.lua        1
    lua5.1-tests/code.lua           1
    lua5.1-tests/constructs.lua     1
    lua5.1-tests/db.lua             1
    lua5.1-tests/errors.lua         1
    lua5.1-tests/events.lua         1
    lua5.1-tests/files.lua          1
    lua5.1-tests/gc.lua             1
    lua5.1-tests/literals.lua       1
    lua5.1-tests/locals.lua         1
    lua5.1-tests/main.lua           1
    lua5.1-tests/math.lua           1
    lua5.1-tests/nextvar.lua        1
    lua5.1-tests/pm.lua             1
    lua5.1-tests/sort.lua           1
    lua5.1-tests/strings.lua        1
    lua5.1-tests/vararg.lua         1
    lua5.1-tests/verybig.lua        1
};

LUA_FILE:
    for my $lua_fn (sort keys %lua_files){

        # get flags
        my $flag = $lua_files{$lua_fn};

        # prepend t if running under prove
        $lua_fn = 't/' . $lua_fn unless $pwd =~ m{ /t$ }x;

        # As an example, consider the following code:
        my $lua_slurp = slurp_file( $lua_fn );

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
        my $tokens = $p->tokens($ast);
        my $lua_file = whip_up_lua_file( $tokens );
        # run lua interpreter on ast serialized to tokens
        my $run_lua_test = 'run_lua_test.sh';
        system("./$run_lua_test $lua_file 1>$lua_file.stdout 2>$lua_file.stderr");
        my ($stdout, $stderr) = map { slurp_file($_) } qq{$lua_file.stdout}, qq{$lua_file.stderr};
        # check for compile error, fail and proceed as flagged if any
        if ($stderr){
            fail "compile $lua_fn:\n$stderr";
            if ($flag eq 3){ # reparse and show ast
                $ast = $p->parse( $lua_slurp );
                warn "# ast of $lua_fn: ", $p->serialize( $ast );
            }
            next LUA_FILE;
        }
        # file parses and compiles, test against its output
        is $stdout, $expected_stdout, $lua_fn;
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

