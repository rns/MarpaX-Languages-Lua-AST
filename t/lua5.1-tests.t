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

# todo: drop tests running lua on roundtripped files

BEGIN {
    eval {
        open(PH, "lua -v 2>&1 1>" . File::Spec->devnull . "|");
        my $stderr = <PH>;
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

my %test_suite_files = qw{

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
my $test_suite_dir = 'lua5.1-tests';
my $roundtripped_test_suite_dir = 'lua5.1-roundtripped-tests';

# silence "Deep recursion on" warning
BEGIN { $SIG{'__WARN__'} =
    sub { warn @_ unless $_[0] =~ /Deep recursion|Redundant argument in sprintf/ }
};

TEST_SUITE_FILE: # henceforth, tsf
for my $tsf_name (sort keys %test_suite_files)
{
    # get flags
    my $flag = $test_suite_files{$tsf_name};

    # prepend test suite path unless a file is from another dir
    my $tsf = File::Spec->catfile( $test_suite_dir, $tsf_name );
    my $roundtripped_tsf = File::Spec->catfile( $roundtripped_test_suite_dir, $tsf_name );

    # prepend t if running under prove
    $tsf = File::Spec->catfile( 't', $tsf ) unless $under_prove;
    $roundtripped_tsf = File::Spec->catfile( 't', $roundtripped_tsf ) unless $under_prove;

    # As an example, consider the following code:
    my $slurped_tsf = slurp_file( $tsf );

    # When you run it, it produces the following output:
    my $expected_stdout = slurp_file( qq{$tsf.out} );

    # roundtrip lua source
    my $roundtripped = $p->roundtrip($slurped_tsf);
    is $roundtripped, $slurped_tsf, "roundtripped $tsf";

    # write roundtripped lua source to file
    whip_up_lua_file( $roundtripped_tsf, $roundtripped );

    # run lua file
    system("$run_lua_test $roundtripped_test_suite_dir $tsf_name 1>$roundtripped_tsf.stdout 2>$roundtripped_tsf.stderr");
    my ($stdout, $stderr) = map { slurp_file($_) } qq{$roundtripped_tsf.stdout}, qq{$roundtripped_tsf.stderr};

    # test output of roundtripped lua source with regexes
    if ($flag == 4)
    {
        # turn $expected_stdout to a regex and test against it
        if ( $tsf =~ m{ sort.lua$ }x )
        {
            $expected_stdout =~ s{[\d\.]+}{[\\d\\.]+}gx;
            like $stdout, qr/$expected_stdout/, $tsf;
            next TEST_SUITE_FILE;
        }
        elsif ( $tsf =~ m{ files.lua$ }x )
        {
            $expected_stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
            $expected_stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
            $stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
            $stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
            eq_or_diff $stdout, $expected_stdout, $tsf;
            next TEST_SUITE_FILE;
        }
    }

    # test output of roundtripped lua source as is
TODO: {
    todo_skip "$tsf doesn't run properly under cygwin's lua", 1
        if $tsf =~ m{ main.lua$ }x and $^O eq 'MSWin32';
    eq_or_diff $stdout, $expected_stdout, "stdout of $tsf";
}

} ## for my $tsf_name (@test_suite_files){

done_testing();

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($tsf_name, $lua_text) = @_;
    open my $fh, ">$tsf_name" or die "Can't create $tsf_name: $@.";
    say $fh $lua_text;
    close $fh;
}

