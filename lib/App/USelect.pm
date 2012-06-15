package App::USelect;
use strict;
use warnings;

# ABSTRACT: main application class.
# VERSION

use App::USelect::Selector;
use App::USelect::UI::Curses;
use Getopt::Long qw( GetOptionsFromArray );
use Try::Tiny;

use parent 'Exporter';
our @EXPORT_OK = qw( run );

sub run {
    my ($opt, $argv) = @_;

    my $select_sub = _make_select_sub($opt)
        or return 4;

    chomp(my @lines = @$argv ? @$argv : <STDIN>);
    my $selector = App::USelect::Selector->new(
            text          => \@lines,
            is_selectable => $select_sub,
        );

    if ($selector->selectable_lines == 0) {
        print STDERR "No selectable lines\n";
        return 2;
    }

    my $ui = App::USelect::UI::Curses->new(
            selector => $selector,
            message => $opt->{message},
            select_mode => $opt->{single_select} ? 'single' : 'multi',
        );
    $ui->run();

    if ($ui->has_errors) {
        print STDERR 'ERROR:', $ui->errors, "\n";
        return 3;
    }
    print($_->text, "\n") for $selector->selected_lines;
    return ($selector->selected_lines == 0);
}

#-------------------------------------------------------------------------------

sub _make_select_sub {
    my ($opt) = @_;

    # Try evaluating the user code on its own first - we can tailor a better
    # error message this way.
    {
        local $_ = ''; # silence warnings about $_ being uninitialised
        no strict 'vars';
        eval($opt->{select_code}); ## no critic ProhibitStringyEval
    }
    if ($@) {
        # Attempt to replace the default error message with something more
        # contextual. Not sure how robust this is.
        my $msg = $@;
        $msg =~ s/at \(eval \d+\) line \d+/in '$opt->{select_code}'/g;
        print STDERR $msg;
        return;
    }

    if (not $opt->{include_blanks}) {
        $opt->{select_code} = '/\S/ and (' . $opt->{select_code} . ')';
    }

    my $select_sub = eval(q<no strict 'vars'; sub { $_ = shift; > . $opt->{select_code} . '}'); ## no critic ProhibitStringyEval
    if ($@) {
        print STDERR $@;
        return;
    }

    return $select_sub;
}

1;
__END__

=pod

=head1 FUNCTIONS

=head2 run( \%options, \@ARGV )

Runs the application

=cut
