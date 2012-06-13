#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use_ok('MyBlog::Schema');

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();
## Your code goes here!


## Tests: 
my $users_rs = $schema->resultset('User')->search({ email => 'alice@bloggs.com' });
is($users_rs->count, 1, 'Found exactly one alice user');

my $alice = $users_rs->next();
is($alice->id, 1, "Magically discovered Alice's PK value");
is($alice->username, 'alice', 'Alice has boring ole username of "alice"');
ok($alice->password->match('aliceandfred'), "Guessed Alice's password, woot!");
like($alice->realname, qr/^Alice/, 'Yup, Alice is named Alice');

done_testing;
