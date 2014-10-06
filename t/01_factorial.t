#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

use 5.010;
use warnings;
use strict;

use Test::More;

my $input = <<END;
-- defines a factorial function
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
say $p->serialize( $p->parse($input) );


done_testing();
