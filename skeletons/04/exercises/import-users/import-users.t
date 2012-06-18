#!/usr/bin/env perl
use strict;
use warnings;

use Text::xSV;

use Test::More;
use_ok('MyBlog::Schema');

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();
    
my $csv = Text::xSV->new();
$csv->load_file('t/data/multiple-users.csv');
$csv->read_header();

my $users_rs = $schema->resultset('User');
while ($csv->get_row()) {
    my $row = $csv->extract_hash();
    
    ## Your code goes here!

    $users_rs->create({
        realname => $row->{realname},
        username => $row->{username},
        email    => $row->{email},
        password => Authen::Passphrase::SaltedDigest->new(
            algorithm => "SHA-1", 
            salt_random => 20, 
            passphrase=> $row->{password},
            ),
    });

    ## End your code
}

## Tests:
    
is($schema->resultset('User')->count, 2, 'Two users exist in the database'));
my $janet = $schema->resultset('User')->find({ username => 'janet' });
ok($janet, 'Found Janet');
is($janet->email, 'janet@bloggs.com', 'Janet has the correct email address');
my $dan = $schema->resultset('User')->find({ username => 'dan' });
ok($dan, 'Found Dan');
ok($dan->password->match('sillypassword'), "Got Dan's password right");
