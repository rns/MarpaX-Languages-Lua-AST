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
my $coroutine = q{
     function foo (a)
       print("foo", a)
       return coroutine.yield(2*a)
     end

     co = coroutine.create(function (a,b)
           print("co-body", a, b)
           local r = foo(a+1)
           print("co-body", r)
           local r, s = coroutine.yield(a+b, a-b)
           print("co-body", r, s)
           return b, "end"
     end)

     print("main", coroutine.resume(co, 1, 10))
     print("main", coroutine.resume(co, "r"))
     print("main", coroutine.resume(co, "x", "y"))
     print("main", coroutine.resume(co, "x", "y"))
};

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
my ($fh, $filename) = tempfile();
binmode( $fh, ":utf8" );
say $fh $p->tokens($ast);
close $fh;

use Test::Output;
stdout_is(sub { system 'lua', $filename }, $expected_stdout, "lus coroutine script test");

done_testing();

