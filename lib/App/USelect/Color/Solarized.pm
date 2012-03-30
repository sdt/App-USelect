package App::USelect::Color::Solarized;

# ABSTRACT: Solarized colors for uselect
# VERSION

use Modern::Perl;

use App::USelect::Color::Curses qw( curses_color );
use Curses qw(
    A_BOLD COLOR_BLACK COLOR_WHITE
    COLOR_RED COLOR_YELLOW COLOR_GREEN COLOR_CYAN COLOR_BLUE COLOR_MAGENTA
);

use parent 'Exporter';

our @EXPORT_OK = qw( solarized_color );

# Use solarized color names
my %solarized_color_table = (
    base03    => [ COLOR_BLACK,   A_BOLD ],
    base02    => [ COLOR_BLACK           ],
    base01    => [ COLOR_GREEN,   A_BOLD ],
    base00    => [ COLOR_YELLOW,  A_BOLD ],
    base0     => [ COLOR_BLUE,    A_BOLD ],
    base1     => [ COLOR_CYAN,    A_BOLD ],
    base2     => [ COLOR_WHITE           ],
    base3     => [ COLOR_WHITE,   A_BOLD ],
    yellow    => [ COLOR_YELLOW          ],
    orange    => [ COLOR_RED,     A_BOLD ],
    red       => [ COLOR_RED             ],
    magenta   => [ COLOR_MAGENTA         ],
    violet    => [ COLOR_MAGENTA, A_BOLD ],
    blue      => [ COLOR_BLUE            ],
    cyan      => [ COLOR_CYAN            ],
    green     => [ COLOR_GREEN           ],
    transp    => [ -1                    ],
);

my $colors = join('|', keys %solarized_color_table);
my $scolor_regex = qr{^ ( $colors ) / ( $colors ) $}x;

sub solarized_color {
    my ($scolor) = @_;

    my ($sfg, $sbg) = ($scolor =~ $scolor_regex)
        or die "Unknown color string $scolor";

    my ($fgc, $fga) = @{ $solarized_color_table{$sfg} };
    my ($bgc, $bga) = @{ $solarized_color_table{$sbg} };

    die "Cannot use $sbg as a background color" if $bga;

    my $attr = curses_color($fgc, $bgc);
    $attr |= $fga if $fga;
    return $attr;
}

1;
