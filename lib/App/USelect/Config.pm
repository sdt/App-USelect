package App::USelect::Config;
use strict;
use warnings;

# ABSTRACT: Config class for uselect
# VERSION

use Config::Tiny            ();
use File::HomeDir           ();
use File::Spec              ();
use Hash::Merge::Simple     ();

my $default_config = {
    '_' => {

    },

    'colorscheme/mono' => {
        cursor_selected         =>  'bold,reverse',
        cursor_unselected       =>  'reverse',
        selectable_selected     =>  'bold',
        selectable_unselected   =>  'default',
        unselectable            =>  'default',
        status                  =>  'bold',
        help                    =>  'default',
    },

    'colorscheme/color' => {
        cursor_selected         =>  'yellow,blue',
        cursor_unselected       =>  'white,blue',
        selectable_selected     =>  'yellow',
        selectable_unselected   =>  'white,bold',
        unselectable            =>  'white',
        status                  =>  'green',
        help                    =>  'default',
    },

    'colorscheme/solarized' => {
        cursor_selected         =>  'green,base02',
        cursor_unselected       =>  'base1,base02',
        selectable_selected     =>  'green',
        selectable_unselected   =>  'base0',
        unselectable            =>  'base01',
        status                  =>  'base1,base02',
        help                    =>  'default',
    },
};

my $config;

sub reset {
    $config = undef;
}

sub get {
    return $config if ($config);

    my $config_file = exists $ENV{USELECTRC}
        ? $ENV{USELECTRC}
        : File::Spec->catdir(File::HomeDir->my_home, '.uselectrc');

    my $user_config = Config::Tiny->read($config_file);
    $config = Hash::Merge::Simple::merge($default_config, $user_config);

    return $config;
}

1;

__END__

=head1 FUNCTIONS

=head2 get

Load the config and return as a hash-of-hashes. Config is cached between calls,
use C<reset> to clear the cache.

Uses L<Config::Tiny> to read the config.

The following locations are tried in order until one succeeds.

=over

=item * $ENV{USELECTRC}

=item * ~/.uselectrc

=back

=head2 reset

Clear the cached config so that the next call to C<get> will return a fresh
config.

=cut
