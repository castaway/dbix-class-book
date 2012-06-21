#!/usr/bin/env perl
use strict;
use warnings;

use Authen::Passphrase::SaltedDigest;
use Test::More;
use_ok('MyBlog::Schema');

package Test::ResultSet;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
__PACKAGE__->mk_group_accessors('simple' => qw/method_calls/);

sub new {
    my ($self, @args) = @_;
    $self->method_calls({});
    $self->next::method(@args);
}

## Count how many times search is called
sub search {
    my ($self, @args) = @_;
    $self->method_calls->{search}++;
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
            {  title => 'Post 4', post => 'Post 4 content' },
            {  title => 'Post 3', post => 'Post 3 content' },
            {  title => 'Post 2', post => 'Post 2 content' },
            {  title => 'Post 1', post => 'Post 1 content' },
            {  title => 'Post 5', post => 'Post 5 content' },
            {  title => 'Post 6', post => 'Post 6 content' },
            ],
    },
                                ]);

### 1) Posts by fred in order
## Your code goes here:
my $ordered_rs;


## Your code end
is($users_rs->method_calls->{search}, 1, 'Called "search" just once');
is($ordered_rs->count, 6, 'Found 6 posts');
foreach my $i (1..6) {
    my $row = $ordered_rs->next;
    ok($row->isa('MyBlog::Schema::Result::Post'), 'Result isa Post object');
    is($row->title, "Post $i", "Post $i returned in order");
}

## 2) 2nd page of posts by fred, 2 per page
## Your code goes here:
my $ordered_page_rs;


## Your code end
is($users_rs->method_calls->{search}, 2, 'Called "search" a second time');
is($ordered_page_rs->count, 2, 'Found  page-worth of posts (2)');
foreach my $i (3,4) {
    my $row = $ordered_rs->next;
    ok($row->isa('MyBlog::Schema::Result::Post'), 'Result isa Post object');
    is($row->title, "Post $i", "Post $i returned in order");
}

done_testing;
