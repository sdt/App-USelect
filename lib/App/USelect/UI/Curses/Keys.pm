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
    $key_name{$_[0]} // $_[0]
}

1;
