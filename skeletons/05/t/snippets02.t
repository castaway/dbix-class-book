#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Data::Dumper;
use Authen::Passphrase::SaltedDigest;
use DateTime;
use MyBlog::Schema;

unlink 't/var/myblog.db';
my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
$schema->deploy();

my $users_rs = $schema->resultset('User');

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
        posts    => [
            {  title => 'Post 3', post => 'Post 3 content', created_date => DateTime->new(year => 2012, month => 01, day => 05) },
            {  title => 'Post 4', post => 'Post 4 content', created_date => DateTime->new(year => 2012, month => 01, day => 07) },
            ],
    }]);
         
my $post_rs = $schema->resultset('Post');
                                
my $title_rs = $post_rs->search(
    {},
    {
        'columns' => ['id', { search => \'title as search'} ,{ tablename => \'"Post" as tablename'}], 
    }
    );

my $content_rs = $post_rs->search(
    {},
    {
        'columns' => ['id', { search => \'post as search'}, { tablename => \'"Post" as tablename'} ],
    }
    );

my $username_rs = $users_rs->search(
    {},
    {
        'columns' => [ 'id', { search => \'username as search'} , { tablename => \'"User" as tablename'}],
    }
    );

my $realname_rs= $users_rs->search(
    {},
    {
        'columns' => [ 'id', { search => \'realname as search'}, { tablename => \'"User" as tablename'}],
    }
    );

my $search_term = 'fred';

$title_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
$content_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
$username_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
$realname_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

my $datasearch_rs = $username_rs->union($realname_rs, $title_rs, $content_rs)->search({
    'search' => { '-like' => $search_term },
});


$datasearch_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
while( my $match = $datasearch_rs->next) {
    ## Enough data to create a link to the user/post of the match
    
    print "Found: $match->{tablename}, $match->{id}, value: $match->{search}\n";
}


done_testing;
