#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

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
#say $p->serialize( $ast );

# read, parse, serialized to token stream and test execution
# of Lua function from after __END__

my $lua_fact;
BEGIN {
    $lua_fact = <<END;
-- defines a factorial function
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end
END
};

# lua source from a scalar initialized at compile time
use Inline Lua => $lua_fact;
my $n = 10;
my $expected_fact = fact($n);

sub lua_fact_tokens {
    my $p = MarpaX::Languages::Lua::AST->new;
    $p->tokens($p->parse($lua_fact))
}

# lua source from a ref to code returning ast of lua source
use Inline Lua => &lua_fact_tokens;
my $got_fact = fact($n);

is $got_fact, $expected_fact, "$n! from lua source and its ast serialized to tokens";

done_testing();

