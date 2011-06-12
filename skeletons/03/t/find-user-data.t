#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use_ok('MyBlog::Schema');

our $db_filename = 't/var/test.db';
unlink $db_filename;

do 'script/insert_user.pl';
do 'script/get_fred.pl';

ok(main->can('get_fred'), 'Found function called "get_fred"');

my $schema = MyBlog::Schema->connect("dbi:SQLite:$db_filename");
my $firstuser = $schema->resultset('User')->find({ id => 1 });
isa_ok($firstuser, 'DBIx::Class::Row', 'Got a row object from the db');

my $fred = get_fred();
isa_ok($fred, 'MyBlog::Schema::Result::User', 'get_fred returned a User object');

is($fred->username, 'fredbloggs', 'get_fred returned fredbloggs');

done_testing;
