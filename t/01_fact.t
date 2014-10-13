#!perl
# Copyright 2014 Ruslan Shvedov

#
use v5.14.2;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# fact is lua's hello world -- this nonexecutable snippet
# will be tested by serialized ast comparison

my $input = <<END;
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

local function get()
  return v
end

print("enter a number:")
a = io.read("*number")        -- read a number
print(fact(a))
END

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse( $input );
unless (defined $ast){
    $p->parse( $input, { trace_terminals => 1 } );
    fail "Can't parse:\n$input";
}

# dump tree first
#say $p->serialize( $ast );

# format it later
my $fmt = $p->fmt( {
    ast => $ast,
    indent => 2,
    linelength => 78,
} );
#say $fmt;

my $expected_fmt = $input;
$expected_fmt =~ s/        -- read a number//;

is $fmt, $expected_fmt, 'lua code formatting';

done_testing();

