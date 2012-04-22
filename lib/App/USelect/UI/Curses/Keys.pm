package App::USelect::UI::Curses::Keys;
use strict;
use warnings;

# ABSTRACT: Key handling for curses UI
# VERSION

use Curses qw( KEY_UP KEY_DOWN KEY_NPAGE KEY_PPAGE );

use parent 'Exporter';
our @EXPORT_OK = qw(
    esc enter up down pgup pgdn ctrl key_name
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub esc     { chr(27)   }
sub enter   { "\n"      }
sub up      { KEY_UP    }
sub down    { KEY_DOWN  }
sub pgup    { KEY_PPAGE }
sub pgdn    { KEY_NPAGE }

sub ctrl {
    my ($char) = @_;
    return chr(ord($char) - ord('a') + 1);
}

my %key_name = (
    ( map { ctrl($_) => '^' . uc($_) } 'a'..'z' ),

    esc()           => 'ESC',
    enter()         => 'ENTER',
    KEY_UP()        => 'UP',
    KEY_DOWN()      => 'DOWN',
    KEY_NPAGE()     => 'PGDN',
    KEY_PPAGE()     => 'PGUP',
    ' '             => 'SPACE',
);

sub key_name {
    my $key = shift;
    my $name = $key_name{$key};
    return $name ? $name : $key;
}

1;
__END__
=pod

=head1 FUNCTIONS

=head2 key_name( $keycode )

Converts a keycode back to a string name.

=head2 ctrl( $key )

Converts a key (eg. d) into its corresponding control-key keycode.

=head1 KEYCODE CONSTANTS

=over

=item esc

=item enter

=item up

=item down

=item pgup

=item pgdn

=item ctrl

=item key_name

=back

=cut
