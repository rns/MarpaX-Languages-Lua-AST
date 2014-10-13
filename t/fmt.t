#!perl
# Copyright 2014 Ruslan Shvedov

#
use v5.14.2;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# fact is lua's hello world -- test formatter by comparing it with
# this nonexecutable snippet

my $lua_src = <<END;
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

function tcheck (t1, t2)
  table.remove(t1, 1)  -- remove code
  assert(table.getn(t1) == table.getn(t2))
  for i=1,table.getn(t1) do assert(t1[i] == t2[i]) end
end

print("enter a number:")
a = io.read("*number")        -- read a number
print(fact(a))
assert(not pcall(err_on_n, - - -n))
f,a = loadstring(f)();
END

my $p = MarpaX::Languages::Lua::AST->new;
my $ast = $p->parse( $lua_src );
unless (defined $ast){
    $p->parse( $lua_src, { trace_terminals => 1 } );
    fail "Can't parse:\n$lua_src";
}

# an ast dump is needed first at times
say $p->serialize( $ast );

my $fmt = $p->fmt( $ast, { indent => '  ' } );
say $fmt;

use Test::Differences 0.61;
#eq_or_diff $fmt, $lua_src, 'lua code formatting';

done_testing();

