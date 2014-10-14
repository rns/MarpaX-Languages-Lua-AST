#!perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua program and test its execution results
# returned by the lua interpreter for the original source code and
# for the source code parsed to AST that is then serialized

# source of programs: http://lua-users.org/wiki/SampleCode

use v5.14.2;
use warnings;
use strict;

use Test::More;

BEGIN {
    my $stderr;
    eval
    {
        my $luav = "lua -v";
        # run $luav capturing STDERR (per perlfaq8)
        use IPC::Open3;
        use File::Spec;
        my $in = '';
        open(NULL, ">", File::Spec->devnull);
        my $pid = open3($in, ">&NULL", \*PH, $luav);
        my $stderr = <PH>;
        waitpid($pid, 0);
        # check lua and its version
        $stderr =~ /^Lua 5.1/ims;
    } or do
    {
        plan skip_all => "lua 5.1 not installed or can't be run (lua -v fails)";
    };
}

use File::Temp qw{ tempfile };
use Cwd qw();

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;


#   file name                       flags:  1 default: do nothing
#                                           2 reparse with diagnostics
#                                           3 reparse and show ast
#                                           4 test stdout with like()
#                                           5 stderr is expected -- test stdout anyway
#                                           6 print name of temporary lua file
#                                           7 todo skip
my %lua_files = qw{

    lua-tests/coroutine.lua         1

    lua5.1-tests/api.lua            1
    lua5.1-tests/attrib.lua         1
    lua5.1-tests/big.lua            5
    lua5.1-tests/calls.lua          1
    lua5.1-tests/checktable.lua     1
    lua5.1-tests/closure.lua        1
    lua5.1-tests/code.lua           1
    lua5.1-tests/constructs.lua     1
    lua5.1-tests/db.lua             1
    lua5.1-tests/errors.lua         1
    lua5.1-tests/events.lua         1
    lua5.1-tests/files.lua          4
    lua5.1-tests/gc.lua             1
    lua5.1-tests/literals.lua       1
    lua5.1-tests/locals.lua         1
    lua5.1-tests/main.lua           1
    lua5.1-tests/math.lua           1
    lua5.1-tests/nextvar.lua        1
    lua5.1-tests/pm.lua             1
    lua5.1-tests/sort.lua           4
    lua5.1-tests/strings.lua        1
    lua5.1-tests/vararg.lua         1
    lua5.1-tests/verybig.lua        1
};

# current dir
my $pwd = Cwd::cwd();

# shell script run lua interpreter on ast serialized to tokens
my $run_lua_test = 'run_lua_test.sh';
# prepend t if running under prove
$run_lua_test = 't/' . $run_lua_test unless $pwd =~ m{ /t$ }x;

# this is used below to silence "Deep recursion warning ... on tokens()"
# todo: check if the recursion is really deep
my $DOWARN = 1;
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN } }

LUA_FILE:
    for my $lua_fn (sort keys %lua_files){

        # get flags
        my $flag = $lua_files{$lua_fn};
TODO: {
        todo_skip "$lua_fn parses, but runs incorrectly", 1  if $flag == 7;
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
$DOWARN = 0; # see above
        my $parsed_lua_source = $p->fmt($ast);
$DOWARN = 1;
        my $lua_file = whip_up_lua_file( $parsed_lua_source );
        diag "Serialized AST is in $lua_file file" if $flag == 6;
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
        # file parses and runs, test its output
        if ($flag == 4){
            # turn $expected_stdout to a regex and test against it
            if ( $lua_fn =~ m{ lua5.1-tests/sort.lua$ }x ){
                $expected_stdout =~ s{[\d\.]+}{[\\d\\.]+}gx;
                like $stdout, qr/$expected_stdout/, $lua_fn;
                next LUA_FILE;
            }
            elsif ( $lua_fn =~ m{ lua5.1-tests/files.lua$ }x ){
                $expected_stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
                $expected_stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
                $stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
                $stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
                is $stdout, $expected_stdout, $lua_fn;
                next LUA_FILE;
            }
        }
        is $stdout, $expected_stdout, $lua_fn;
}

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


