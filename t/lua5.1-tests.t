#!perl
# Copyright 2015 Ruslan Shvedov

# take a lua file, from lua 5.1. test suite, roundtrip it through parser
# test roundtripped lua source vs. the original
# run roundtripped source with lua interpreter and test its execution results
# against those of the original source code

# lua sources for more tests can be found at http://lua-users.org/wiki/SampleCode

use 5.010;
use warnings;
use strict;

use Test::More;
use File::Spec;
use Test::Differences;

BEGIN {
    my $stderr;
    eval {
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
    } or do {
        plan skip_all => "lua 5.1 not installed or can't be run (lua -v fails)";
    };
}

use Cwd qw();

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;


#   file name                       flags:  1 default: do nothing
#                                           3 reparse and show ast
#                                           4 test stdout with like()
#                                           5 stderr is expected -- test stdout anyway
#                                           7 skip

# todo: move this and other in xt (author test)
#       as in http://elliotlovesperl.com/2009/11/24/explicitly-running-author-tests/
# If you have .pm files in your module's distribution
# that are used only for tests, put them in 't/lib' and add the line
#   use lib 't/lib';
# to each test's file.
#   ./xt/author - run when the tests are being run in an author's working copy
#   ./xt/smoke - run when the dist is being smoked (AUTOMATED_TESTING=1)
#   ./xt/release - run during "make disttest"
# -- http://perl-qa.hexten.net/wiki/index.php?title=Best_Practices_for_Testing

my %lua_files = qw{

    api.lua            1
    attrib.lua         1
    big.lua            5
    calls.lua          1
    checktable.lua     1
    closure.lua        1
    code.lua           1
    constructs.lua     1
    db.lua             1
    errors.lua         1
    events.lua         1
    files.lua          4
    gc.lua             1
    literals.lua       1
    locals.lua         1
    main.lua           1
    math.lua           1
    nextvar.lua        1
    pm.lua             1
    sort.lua           4
    strings.lua        1
    vararg.lua         1
    verybig.lua        1
};

# current dir
my $pwd = Cwd::cwd();

# shell script run lua interpreter on ast serialized to tokens
my $run_lua_test = $^O eq 'MSWin32' ? 'run_lua_test.bat' : 'run_lua_test.sh';

# prepend t if running under prove
my @dirs = File::Spec->splitdir( $pwd );
my $under_prove = $dirs[-1] eq 't';
$run_lua_test = File::Spec->catfile( '.', 't', $run_lua_test ) unless $under_prove;
$run_lua_test = './' . $run_lua_test unless $^O eq 'MSWin32';

# test suite dirs
my $lua_test_suite_dir = 'lua5.1-tests';
my $lua_ast_test_suite_dir = 'lua5.1-ast-tests';

# silence "Deep recursion on"
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] unless $_[0] =~ /Deep recursion|Redundant argument in sprintf/ } };

LUA_FILE:
for my $lua_fn (sort keys %lua_files)
{
    # get flags
    my $flag = $lua_files{$lua_fn};

    # prepend test suite path unless a file is from another dir
    my $lua_ts_fn = File::Spec->catfile( $lua_test_suite_dir, $lua_fn );
    my $lua_ast_ts_fn = File::Spec->catfile( $lua_ast_test_suite_dir, $lua_fn );

    # prepend t if running under prove
    $lua_ts_fn = File::Spec->catfile( 't', $lua_ts_fn ) unless $under_prove;
    $lua_ast_ts_fn = File::Spec->catfile( 't', $lua_ast_ts_fn ) unless $under_prove;

    # As an example, consider the following code:
    my $lua_slurp = slurp_file( $lua_ts_fn );

    # When you run it, it produces the following output:
    my $expected_stdout = slurp_file( qq{$lua_ts_fn.out} );

    # roundtrip lua source
    my $roundtripped = $p->roundtrip($lua_slurp);
    is $roundtripped, $lua_slurp, "roundtripped $lua_ts_fn";

    # write roundtripped lua source to file
    whip_up_lua_file( $lua_ast_ts_fn, $roundtripped );

    # run lua file
    system("$run_lua_test $lua_ast_test_suite_dir $lua_fn 1>$lua_ast_ts_fn.stdout 2>$lua_ast_ts_fn.stderr");
    my ($stdout, $stderr) = map { slurp_file($_) } qq{$lua_ast_ts_fn.stdout}, qq{$lua_ast_ts_fn.stderr};

    # test output of roundtripped lua source with regexes
    if ($flag == 4)
    {
        # turn $expected_stdout to a regex and test against it
        if ( $lua_ts_fn =~ m{ sort.lua$ }x )
        {
            $expected_stdout =~ s{[\d\.]+}{[\\d\\.]+}gx;
            like $stdout, qr/$expected_stdout/, $lua_ts_fn;
            next LUA_FILE;
        }
        elsif ( $lua_ts_fn =~ m{ files.lua$ }x )
        {
            $expected_stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
            $expected_stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
            $stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
            $stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
            eq_or_diff $stdout, $expected_stdout, $lua_ts_fn;
            next LUA_FILE;
        }
    }

    # test output of roundtripped lua source as is
    eq_or_diff $stdout, $expected_stdout, $lua_ts_fn;

} ## for my $lua_fn (@lua_files){

done_testing();

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_fn, $lua_text) = @_;
    open my $fh, ">$lua_fn" or die "Can't create $lua_fn: $@.";
    say $fh $lua_text;
    close $fh;
}

