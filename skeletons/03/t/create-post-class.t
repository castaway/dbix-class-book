#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use_ok('MyBlog::Schema');

my $db = 't/var/test.db';
unlink $db;

my $schema = MyBlog::Schema->connect("dbi:SQLite:$db");
$schema->deploy();

## New Post source must exist;
ok($schema->source('Post'), 'Post source exists in schema');

## Not running source tests if not there, will have failed above already
SKIP: {
    my $source = $schema->source('Post');
    skip "Source Post not found", 7 if(!$source);

    ## Expected component
    isa_ok($schema->source('Post'), 'DBIx::Class::InflateColumn::DateTime', 'DateTime component has been added');

    ## Expected columns:
    foreach my $col (qw/id user_id created_date title post/) {
        ok($schema->source('Post')->has_column($col), "Found expected Post column '$col'");
    }
    is_deeply([$schema->source('Post')->primary_columns()], ['id'], 'Found expected primary key col "id" in Post source');


    ## Expected relationships:
    ok($schema->source('Post')->relationship_info('user'), 'Found a relationship named "user" in the Post source');
    is($schema->source('Post')->relationship_info('user')->{attrs}{accessor}, 'single', 'User relationship in Post source is a single accessor type');
}

done_testing(10);
