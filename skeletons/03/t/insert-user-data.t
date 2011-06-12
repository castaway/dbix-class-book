#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use_ok('MyBlog::Schema');

our $db_filename = 't/var/test.db';
unlink $db_filename;

## Assuming the script returns / ends with the created user object?
my $user = do 'script/insert_user.pl';

my $schema = MyBlog::Schema->connect("dbi:SQLite:$db_filename");

my $firstuser = $schema->resultset('User')->find({ id => 1 });
isa_ok($firstuser, 'DBIx::Class::Row', 'Created a user');

is($firstuser->username, 'fredbloggs', 'User is named fredbloggs');

is($schema->resultset('User')->count(), 1, 'Inserted exactly one user');

done_testing;
