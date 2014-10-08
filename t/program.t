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
use File::Temp qw{ tempfile };

use MarpaX::Languages::Lua::AST;

# this is the first examples to be tested against the serialized tree string
# other will need to use lua interpreter
my $input = <<END;
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

print("enter a number:")
a = io.read("*number")        -- read a number
print(fact(a))
END

# As an example, consider the following code:
my $coroutine = slurp_lua_file( "other-lua-tests/coroutine.lua" );

# When you run it, it produces the following output:
my $expected_stdout = qq{
co-body\t1\t10
foo\t2
main\ttrue\t4
co-body\tr
main\ttrue\t11\t-9
co-body\tx\ty
main\ttrue\t10\tend
main\tfalse\tcannot resume dead coroutine
};
$expected_stdout =~ s/^\s+//;

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse($coroutine);

# write ast serialized to tokens to a temporary file
my $lua_file = whip_up_lua_file( $p->tokens($ast) );

use Test::Output;
stdout_is(sub { system 'lua', $lua_file }, $expected_stdout, "lus coroutine script test");

sub slurp_lua_file{
    my ($fn) = @_;
    open my $fh, "<", $fn or die "Can't open $fn: $@.";
    binmode( $fh, ":utf8" );
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_text) = @_;
    my ($fh, $filename) = tempfile();
    binmode( $fh, ":utf8" );
    say $fh $lua_text;
    close $fh;
    return $filename;
}

done_testing();

