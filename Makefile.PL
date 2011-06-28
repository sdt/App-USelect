use inc::Module::Install;

name     'App-PiSelect';
all_from 'lib/App/PiSelect.pm';
author   q{Stephen Thirlwall <sdt@dr.com>};
license  'perl';

build_requires 'Test::More';

requires        'autodie';
requires        'Curses';
requires        'List::Util';
requires        'Modern::Perl';
requires        'Moose';
requires        'Scalar::Util';

auto_install;

WriteAll;

