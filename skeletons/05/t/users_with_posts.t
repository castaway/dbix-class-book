#!/usr/bin/env perl
use strict;
use warnings;

use Authen::Passphrase::SaltedDigest;
use Test::More;
use_ok('MyBlog::Schema');

package Test::ResultSet;
use strict;
use warnings;

use base 'DBIx::Class::Helper::ResultSet';
__PACKAGE__->mk_group_accessors('simple' => qw/method_calls/);

sub new {
    my ($self, @args) = @_;
    $self->method_calls({});
    $self->next::method(@args);
}

## Count how many times except is called
sub except {
    my ($self, @args) = @_;
    $self->method_calls->{except}++;
    $self->next::method(@args);
}

package main;

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();
foreach my $source ($schema->sources) {
    $schema->source($source)->resultset_class('Test::ResultSet');
}
my $users_rs = $schema->resultset('User');
## Add some initial data:
my @users = $users_rs->populate([
    {
        realname => 'Fred Bloggs',
        username => 'fred',
        password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'mypass'),
        email    => 'fred@bloggs.com',
        posts    => [
            {  title => 'Post 1', post => 'Post 1 content', created_date => DateTime->new(year => 2012, month => 01, day => 01) },
            {  title => 'Post 2', post => 'Post 2 content', created_date => DateTime->new(year => 2012, month => 01, day => 03) },
            ],
    },
    {
        realname => 'Joe Bloggs',
        username => 'joe',
        password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'sillypassword'),
        email    => 'joe@bloggs.com',
    },
    {
        realname => 'Jane Bloggs',
        username => 'jane',
        password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'sillypassword'),
        email    => 'jane@bloggs.com',
        posts    => [
            {  title => 'Post 3', post => 'Post 3 content', created_date => DateTime->new(year => 2012, month => 01, day => 05) },
            {  title => 'Post 4', post => 'Post 4 content', created_date => DateTime->new(year => 2012, month => 01, day => 07) },
            ],
    }
]
);

### Users and their earliest posts
## Your code goes here:
my $users_with_posts_rs;


## Your code end
is($users_rs->method_calls->{except}, 1, 'Called "except" just once');
is($$users_with_posts_rs->count, 2, 'Found 2 users');
my $row = $$users_with_posts_rs->next;
ok($row->isa('MyBlog::Schema::Result::User'), 'Found user objects');
ok($row->username eq 'fred' || $row->username eq 'jane', 
   'Found users with posts, 1st user');
$row = $earliest_rs->next;
ok($row->username eq 'fred' || $row->username eq 'jane',
   'Found users with posts, 2nd user');

done_testing;
