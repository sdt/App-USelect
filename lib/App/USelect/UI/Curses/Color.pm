package App::USelect::UI::Curses::Color;
use strict;
use warnings;

# ABSTRACT: Cached on-demand color pairs for curses
# VERSION

use Carp qw( croak );
use Curses qw(
    init_pair COLOR_PAIR

    A_BLINK A_BOLD A_DIM A_REVERSE A_STANDOUT A_UNDERLINE

    COLOR_BLACK COLOR_WHITE COLOR_RED COLOR_YELLOW
    COLOR_GREEN COLOR_CYAN COLOR_BLUE COLOR_MAGENTA
);


use parent 'Exporter';
our @EXPORT_OK = qw( get_color );

# Cache and init colors on demand
my %curses_colorpair_table;
sub _color_pair {
    my ($fg, $bg) = @_;
    my $key = "$fg/$bg";

    if (exists $curses_colorpair_table{$key}) {
        return $curses_colorpair_table{$key};
    }

    my $index = 1 + keys %curses_colorpair_table;
    init_pair($index, $fg, $bg);

    return $curses_colorpair_table{$key} = COLOR_PAIR($index);
}

sub COLOR_DEFAULT { -1 };

my %color_names = (

    black       => COLOR_BLACK,
    white       => COLOR_WHITE,
    red         => COLOR_RED,
    yellow      => COLOR_YELLOW,
    green       => COLOR_GREEN,
    cyan        => COLOR_CYAN,
    blue        => COLOR_BLUE,
    magenta     => COLOR_MAGENTA,

    # Solarized colors can be used FG or BG
    base02      => COLOR_BLACK,
    base2       => COLOR_WHITE,

    default     => COLOR_DEFAULT,
);

my %attr_names = (
    blink       => A_BLINK,
    bold        => A_BOLD,
    dim         => A_DIM,
    reverse     => A_REVERSE,
    standout    => A_STANDOUT,
    underline   => A_UNDERLINE,
);

my %solarized_fg_names = (
    # These also need A_BOLD and so cannot be used as BG colors
    base03      => COLOR_BLACK,
    base01      => COLOR_GREEN,
    base00      => COLOR_YELLOW,
    base0       => COLOR_BLUE,
    base1       => COLOR_CYAN,
    base3       => COLOR_WHITE,
    orange      => COLOR_RED,
    violet      => COLOR_MAGENTA,
);

sub _parse_color {
    my ($name) = @_;

    my @components = split(/,/, $name);

    my @colors;
    my $attr = 0;

    for my $c (@components) {
        my $lc = lc $c;
        $lc =~ s/^\s+//;
        $lc =~ s/\s+$//;
        if (exists $color_names{$lc}) {
            push(@colors, $color_names{$lc});
        }
        elsif (exists $attr_names{$lc}) {
            $attr |= $attr_names{$lc};
        }
        elsif (exists $solarized_fg_names{$lc}) {
            croak "Solarized color \"$c\" cannot be used as a background color"
                if (@colors > 0);
            push(@colors, $solarized_fg_names{$lc});
            $attr |= A_BOLD;
        }
        else {
            croak "Unknown \"$c\" in \"$name\"";
        }
    }
    croak "Too many colors in \"$name\""
        if @colors > 2;

    my $fg = @colors > 0 ? $colors[0] : COLOR_DEFAULT;
    my $bg = @colors > 1 ? $colors[1] : COLOR_DEFAULT;

    return ($fg, $bg, $attr);
}

my %color_cache;
sub get_color {
    my ($name) = @_;

    my $color = $color_cache{$name};
    if (! defined $color) {
        my ($fg, $bg, $attr) = _parse_color($name);
        $color_cache{$name} = $color = _color_pair($fg, $bg) | $attr;
    }
    return $color;
}

1;

__END__
=pod

=head1 FUNCTIONS

=head2 get_color ( $string )

Parses a color specification of the form fg,bg,attr, creates a curses color
pair and returns the final curses attribute value.

=head3 Colors
    black blue cyan green magenta red white yellow

=head3 Attributes
    blink bold dim reverse standout underline

=head3 Solarized Colors (see L<http://ethanschoonover.com/solarized>)
    base03 base02 base01 base00 base0 base1 base2 base3
    yellow orange red magenta violet blue cyan green

=cut
