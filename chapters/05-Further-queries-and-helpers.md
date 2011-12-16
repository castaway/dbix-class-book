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
and methods to describe the intented query, and then optimises the
result into SQL. The main method we will need is `search`, with
various conditions and attributes.

## Recap, simple search queries

In Chapter 4 we searched for a set of users with rude or unwanted
words as their realnames, in order to remove them from the
database. This uses the `search` method and filters the results using
the `-like` comparison operator. 

`LIKE` is an SQL keyword used to compare data gainst simple wildcard
matching. `%` matches any number of characters, `_` matches a single
character. LIKE is defined as being case-insensitive in the SQL
standard, it is not implemented as such in all databases (PostgreSQL
is one example).

The two arguments to `search` are a set of conditions, and a set of
attributes. The conditions supply the filters to apply to the data,
the attributes add grouping, sorting and joining.

The other non-obvious subtlty here is that an arrayref in the value of
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
    FROM users
    ORDER BY me.username DESC

Now that we have rows in a known order, we can reduce the set of
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
    FROM users
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
    FROM users
    ORDER BY me.username DESC
    OFFSET 10
    LIMIT 10

## Your turn, fetch ordered posts

Another good use of sorting is to sort things by datetime values to
display them in the order that they happened. You can combine search
conditions with attributes, and find all the posts by the user
**fredbloggs** in the order they were created.

This test can be found in the file **ordered_posts.t**.

    

## Grouping, Filtering, Joining related data

## Aggregates (sum, count)

## Clever stuff: having, subselects, ...

## More on ResultSets and chaining

As mentioned in Chapter 4, ResultSets are used to store the conditions
to create database queries. This means that a ResultSet object can be
passed around and used to collect conditions and attributes, before
running the query.

Suppose we wanted to later check for unwanted words in realnames of
users from ceratin email domains, we can extend the condition later by
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

