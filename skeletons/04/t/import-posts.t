#!/usr/bin/env perl
use strict;
use warnings;

use XML::Simple;
use Authen::Passphrase::SaltedDigest;

use Test::More;
use_ok('MyBlog::Schema');

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();

my $alice = $schema->resultset('Uesr')->create(
    {
        realname => 'Alice Bloggs', 
        username => 'alice', 
        password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred'), 
        email    => 'alice@bloggs.com',
    });

my $xml_posts = XMLIn('t/data/multiple-posts.xml');

foreach my $post_xml (@$xml_posts) {
    ## Your code goes here!

}

## Tests:

is($schema->resultset('Post')->count, 2, 'Two posts exist in the database');
my @posts = $alice->posts->all();

foreach my $post (@posts) {
    ok(
        $post->title eq 'In which Alice writes a blog post' ||
        $post->title eq "Alice's second blog post",
        'Got correct post title'
    );

   ok($post->post =~ /^This being a new blog/ ||
      $post->post =~ /^Alice ponders over life/,
      'Got correct post content');
}

