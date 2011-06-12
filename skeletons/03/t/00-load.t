#!perl -T

use Test::More;

BEGIN {
    use_ok( 'MyBlog::Schema' ) || print "Bail out!
";
}

diag( "Testing MyBlog::Schema $MyBlog::Schema::VERSION, Perl $], $^X" );
done_testing(1)
