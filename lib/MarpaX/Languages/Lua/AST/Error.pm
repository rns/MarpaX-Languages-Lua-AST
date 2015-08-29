package MarpaX::Languages::Lua::AST::Error;

use v5.10.1;
use strict;
use warnings;

=pod Overview

    my $err = MarpaX::Languages::Lua::AST::Error->new($recce, $parser->{grammar});
    crock $err->sprint();

    optionally treat ambiguity as an error

    take input span from the last completed range and reparse with trace_terminals => 1

    error reporting and recovery based on (1) longest completed span,
    (2) longest predicted span, and mapping between (1) and (2)

    -   to define

        what’s expected (terminals and non-terminals),
        what’s found and error location
        after and before spans

        error reporing format
            line:column: expected: <filtered expected terminals>,
            found: <rejected token name (value)>, explanation

        messages like
            end is needed to close 'if' at line ...

    -   to group expected terminal by category (rule LHS or general):
        addition, multiplication ... = operator or binop

=cut

sub new{
    my ($class, $recce, $grammar) = @_;
    my $err = {};
    $err->{recce} = $recce;
    $err->{grammar} = $grammar;
    bless $err, $class;
}

# returns completed spans at current position reverse-sorted by position
sub longest_spans {
    my ($err) = @_;

    my $grammar = $err->{grammar};
    my $recce = $err->{recce};

    my %unique_lhs = map {
        my ($lhs) = $grammar->rule_expand($_);
        $grammar->symbol_name($lhs) => 1
    } $grammar->rule_ids();

#    warn MarpaX::AST::dumper(\%unicorns);
    return
        # LHS literal start-length line:column
        map {
            "$_->[2] '" . $recce->literal($_->[0], $_->[1]) . "'" .
                ' @' . "$_->[0]-$_->[1]" .
                ', ' . join( ':', $recce->line_column($_->[0]) ),
        }
        # sort by start
        sort { $b->[0] <=> $a->[0] }
            # skip non-completed spans
            grep { @$_ == 3 }
                # check if there is a completed span for LHS and append LHS
                # [ $start, $length, LHS ]
                map { [ $recce->last_completed_span( $_ ), $_ ] }
                    keys %unique_lhs;

}

sub traverse_to_terminal{
    my ($err, $recce,
        $terminals_expected, $terminals_expected_at_dot_position,
        $dot_rule_id, $dot_position, $dot_position_by_rule_id) = @_;

    my $grammar = $err->{grammar};

    my (undef, @rhs_ids) = $grammar->rule_expand( $dot_rule_id );
    my $dot_symbol_id = $rhs_ids[ $dot_position ];
    my $dot_symbol = $grammar->symbol_name( $rhs_ids[ $dot_position ] );

    if (exists $terminals_expected->{ $dot_symbol }){
        warn "terminal: $dot_symbol";
        push @{ $terminals_expected_at_dot_position->{ $dot_symbol } },
            $grammar->rule_name($dot_rule_id);
    }
    else{
        # traverse dot rules until expected terminal in dot position
        # or there is a cycle
        warn "\n# rule id:\n", $dot_rule_id, ', ', $dot_symbol;

        # find rule with $lhs_id equal to $dot_symbol_id
        my @next_dot_rule_ids = grep {
            my ($lhs_id, @rhs_ids) = $grammar->rule_expand( $_ );
            $lhs_id == $dot_symbol_id
        } $grammar->rule_ids();

        for my $next_dot_rule_id (@next_dot_rule_ids){
            my $next_dot_position = $dot_position_by_rule_id->{ $next_dot_rule_id };
            my ($lhs_id, @rhs_ids) = $grammar->rule_expand( $next_dot_rule_id );
            my $next_dot_symbol_id = $rhs_ids[ $next_dot_position ];
            my $next_dot_symbol = $grammar->symbol_name( $next_dot_symbol_id );
            next if $next_dot_symbol eq $dot_symbol;

            if (exists $terminals_expected->{ $next_dot_symbol }){
                warn "terminal: $next_dot_symbol" ;
                push @{ $terminals_expected_at_dot_position->{ $next_dot_symbol } },
                    $grammar->rule_name($next_dot_rule_id);
            }
            else {
                warn "# next dot rule:\n", $next_dot_rule_id, ': ', $next_dot_position;
                warn $next_dot_symbol_id, ': ', $next_dot_symbol;
                $err->traverse_to_terminal(
                    $recce,
                    $terminals_expected, $terminals_expected_at_dot_position,
                    $next_dot_rule_id, $next_dot_position, $dot_position_by_rule_id
                );
            }
        }

    }
}

sub show{
    my ($err) = @_;

    my $grammar = $err->{grammar};
    my $recce = $err->{recce};

    warn "Showing expected terminals:\n", join ', ', @{ $recce->terminals_expected() };
    warn "Showing progress:\n", $recce->show_progress();
    return;

    # todo: implement Overview above
    my $report_items = $recce->progress();

    my $rule_id_by_dot_position = {};

    my $dot_position_by_rule_id = {};
    for my $report_item ( @{$report_items} ) {
        my ($rule_id, $dot_position, $origin) = @{$report_item};
        next unless $dot_position >= 0;

        $dot_position_by_rule_id->{$rule_id} = $dot_position;

        my $rule_name = $grammar->rule_name( $rule_id );
        my (undef, @rhs_ids) = $grammar->rule_expand( $rule_id );
        my $rhs_length = @rhs_ids;

#        warn join ', ', qq{$rule_id:$rule_name}, $dot_position, $origin, $rhs_length;

        push @{ $rule_id_by_dot_position->{$dot_position} }, $rule_id;
    }

#    warn MarpaX::AST::dumper( $dot_position_by_rule_id );

    my $farthest_dot_position = (sort { $b <=> $a } keys %{ $rule_id_by_dot_position })[0];

#    warn "farthest dot position: ", $farthest_dot_position;

    # traverse $farthest_dot_rules to reach terminals
    my $terminals_expected = { map { $_ => 1 } @{ $recce->terminals_expected() } };
    my $terminals_expected_at_dot_position = {};

#    warn "# rules at dot position:\n",
#        join ', ', map { $grammar->rule_name($_) }
#            @{ $rule_id_by_dot_position->{ $farthest_dot_position } };

    for my $farthest_dot_rule_id (@{ $rule_id_by_dot_position->{ $farthest_dot_position } } ){

        $err->traverse_to_terminal(
            $recce,
            $terminals_expected, $terminals_expected_at_dot_position,
            $farthest_dot_rule_id, $farthest_dot_position, $dot_position_by_rule_id
        );

    }

    warn MarpaX::AST::dumper( $terminals_expected_at_dot_position );
}

1;
