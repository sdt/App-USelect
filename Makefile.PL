use inc::Module::Install;

name     'App-USelect';
all_from 'lib/App/USelect.pm';
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

