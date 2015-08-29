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
    errors.lua
    error-gamedev.lua
};

my $p = MarpaX::Languages::Lua::AST->new;

# file
for my $lua_file (@lua_files){

    $lua_file = q{./t/} . $lua_file if $ENV{HARNESS_ACTIVE};

    my $lua_src = slurp_file( qq{$lua_file} );

    diag $lua_file unless $ENV{HARNESS_ACTIVE};

    if ( $lua_file eq q{errors.lua} ){
        my $errors = [
            [  'if n == 0',
              'gif n == 0',
              q{} ],
            [ '  else',
              '  els',
              q{} ],
        ];
        for my $error (@$errors){
            my $lua_src_err = $lua_src;
            $lua_src_err =~ s/\Q$error->[0]\E/$error->[1]/;
        SKIP: {
                skip "unimplemented", 1;
                my $ast = $p->parse( $lua_src_err );
                ok(0);
            }
        }
    }
    else{
        SKIP: {
                skip "unimplemented", 1;
                my $ast = $p->parse( $lua_src );
                ok(0);
            }
    }
}

my $snippets = [
    [
        q{ function and(a, b) return a and b end },
        'keyword used as identifer'
    ],
    [
        qq{ r=\nfunc(1,b)},
        "line break before '(' in a function call"
    ],
    [   # http://forums.mudlet.org/viewtopic.php?f=9&t=2901
        q{if pilgrim = "off" then echo("Pilgrim trigger off")},
    ],
    [   # http://community.playstarbound.com/threads/weird-lua-syntax-snippet.74812/
        q{stuff = world.itemDropQuery(objectPos, 5, order="nearest")},
    ],
    [   # https://github.com/mschuldt/configs/blob/master/lisp/flycheck/test/resources/checkers/lua-syntax-snippet.lua
        q{print "oh no; print "hello world" -- "},
    ],
    # todo: fix endless recursion in Lua::AST::Error module for 2 below cases
#    [
#        # http://stackoverflow.com/questions/17626855/my-if-then-else-end-statement-is-failing-in-lua-how-can-i-fix-it
#        q|{ "quit", if os.getenv("DE") == "gnome" then os.execute("/usr/bin/gnome-session-quit") else awesome.quit end }|,
#    ],
#    [
#        # http://stackoverflow.com/questions/25121020/lua-email-syntax-snippet
#        q{mail(technicalte@gmail.com, testSubject, testMailBody)},
#    ],
];
for my $snippet (@$snippets){
    my ($lua_src, $desc) = @{ $snippet };
    $desc //= '';
    diag $lua_src unless $ENV{HARNESS_ACTIVE};
    eval { my $ast = $p->parse( $lua_src ) };
    TODO: {
        todo_skip "'$desc' error not caught yet", 1 if $desc =~ /line break/;

        ok $@, 'parse error' . ( $desc ? ':' : '' ) . $desc;
    }
}

done_testing();
