#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

#
use 5.010;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# start testing external lexer from fact

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

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse( $input );
unless (defined $ast){
    $p->parse( $input, { trace_terminals => 1 } );
    fail "Can't parse:\n$input";
}

say "# lexing:\n", $input;
$p->read( undef, $input );

done_testing();

