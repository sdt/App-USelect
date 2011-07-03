package App::USelect::UI;
use Moose::Role;

requires qw/ end draw draw_help update command_keys /;

use Modern::Perl;

has width => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

has height => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

1;
