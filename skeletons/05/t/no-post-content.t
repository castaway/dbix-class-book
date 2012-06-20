#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use_ok('MyBlog::Schema');

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();

## insert some test data
my $users_rs = $schema->resultset('User');

$users_rs->create({
    realname => 'John Smith',
    username => 'johnsmith',
    password => Authen::Passphrase::SaltedDigest->new(
        algorithm => "SHA-1", 
        salt_random => 20,
        passphrase => 'johnspass',
        ),
        email => 'john.smith@example.com',
        
        posts => [
            {
                title => "John's first post",
                post  => 'Tap, tap, is this thing on?',
                created_date => DateTime->now,
            },
            {
                title => "John's second post",
                post => "Anybody out there?",
                created_date => DateTime->now,
            }
        ],
                  });    

my $posts_no_content_rs;
## Your code goes here!

## End your code

## Tests:   
is($posts_no_content_rs->count, 2, 'Found both posts');

my $first_post = $posts_no_content_rs->next();
my %post_data = $first_post->get_columns;
is(scalar keys %post_data, 2, "Got two columns in the first post");
ok($first_post->title, 'Got a title on the first post');
ok($first_post->created_date, "Got a created_date on the first post");
ok(!$first_post->post, 'No post content on first post');

done_testing;
