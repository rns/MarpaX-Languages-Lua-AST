#!perl
# Copyright 2014 Ruslan Shvedov

#
use v5.14.2;
use warnings;
use strict;

use Test::More;
use Test::Differences 0.61;
use File::Temp qw{ tempfile };

use MarpaX::Languages::Lua::LUIF;

my $p = MarpaX::Languages::Lua::LUIF->new();

# test lua bnf
my @tests = (
[ 'LUIF design note',
# LUIF
q{
g = grammar ()
  local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
},
# expected lua
q{g = function ()
  local x = 1
  a = { 'b', 'c' }
  w = { 'x', 'y', 'z' }
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2, n do
    x = x * i
  end
end
}
],

[ 'Marpa::R2 synopsis with default name',
# LUIF
q{
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression exp Expression
 || Expression mul Expression
  | Expression div Expression
 || Expression add Expression
  | Expression sub Expression
},
# expected lua
<<EOS
default_grammar = {
  Script = { 'Expression',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  },
  Expression = { 'Number' },
  Expression = { 'left_paren', 'Expression', 'right_paren',
    fields = {
      priority = '|'
    }
  },
  Expression = { 'Expression', 'exp', 'Expression',
    fields = {
      priority = '||'
    }
  },
  Expression = { 'Expression', 'mul', 'Expression',
    fields = {
      priority = '||'
    }
  },
  Expression = { 'Expression', 'div', 'Expression',
    fields = {
      priority = '|'
    }
  },
  Expression = { 'Expression', 'add', 'Expression',
    fields = {
      priority = '||'
    }
  },
  Expression = { 'Expression', 'sub', 'Expression',
    fields = {
      priority = '|'
    }
  },
}
EOS
],

[ 'Marpa::R2 synopsys with actions in Lua functions',
# LUIF
q{
Marpa_R2_synopsys_actions = grammar ()
  Script ::= Expression+ % comma
  Expression ::=
    Number
    | left_paren Expression right_paren
   || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
   || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
    | Expression op_div Expression, action (e1, e2) return e1 / e2 end
   || Expression op_add Expression, action (e1, e2) return e1 + e2 end
    | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
end
},
# expected lua
<<EOS
Marpa_R2_synopsys_actions = function ()
  Script = { 'Expression',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  }
  Expression = { 'Number' }
  Expression = { 'left_paren', 'Expression', 'right_paren',
    fields = {
      priority = '|'
    }
  }
  Expression = { 'Expression', 'op_exp', 'Expression',
    fields = {
      action = function (e1, e2) return e1 ^ e2 end,
      priority = '||'
    }
  }
  Expression = { 'Expression', 'op_mul', 'Expression',
    fields = {
      action = function (e1, e2) return e1 * e2 end,
      priority = '||'
    }
  }
  Expression = { 'Expression', 'op_div', 'Expression',
    fields = {
      action = function (e1, e2) return e1 / e2 end,
      priority = '|'
    }
  }
  Expression = { 'Expression', 'op_add', 'Expression',
    fields = {
      action = function (e1, e2) return e1 + e2 end,
      priority = '||'
    }
  }
  Expression = { 'Expression', 'op_sub', 'Expression',
    fields = {
      action = function (e1, e2) return e1 - e2 end,
      priority = '|'
    }
  }
end
EOS
],

[ 'fatal: both grammar() and BNF rules are used, BNF after grammar()',
# LUIF
q{
g = grammar ()
local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
 || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
  | Expression op_div Expression, action (e1, e2) return e1 / e2 end
 || Expression op_add Expression, action (e1, e2) return e1 + e2 end
  | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
},
q{
...
}
],

[ 'fatal: both grammar() and BNF rules are used, BNF before grammar()',
# LUIF
q{
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
 || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
  | Expression op_div Expression, action (e1, e2) return e1 / e2 end
 || Expression op_add Expression, action (e1, e2) return e1 + e2 end
  | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
g = grammar ()
local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
},
q{
...
}
],
#[ '...', q{...}, q{...} ],
);

for my $test (@tests){
    my ($name, $bnf_extended_lua, $expected_lua_bnf ) = @$test;
    my $ast = $p->parse( $bnf_extended_lua );
    unless (defined $ast){
        fail "Can't parse:\n$bnf_extended_lua";
        next;
    }
    unless ($name =~ /^fatal/){
#        my $lua_bnf_ast = $p->serialize( $ast );
#        say $lua_bnf_ast;
        my $lua_bnf = $p->fmt( $ast );
#        say $lua_bnf;

        # test by string matching
        eq_or_diff $lua_bnf, $expected_lua_bnf, $name;

        # test by lua compilation
        my ($fh, $filename) = tempfile();
        binmode( $fh, ":utf8" );
        say $fh $lua_bnf;
        my $rc = system "lua $filename";
        is $rc, 0, "compile with lua";
    }
    else{
        eval { $p->fmt( $ast ) };
        ok $@, $@;
    }

}

done_testing();

