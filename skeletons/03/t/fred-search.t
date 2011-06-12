#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use_ok('MyBlog::Schema');

our $db_filename = 't/var/test.db';
unlink $db_filename;

my $schema = MyBlog::Schema->connect("dbi:SQLite:$db_filename");

my @realfreds = qw/Fred_1 Fred_2 Fred_3/;
foreach my $user (@realfreds) {
    $shema->resultset('User')->create( {
        username => $user,
        realname => $user,
        password => 'whatever',
        email => 'fred@blogs.net',
                                       });
}

do 'script/fred_search.pl';

ok(main->can('fred_search'), 'Found function called "fred_search"');

my @freds = fred_search();
is_deeply(\@freds, \@realfreds, 'Got all the real freds');

done_testing;
