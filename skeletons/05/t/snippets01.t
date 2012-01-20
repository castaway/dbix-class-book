#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Data::Dumper;
use MyBlog::Schema;

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();

my $posts_rs = $schema->resultset('Post')->search(
{},
{ 
    prefetch => [ 'user' ],
    rows => 10, 
    page => 1,
});

print Dumper($posts_rs->as_query), "\n";

# Output all posts:
while (my $post = $posts_rs->next) {
    print $post->user->username, " ", $post->title, " ", $post->post, "\n";
}

done_testing;
