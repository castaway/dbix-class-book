#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Authen::Passphrase::SaltedDigest;
use_ok('MyBlog::Schema');

package Test::ResultSet;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
__PACKAGE__->mk_group_accessors('simple' => qw/method_calls/);

sub new {
    my ($class, @args) = @_;
    my $self = $class->next::method(@args);
    $self->method_calls({});

    return $self;
}

sub create {
    my ($self, @args) = @_;
    $self->method_calls->{create}++;
    $self->next::method(@args);
}

sub find_or_create {
    my ($self, @args) = @_;
    $self->method_calls->{find_or_create}++;
    $self->next::method(@args);
}

sub update_or_create {
    my ($self, @args) = @_;
    $self->method_calls->{update_or_create}++;
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

### Multi-create test, add joebloggs and his posts here:
## Your code goes here!

my $joe = $users_rs->create({
    username => 'joebloggs',
    email => 'joe@bloggs.com',
    realname => 'Joe Bloggs',
    password => Authen::Passphrase::SaltedDigest->new(
        algorithm => "SHA-1", 
        salt_random => 20,
        passphrase => 'joepass'),
    posts => [
        { 
            title => "Joe's Post",
            post => "Joe wrote something!",
        },
    ],
});

## Your code end
is($users_rs->method_calls->{create}, 1, 'Called "create" just once');
ok($users_rs->find({ username => 'joebloggs' }), 'joebloggs was created');
ok($schema->resultset('Post')->search(
       { 'user.username' => 'joebloggs'},
       { join => 'user' }
   )->count >= 2, 'Got at least 2 posts by joebloggs');

## find_or_create test, add alicebloggs here with existance check
## Your code goes here:
    

my $alice = $users_rs->find_or_create({
    username => 'alicebloggs',
    email => 'alice@bloggs.com',
    realname => 'Alice Bloggs',
    password => Authen::Passphrase::SaltedDigest->new(
        algorithm => "SHA-1", 
        salt_random => 20,
        passphrase => 'alicepass',
        )});
    
## Your code end
is($users_rs->method_calls->{find_or_create}, 1, 'Called "find_or_create" just once');
ok($users_rs->find({ username => 'alicebloggs' }), 'alicebloggs was created');

my $fred = $users_rs->create({ 
    realname => 'Fred Bloggs',
    username => 'fredbloggs',
    password => Authen::Passphrase::SaltedDigest->new(
        algorithm => "SHA-1", 
        salt_random => 20,
        passphrase => 'mypass',
        ),
        email => 'fred@bloggs.com',
});   
## update_or_create test, update fred's password here:
## Your code goes here:

my $fred_update = $users_rs->update_or_create({
    username => 'fredbloggs',
    password => Authen::Passphrase::SaltedDigest->new(
        algorithm => "SHA-1", 
        salt_random => 20,
        passphrase => 'fredsnewpass',
        )}, { key => 'username_idx' });

## Your code end
is($users_rs->method_calls->{update_or_create}, 1, 'Called "update_or_create" just once');
my $fred = $users_rs->find({ username => 'fredbloggs' });
ok($fred, 'got fredbloggs');
if($fred) {
    ok($fred->password->match('freddy'), 'Updated password');
}
    
done_testing;
 


