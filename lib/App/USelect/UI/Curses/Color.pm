package App::USelect::UI::Curses::Color;
use strict;
use warnings;

# ABSTRACT: Cached on-demand color pairs for curses
# VERSION

use Curses qw(
    init_pair COLOR_PAIR
);

use parent 'Exporter';
our @EXPORT_OK = qw( curses_color );

# Cache and init colors on demand
my %curses_color_table;
sub curses_color {
    my ($fg, $bg) = @_;
    my $key = "$fg/$bg";

    if (exists $curses_color_table{$key}) {
        return $curses_color_table{$key};
    }

    my $index = 1 + keys %curses_color_table;
    init_pair($index, $fg, $bg);

    return $curses_color_table{$key} = COLOR_PAIR($index);
}

1;

__END__
=pod

=head1 FUNCTIONS

=head2 curses_color ( $fg, $bg )

If this color pair has been created before, returns the COLOR_PAIR value for it.
Otherwise, creates a new pair with init_pair and COLOR_PAIR.

=cut
