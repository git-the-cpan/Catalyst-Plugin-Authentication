use strict;
use warnings;
use inc::Module::Install 0.87;
use Module::Install::AuthorRequires;
use Module::Install::AuthorTests;

if ( $Module::Install::AUTHOR ) {
    system( 'pod2text lib/Catalyst/Plugin/Authentication.pm > README' )
        and die;
}

perl_version '5.008001';

name 'Catalyst-Plugin-Authentication';
all_from 'lib/Catalyst/Plugin/Authentication.pm';

requires 'Catalyst::Runtime';
requires 'Class::Inspector';
requires 'MRO::Compat';
requires 'Catalyst::Plugin::Session' => '0.10';
requires 'Moose';
requires 'MooseX::Emulate::Class::Accessor::Fast';
requires 'namespace::clean';


test_requires 'Test::More' => '0.88';
test_requires 'Test::Exception';
test_requires 'Class::MOP';
test_requires 'Moose';

author_requires 'Test::Pod' => '1.14';
author_requires 'Test::Pod::Coverage' => '1.04';
author_requires 'Test::NoTabs';
author_requires 'Test::WWW::Mechanize::Catalyst';
author_requires 'Catalyst::Plugin::Session';
author_requires 'Catalyst::Plugin::Session::State::Cookie';
author_requires 'Digest::SHA1';

author_tests 't/author';

auto_install;
resources repository => 'git://git.shadowcat.co.uk/catagits/Catalyst-Plugin-Authentication.git';

WriteAll;
