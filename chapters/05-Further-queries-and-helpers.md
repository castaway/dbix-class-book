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

    

## Joining, Aggregating and Grouping on related data

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
      '+columns' => [ { post_count => { count => 'posts.title' } }],
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
    }
    ]);
    
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

## Filtering data after grouping

With [group_by](#joining-aggregating-and-grouping-on-related-data) and
various aggregation functions we can sum or count data across groups
of rows, if we want to then filter the results again, for example to
get only the groups whose COUNT is greater than a certain value, we
need to use the SQL keyword `HAVING`. To differentiate, the `WHERE`
clause applies before the grouping, and the `HAVING` clause applies
afterwards.

So to return all users that have at least one post:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_with_as_least_one_post_rs = $schema->resultset('User')->search({
    }, {
      '+columns' => [ { post_count => { count => 'posts.title',
                                        -as   => 'post_count',
                      }
                    ],
      group_by   => [ $users_rs->resultsource->columns ],
      join       => ['posts'],
      having     => [ { 'post_count' => { '>=' => 1 } } ],
    });

Note that we've added the `-as` argument to our `post_count` column,
this is required to output the SQL `AS` keyword, which is used to
alias the result of a function call or calculation. The alias can then
be used in subsequent clauses, such as the `HAVING` clause.

We get the SQL:

    SELECT me.id, me.realname, me.username, me.password, me.email, count(posts.id) as post_count
    FROM users me
    LEFT JOIN posts ON me.id = posts.id
    GROUP BY me.id, me.realname, me.username, me.password, me.email
    HAVING post_count <= 1

WARNING: If you get an error from your database here, and its Oracle
or MS SQL Server, then you will need to use different code. As these
databases do not parse/run the SQL in order, the `post_count` alias is
still unknown while parsing the `HAVING` clause. We need to repeat the
condition instead:

    my $users_with_as_least_one_post_rs = $schema->resultset('User')->search({
    }, {
      '+columns' => [ { post_count => { count => 'posts.title' },
                      }
                    ],
      group_by   => [ $users_rs->resultsource->columns ],
      join       => ['posts'],
      having     => \[ 'count(posts.id) >= ?', [ {} => 1 ] ],
    });

[%# This probably needs its own section somewhere.. ! %]
This is how to write literal SQL chunks in DBIx::Class. While DBIC is
quite clever, there will always be a need to support literal SQL
pieces for database specific functionality or similar. The
arrayref-reference contains the SQL string with `?` characters for
placeholders, and an arrayref for each of the values.

Which outputs:

    SELECT me.id, me.realname, me.username, me.password, me.email, count(posts.id)
    FROM users me
    LEFT JOIN posts ON me.id = posts.id
    GROUP BY me.id, me.realname, me.username, me.password, me.email
    HAVING count(posts.id) >= ?
    
Which is executed with the placeholders set to: (1)

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


## Extending search conditions and ResultSet chaining

As mentioned in Chapter 4, ResultSets are used to store the conditions
to create database queries. This means that a ResultSet object can be
passed around and used to collect conditions and attributes, before
running the query.

Suppose we're building a list of unwanted words to search for in
realnames of users, and then later filter the search to only certain
email domains, we can add to the condition later by calling `search`
again on the returned ResultSet. This returns a new ResultSet
containing the merged conditions.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    ## Add initial conditions ... 
    
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


To re-iterate, `search` does not change the ResultSet it was called
on, just returns a new ResultSet object with the conditions merged
into the existing set.

Conditions and attributes are either merged or replaced according to
these rules.

* Search conditions - merged into existing using AND.

* `where` attribute - merged using AND.

* `having` attribute - merged using AND.

* `join`, `prefetch`, `+columns`, `+select`, `+as` are merged into existing attributes.

All other attributes replaced with the newly supplied values.

You can always call `search` on an existing ResultSet to add or change
conditions or attributes, to extend the query.

## Preserving original conditions (subselects)

Extending queries can sometimes have unexpected results, suppose ... # need an example for this!

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    $users_rs->search({ some conds })->as_subselect_rs->search({ more filtering });

## Data set manipulation (and ResultSet extension)

The SQL language has a whole host of
[set operations](http://en.wikipedia.org/wiki/Set_operations_(SQL)) to
help manipulate results and make the database software do as much work
as possible for you. You may of course prefer to do these in Perl, its
up to you. DBIx::Class doesn't currently simplify the use of these
directly, however there is a module on CPAN which supplies them.

To use the `UNION`, `INTERSECT` and `EXCEPT` keywords, install the
[DBIx::Class::Helpers module from CPAN](http://metacpan.org/module/DBIx::Class::Helpers).

Using these constructs we can glue together the results of arbitrary
resultsets, for example of if we want to allow users to search for
either usernames or post titles (or contents), we can UNION together
several resultsets. Take care to select the same number of columns in
the resultsets.

To add new methods to our ResultSet classes, we will need to create
our own ResultSet subclass. This will simply inherit from the existing
default DBIx::Class::ResultSet class, and add the Helper
component. Put this in the `MyBlog/Schema/ResultSet/User.pm` file:

    package MyBlog::Schema::ResultSet::User;
    
    use strict;
    use warnings;
    
    use base 'DBIx::Class::ResultSet';

    __PACKAGE__->load_components(qw/Helper::ResultSet::SetOperations/);
    
    1;
    
Now we can use the Helper methods provided, first, create some
resultsets to query each of the fields we wish to search on:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $post_rs = $schema->resultset('Post');
    my $users_rs = $schema->resultset('User');
    
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


[%# may be able to remove this para at somepoint.. %] To ensure that
the resultset results will be consistant, the `union` code checks that
the `result_class` of its arguments are all the same. (See below) As
we're using different sources to `union` we set the result_class here:

    $title_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    $content_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    $username_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    $realname_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');


Then create the `union` and the actual search query:

    my $search_term = 'fred';
    my $datasearch_rs = $username_rs->union([$realname_rs, $title_rs, $content_rs])->search({
      'search' => { '-like' => $search_term },
    });

To actually get the results we need to introduce another new
technique, replacing the class that is used to create the Result
objects. In normal use this creates an instance of of your Result
class (which derives from DBIx::Class::Row). Using the Result class
for `User` here will not work as the names of our columns don't match
the columns defined in the class. DBIx::Class installs one alternative
Result class generator for you,
`DBIx::Class::ResultClass::HashRefInflator`, which causes the methods
`next`, `find` and `all` to return a hashref of the results instead of
an object. We add it to the ResultSet using `result_class`.

    $datasearch_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    
    while( my $match = $datasearch_rs->next) {
      ## Enough data to create a link to the user/post of the match
      
      print "Found: $match->{source}, $match->{id}, value: $match->{search}\n";
    }

The SQL we get looks like this:

    SELECT me.id, me.search, me.tablename 
    FROM (
      SELECT me.id, username as search, "User" as tablename 
      FROM users me 
      UNION 
      SELECT me.id, realname as search, "User" as tablename 
      FROM users me 
      UNION 
      SELECT me.id, title as search, "Post" as tablename 
      FROM posts me 
      UNION 
      SELECT me.id, post as search, "Post" as tablename 
      FROM posts me) me 
    WHERE ( search LIKE ? )

Which is executed with the placeholders set to: ('fred')

`intersect` and `except` can be used in exactly the same way, and
produce respectively a set of results which exists in all the querys
given, and a set of results that contains all rows in the first query,
without any that appear in the subsequent queries.

## Your turn, find all user except those with no posts

This is an alternative way to get the same results we had with
`group_by` and `having`. First create a query to fetch all the users,
then use the `except` method provided by DBIx::Class::Helpers to
subtract the users with no posts.

You can find this test in the file **users_with_posts.t**.

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use Authen::Passphrase::SaltedDigest;
    use Test::More;
    use_ok('MyBlog::Schema');
    
    package Test::ResultSet;
    use strict;
    use warnings;
    
    use base 'DBIx::Class::Helper::ResultSet';
    __PACKAGE__->mk_group_accessors('simple' => qw/method_calls/);

    sub new {
      my ($self, @args) = @_;
      $self->method_calls({});
      $self->next::method(@args);
    }

    ## Count how many times except is called
    sub except {
      my ($self, @args) = @_;
      $self->method_calls->{except}++;
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
    },
    {
      realname => 'Jane Bloggs',
      username => 'jane',
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'sillypassword'),
      email    => 'jane@bloggs.com',
      posts    => [
        {  title => 'Post 3', post => 'Post 3 content', created_date => DateTime->new(year => 2012, month => 01, day => 05) },
        {  title => 'Post 4', post => 'Post 4 content', created_date => DateTime->new(year => 2012, month => 01, day => 07) },
      ],
    }
    ]);
    
    ### Users and their earliest posts
    ## Your code goes here:
    my $users_with_posts_rs;


    ## Your code end
    is($users_rs->method_calls->{except}, 1, 'Called "except" just once');
    is($$users_with_posts_rs->count, 2, 'Found 2 users');
    my $row = $$users_with_posts_rs->next;
    ok($row->isa('MyBlog::Schema::Result::User'), 'Found user objects');
    ok($row->username eq 'fred' || $row->username eq 'jane', 
      'Found users with posts, 1st user');
    $row = $earliest_rs->next;
    ok($row->username eq 'fred' || $row->username eq 'jane',
      'Found users with posts, 2nd user');

    done_testing;


## Real or virtual Views and stored procedures

SQL database systems provide two ways to store predefined queries in
the database. Views consist of a stored query, which can be used just
like a table in `SELECT` statements. The underlying query is run when
needed to fetch the data. 

As views are used similarly to tables, you can just create a normal
Result class, as described in [Chapter 3](03-describing-database),
using the name of the view as the `table` argument.

WARNING: Although this may make the view look like a table, it may not
allow you to run any of the methods to remove or alter the data, such
as `update` and `delete`. Whether these work will depend on the
structure of the query, and the database system you are using.

DBIx::Class also provides a specialised `View` class which can store
the actual query behind the view, and thus allow it to be deployed
(output a CREATE VIEW statement), along with all the tables. Instead
of deploying the view or representing an actual view defined in the
database, it can also define a virtual view, a query just stored in
the DBIx::Class schema.

To create a View class to represent posts together with the username
of the user that wrote them, we can create the PostsAndUser class:

    1. package MyBlog::Schema::Result::PostsAndUser;
    
    2. use strict;
    3. use warnings;
    
    4. use base qw/DBIx::Class::Core/;
 
    5. __PACKAGE__->table_class('DBIx::Class::ResultSource::View');
 
    6. __PACKAGE__->table('posts_and_user');
    7. __PACKAGE__->result_source_instance->is_virtual(1);
    9. __PACKAGE__->result_source_instance->view_definition(
    10.  "SELECT id, title, post, created_date, username, realname FROM posts JOIN users ON posts.user_id = users.id WHERE user.id = ?"
    11. );

    12. __PACKAGE__->add_columns(
    13.   'id' => {
    14.   data_type => 'integer',
    16. },
    17.   'title' => {
    18.   data_type => 'varchar',
    19.   size => 255,
    20. },
    21.  'post => {
    22.   data_type => 'text',
    23. },
    24.  'created_date' => {
    25.  data_type => 'datetime',
    26. },
    27.  'username' => {
    28.   data_type => 'varchar',
    29.   size => 255,
    30. },
    31.  'realname' => {
    32.  data_type => 'varchar',
    33.  size => 255,
    34. },   
    35. );

The main differences to the plain Table Result class are:

    5. __PACKAGE__->table_class('DBIx::Class::ResultSource::View');

Line 5 sets the type of the Result class to be a View instead of the
default Table class.

    7. __PACKAGE__->result_source_instance->is_virtual(1);

Line 7 uses the `is_virtual` method to define this as a DBIx::Class
level view, not a view in the database. Note that only virtual views
can contain placeholders.

    9. __PACKAGE__->result_source_instance->view_definition(
    10.  "SELECT id, title, post, created_date, username, realname FROM posts JOIN users ON posts.user_id = users.id WHERE users.username = ?"
    11. );

Lines 9 to 11 actually set the query used for the view. 

We can use the view just like a normal query, providing the value for
the placeholder parameter in the `bind` attribute:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $posts_and_users_rs = $schema->resultset('PostsAndUser');
    my $freds_posts = $posts_and_users_rs->search({}, { bind => ['fred'] });

This would run the SQL:

    SELECT me.id, me.title, me.post, me.created_date, me.username, me.realname
    FROM (
      SELECT id, title, post, created_date, username, realname
      FROM posts
      JOIN users ON posts.user_id = users.id
      WHERE
      users.username = ?
   )

Using the placeholders: ( 'fred' )

Stored procedures are SQL code stored in the database that can run
quite complex programs to create, update and otherwise manipulate
data. They can return either single values, or a set of rows.

DBIx::Class doesn't provide any specific support for stored
procedures, however they may be used as the content of a virtual view
(returning a set), or as a function (returning single values).

## Preventing race conditions with transactions and locking

When accessing the database using multiple processes or clients, such
as when writing a multi-user application or website, creates the
possibility of race conditions. In our MyBlog schema, these can happen
if, for example, two users attempt to create a new user with the same
username, at the same time.

    ## First user:
    my $user = $users_rs->find_or_new({
       username => 'fredbloggs',
       realname => 'Fred Bloggs',
       password => 'something daft',
       email    => 'fred@bloggs.com',

    });
    if(!$user->in_storage) { # New user
      $user->insert;
    } else {
      warn "fredblogs already exists!"
    }
    
    ## Second user:
    my $user = $users_rs->find_or_new({
       username => 'fredbloggs',
       realname => 'Fred Bloggs',
       password => 'summat daft',
       email    => 'fred@bloggs.co.uk',
    });
    if(!$user->in_storage) { # New user
      $user->insert;
    } else {
      warn "fredblogs already exists!"
    }
    

On the surface this might seem straight forward, but internally we are
running this set of queries:

    ## First user:
    SELECT id, username, realname, password, email 
    FROM users 
    WHERE username = 'fredbloggs';

    -- Do some work
    
    INSERT INTO users
    (username, realname, password, email)
    VALUES('fredbloggs', 'Fred Bloggs', 'something daft', 'fred@bloggs.com');
    
    ## Second user:
    SELECT id, username, realname, password, email 
    FROM users 
    WHERE username = 'fredbloggs';
    
    -- Do some work
    
    INSERT INTO users
    (username, realname, password, email)
    VALUES('fredbloggs', 'Fred Bloggs', 'summat daft', 'fred@bloggs.co.uk');

We obviously intend for these to run first user, then second user, and
for the second one to get an error that a user named 'fredbloggs'
already exists. What may happen is that the `SELECT` statements run
first and both return a result of 'no such user yet'. To ensure the
statements for each user creation run together, we need to start a
`transaction`, using the `txn_do` method:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    $schema->txn_do( sub {
      my $user = $users_rs->find_or_new({
         username => 'fredbloggs',
         realname => 'Fred Bloggs',
         password => 'something daft',
         email    => 'fred@bloggs.com',
      });

      # ... Do some work
    
      if(!$user->in_storage) { # New user
        $user->insert;
      } else {
        warn "fredbloggs already exists!"
      }
    
    } );
    
Now we'll get the SQL:

    START TRANSACTION;
    SELECT id, username, realname, password, email 
    FROM users 
    WHERE username = 'fredbloggs';

    -- Do some work
    
    INSERT INTO users
    (username, realname, password, email)
    VALUES('fredbloggs', 'Fred Bloggs', 'something daft', 'fred@bloggs.com');

    COMMIT;

If any of these fail, the entire set of statements is automatically
reverted using the `ROLLBACK` statement.

It's possible that you can't collect all the code you need to run in a
transaction, into the same place in your code. In this case there are
also the bare bones methods `txn_begin` and `txn_commit` on the
`Schema` object, which will independently start and end a
transaction. Another alternative is the `txn_scope_guard` method which
will return a `$guard` object. This will issue a rollback if it goes
out of scope, otherwise it can be used to issue a `commit` statement.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    {
      my $guard = $schema->txn_scope_guard;
    
      my $user = $users_rs->find_or_new({
         username => 'fredbloggs',
         realname => 'Fred Bloggs',
         password => 'something daft',
         email    => 'fred@bloggs.com',
      });

      # ... Do some work, pass $user and $guard around ...
    
      if(!$user->in_storage) { # New user
        $user->insert;
      } else {
        warn "fredbloggs already exists!"
      }
    
      $guard->commit;
    }
 
Transactions may be also be nested.

