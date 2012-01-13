Chapter 5 - Further queries and helpers
=======================================

Chapter summary
---------------

This chapter expands on the basic operations shown in
[Chapter 4](04-Creating-Reading-Updating-Deleteing.html) by showing
how to do much more complex searches across the data. It also
demonstrates a few useful external modules available on CPAN and how
to do transactions and locking.

Pre-requisites
--------------

You should understand basic DBIx::Class use as shown in Chapter 4. We
will be giving code examples and tests using Test::More so you should
be familiar with Perl unit testing. The database we are using is
provided as an SQL file you can import into an
[SQLite database](http://search.cpan.org/dist/DBD-SQLite) to get
started.

[Download code](http://dbix-class.org/book/code/chapter05.zip)

Introduction
------------

In Chapter 4 we covered simple queries to fetch single rows from the
database, change and delete the data. Now we're going to use the
database to prefilter, sort, slice and dice the data for us, as this
is more efficient than fetching the data a piece at a time and doing
the work in Perl. DBIx::Class allows you to use Perl data structures
and methods to describe the intended query, and then optimises the
result into SQL. The main method we will need is `search`, with
various conditions and attributes.

## Recap, simple search queries

In Chapter 4 we searched for a set of users with rude or unwanted
words as their realnames, in order to remove them from the
database. This uses the `search` method and filters the results using
the `-like` comparison operator. 

`LIKE` is an SQL keyword used to compare data against simple wildcard
matching. `%` matches any number of characters, `_` matches a single
character. LIKE is defined as being case-insensitive in the SQL
standard, it is not implemented as such in all databases (PostgreSQL
is one example, it provides the LIKE and ILIKE keywords).

The two arguments to `search` are a set of conditions, and a set of
attributes. The conditions supply the filters to apply to the data,
the attributes add grouping, sorting and joining and more.

The other non-obvious subtlety here is that an arrayref in the value of
a condition hashref produces a set of ORed conditions, whereas the
hashref layer produces ANDed conditions.  This functionality is provided by the [SQL::Abstract module](http://metacpan.org/dist/SQL-Abstract).

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @badwords = ('john', 'joe', 'joseph');
    my $badusers_rs = $users_rs->search({
      realname => [ map { { 'like' => "%$_%"} } @badwords ],
    });

This query is sent to the database as this SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users
    WHERE me.realname LIKE '%john%' OR me.realname LIKE '%joe%' OR me.realname LIKE '%joseph%'
    
We'll get the results by grabbing a Row object at a time from the
ResultSet using the `next` method.

    while(my $user = $users_rs->next) {
      print $user->realname;
    }

## Choosing data to fetch

A default `search` will fetch all the columns defined in the
ResultSource that we're using for the search. Note that the
ResultSource itself does not need to define all the columns in a
database table, if you don't need to use some of them in your
application at all, you can leave them out of the Schema.

You may want to reduce the set of columns fetched from the database,
useful if one of them is a large blob type column and you don't always
need the data. The `columns` attribute replaces the default list with
the supplied arrayref of column names.

To fetch the user data without the password column:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_minus_passwd_rs = $schema->resultset('User')->search({
    }, {
      columns     => [ qw/me.id me.realname me.username me.email/ ],
    });

To better express the "all but the password column" we can fetch the
list of defined columns from the ResultSource, and subtract the
column:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User');
    my $users_minus_passwd_rs = $users_rs->search({
    }, {
      columns     => [ grep { $_ ne 'password' } ($users_rs->resultsource->columns) ],
    });
    
To get the SQL:

    SELECT me.id, me.realname, me.username, me.email
    FROM users me

The SQL `SELECT` clause can contain many other things, for example
functions such as `length`. To output a function and its arguments,
use a hashref in the `columns` attribute, we can also add new columns
to the default set using the `+columns` attribute.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User');
    my $users_plus_emaillen_rs = $users_rs->search({
    }, {
      '+columns'     => [ { 'userlen' => { length => 'username' } }],
    });

Which produces the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email, length(email)
    FROM users me

The outer level of hashref has the new internal column name as its
key. This gives you a way to access to resulting value. Note that
we'll need to use the `get_column` method to fetch the data as it does
not create a new accessor method on the resulting Row object.

    while (my $user = $users_plus_emaillen_rs->next) {
      print "User: ", $user->username, " has email length ", $user->get_column('emaillen'), " \n";
    }

Later on in the
[section on joining](#joining-filtering-and-grouping-on-related-data)
we'll show how to include data from related tables, and select entire
sets of related data in the same single query.

## Your turn, fetch posts with no "post" column data

  ## TODO

## Ordering and Reducing

The SQL language provides a number of ways to manipulate the data
before building rows out of the results. Doing this work in the
database instead of your Perl code is much more efficient.

First we look at ordering and reducing. We can sort results based on any
data values in the database, or manipulations of those values. The
type of sorting we get depends on the data types in the columns. We
can fetch all our users ordered by their usernames for display:

The `order_by` attribute is used to output the SQL keywords `ORDER BY`. 
Sorting can be done either ascending, with `-asc`, or descending
with `-desc`.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User')->search({
    }, {
      order_by => { '-desc' => ['me.username'] }
    });

We get the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    ORDER BY me.username DESC

The results from our loop over the results are now sorted by username,
no need to sort further in Perl or your templating system.

Now that we have rows in a known order, we can also reduce the set of
results to a top ten, or to a page worth of results, so that we only
fetch data we'll actually use. There are unfortunately many different
implementations of ways to reduce the number of rows returned by an
SQL query. Luckily DBIx::Class abstracts these away for you, providing
a single `rows` attribute that is converted to the correct keyword
when the query is run.

The first 'page' of 10 usernames to display:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User')->search({
    }, {
      order_by => { '-desc' => ['me.username'] },
      rows     => 10,
    });

On SQLite and MySQL we get the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    ORDER BY me.username DESC
    LIMIT 10

Which returns a maximum of 10 rows. If the unlimited query would
return less than 10 rows, then we just get those, no error is thrown.

SQL even provides a way to return a specified set of results from
within the entire set, so we can fetch a second page of results
precisely. DBIx::Class implements this by providing the `page`
attribute to select which page of results to return, this defaults to
1 if not supplied.

The second 'page' of 10 usernames to display:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User')->search({
    }, {
      order_by => { '-desc' => ['me.username'] },
      rows     => 10,
      page     => 2,
    });

On SQLite and MySQL we get the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    ORDER BY me.username DESC
    OFFSET 10
    LIMIT 10

## Your turn, fetch and filter ordered posts

Another good use of sorting is to sort things by datetime values to
display them in the order that they happened. Now combine search
conditions with attributes, and find: 1) all the posts by the user
**fredbloggs** in the order they were created, 2) the 2nd "page" of 2
posts per page.

This test can be found in the file **ordered_posts.t**.

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
    is($ordered_page_rs->count, 2, 'Found 
    foreach my $i (3,4) {
      my $row = $ordered_rs->next;
      ok($row->isa('MyBlog::Schema::Result::Post'), 'Result isa Post object');
      is($row->title, "Post $i", "Post $i returned in order");
    }

    done_testing;

    

## Joining, Filtering and Grouping on related data

We've seen how to create related rows, either singly or together with
other data, now we can look at how to query or fetch all that data
without making multiple trips to the database. The SQL keyword `JOIN`
can be produced using the attribute `join` and providing it a list of
related resultsources to join on. The joined tables can be accessed in
the search conditions and other clauses, using the name of the
relationship.

Here is a more concrete example, we can fetch a list of our users,
together with the number of posts that they have written.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_post_count_rs = $schema->resultset('User')->search({
    }, {
      '+columns' => [ { post_count => { count => 'posts.title' }],
      group_by   => [ $users_rs->resultsource->columns ],
      join       => ['posts'],
    });

We get the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email, count(posts.id)
    FROM users me
    LEFT JOIN posts ON me.id = posts.id
    GROUP BY me.id, me.realname, me.username, me.password, me.email

In order to use aggregate functions such as `count` in our SQL, we
also need to provide a `GROUP BY` clause to tell the database what the
count applies to. In this case we've grouped on all the `users`
columns, so we want a count of unique posts.id values per user. The
`group_by` attribute outputs the `GROUP BY` clause.

NB: The SQL standard says that GROUP BY should include all the queried
(`SELECT`ed) columns which are not being aggregated. Some databases
enforce this, some, such as MySQL, do not by default.


## Your turn, find the earliest post of each user

The `sum`, `avg`, `min`, and `max` aggregate functions work just like
the `count` function. Use this information to create a query that will
return the earliest (minimum `created_date`) of each user in the
database.

This test can be found in the file **earliest_posts.t**.

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
    },
    
    ### Users and their earliest posts
    ## Your code goes here:
    my $earliest_rs;


    ## Your code end
    is($users_rs->method_calls->{search}, 1, 'Called "search" just once');
    is($earliest_rs->count, 2, 'Found 2 users');
    my $row = $earliest_rs->next;
    ok($row->isa('MyBlog::Schema::Result::User'), 'Found user objects');
    ok($row->username eq 'fred' && $row->created_date->ymd eq '2012-01-01'
       || $row->username eq 'joe' && $row->created_date->ymd eq '2012-01-05',
    'Found earliest post, 1st user');
    $row = $earliest_rs->next;
    ok($row->username eq 'fred' && $row->created_date->ymd eq '2012-01-01'
       || $row->username eq 'joe' && $row->created_date->ymd eq '2012-01-05',
    'Found earliest post, 2nd user');

    done_testing;

## Fetching data from related tables

Joins can also be used to fetch multiple tables worth of data in the
same query, eliminating extra trips to the database. To illustrate, if
we fetch a user object and the first page worth of posts written by
that user, we generate the following:

    my $user = $schema->resultset('User')->find({ username => 'fred' });
    
    # Output fred's posts:
    my $posts = $fred->posts->search({}, { rows => 10, page => 1 });
    while (my $post = $fred->next) {
      print $post->title, " ", $post->post, "\n";
    }

The SQL generated:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    WHERE me.username = 'fred'
    
    SELECT me.id, me.user_id, me.created_date, me.title, me.post
    FROM posts
    WHERE me.user_id = 1
    LIMIT 10

Or worse, we fetch a page posts from different users for our
frontpage, and then fetch the user details, we get a query per user:

    my $posts_rs = $schema->resultset('Post')->search({}, { rows => 10, page => 1 });
    
    # Output all posts:
    while (my $post = $posts_rs->next) {
      print $post->user->username, " ", $post->title, " ", $post->post, "\n";
    }

The SQL generated:

    SELECT me.id, me.user_id, me.created_date, me.title, me.post
    FROM posts
    LIMIT 10

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    WHERE me.id = 1
    
    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    WHERE me.id = 2
    
    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    WHERE me.id = 2
    
    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users me
    WHERE me.id = 1

.. and so one, one for each post, even if some are written by the same
user. Of course we could reduce it by caching the user objects so that we
don't refetch duplicates.

We can reduce this set of queries (in either case), by using the
`prefetch` attribute to our initial query, which asks it to include
all the listed relations into the query.

Note, this currently does not work with multiple `has_many` type
relations at the same level, as decoding the resulting data back into
objects is tricky.

So for users and the first page of posts:

    my $user = $schema->resultset('User')->search(
    { 
      username => 'fred',
    },
    {
      prefetch => ['posts'],
      rows     => 10,
      page     => 1,
    });
    
    # Output fred's posts:
    my $posts = $fred->posts->search({}, { rows => 10, page => 1 });
    while (my $post = $fred->next) {
      print $post->title, " ", $post->post, "\n";
    }

Resulting in:

    SELECT me.id, me.realname, me.username, me.password, me.email, posts.id, posts.user_id, posts.created_date, posts.title, posts.post
    FROM users me
    LEFT JOIN posts ON me.id = posts.user_id
    WHERE me.username = 'fred'
    LIMIT 10

And for the page of posts with users:

    my $posts_rs = $schema->resultset('Post')->search(
    {},
    { 
      prefetch => [ 'user' ],
      rows => 10, 
      page => 1,
    });
    
    # Output all posts:
    while (my $post = $posts_rs->next) {
      print $post->user->username, " ", $post->title, " ", $post->post, "\n";
    }

The SQL generated:

    SELECT me.id, me.user_id, me.created_date, me.title, me.post, user.id, user.realname, user.username, user.password, user.email
    FROM posts
    JOIN user ON me.id = posts.user_id
    LIMIT 10

## Clever stuff: having, subselects, ...

There are several more commonly used SQL clauses which we haven't mentioned yet

## More on ResultSets and chaining

As mentioned in Chapter 4, ResultSets are used to store the conditions
to create database queries. This means that a ResultSet object can be
passed around and used to collect conditions and attributes, before
running the query.

Suppose we wanted to later check for unwanted words in realnames of
users from certain email domains, we can extend the condition later by
calling `search` again on the returned ResultSet.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @badwords = ('john', 'joe', 'joseph');
    my $badusers_rs = $users_rs->search({
      realname => [ map { { 'like' => "%$_%"} } @badwords ],
    });
    
    ## And later ...
    
    my $filtered_badwords_rs = $badwords_rs->search({
      email => { '-like' => '%@example.com' }
    });

Our query will now be:

    SELECT me.id, me.realname, me.username, me.password, me.email
    FROM users
    WHERE me.realname LIKE '%john%' OR me.realname LIKE '%joe%' OR me.realname LIKE '%joseph%' AND email LIKE '%@example.com';


`search` does not change the ResultSet it was called on, just returns
a new ResultSet object with the conditions merged into the existing
set.

Conditions and attributes are either merged or replaced according to
these rules.

* Search conditions - merged into existing using AND.

* `where` attribute - merged using AND.

* `having` attribute - merged using AND.

* `join`, `prefetch`, `+select`, `+as` are merged into existing attributes.

All other attributes replaced with the newly supplied values.

## Helpers on CPAN (union ... )

## Querying/defining views, stored procedures

## Transactions, locks etc

