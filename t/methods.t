#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::Languages::Lua::AST';

# silence "Deep recursion on" warning
$SIG{'__WARN__'} = sub { warn $_[0] unless $_[0] =~ /Deep recursion/ };

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

my @lua_files = qw{
    methods.lua
    MarpaX-Languages-Lua-Parser/echo.lua
    lua5.1-tests/constructs.lua
};

for my $lua_file (@lua_files){

    $lua_file = q{./t/} . $lua_file if $ENV{HARNESS_ACTIVE};

    my $lua_src = slurp_file( qq{$lua_file} );
    my $p = MarpaX::Languages::Lua::AST->new;
    my $ast = $p->parse( $lua_src );
    $ast = MarpaX::AST->new( $ast, { CHILDREN_START => 3 } );

    # line_column()
#    warn MarpaX::AST::dumper($p->{start_to_line_column});
    my $expected_start_to_line_column = {};
    for my $start (keys %{ $p->{start_to_line_column} }){
        my $chunk = substr $lua_src, 0, $start;
        my $expected_line = $chunk =~ tr/\n// + 1;
        my $expected_column = length ($chunk) - rindex ($chunk, "\n");
        $expected_start_to_line_column->{$start} = [ $expected_line, $expected_column ];
    }
    is_deeply $expected_start_to_line_column, $p->{start_to_line_column}, "$lua_file: start to line, column";

}

done_testing();
