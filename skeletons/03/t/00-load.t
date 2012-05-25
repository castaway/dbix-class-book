#!/usr/bin/env perl 

use Test::More;

BEGIN {
    use_ok( 'MyBlog::Schema' ) || print "Bail out!\n";
}

diag( "Testing MyBlog::Schema $MyBlog::Schema::VERSION, Perl $], $^X" );
done_testing(1)
