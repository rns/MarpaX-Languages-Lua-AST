#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua program and test its execution results
# returned by the lua interpreter for the original source code and
# for the source code parsed to AST that is then serialized

use 5.010;
use warnings;
use strict;

use Test::More;

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

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse($input);
say $p->serialize( $ast );

done_testing();

