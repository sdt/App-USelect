package App::USelect::Color::Curses;

# ABSTRACT: Curses color-pair handling
# VERSION

use Modern::Perl;
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
