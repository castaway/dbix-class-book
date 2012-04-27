% The DBIx::Class Book
% Jess Robinson
% February 2012

Chapter 2 - Databases, design and layout
========================================

Chapter summary
---------------

This chapter explains how to effectively lay out the data you want to
store in your database. It covers several techniques on how to decide
to split up your content in a way that is usable with
DBIx::Class. Note that these are of my own devising, for a more formal
set of rules, see L<http://db-class.org>[^dbclass] or look up
"Database normalisation".

If you already have an existing database, or are working with a
DBA[^DBA], then you can skim this to get an idea of what is going on
(and why), or jump straight to [](chapter_03-describing-database).

Pre-requisites
--------------

We will be showing SQL examples in this chapter, and giving both MySQL[^mysql] and SQLite[^sqlite]

Examples given in this chapter will work with the one-file database [SQLite](http://www.sqlite.org), which can be installed for Perl by installing the CPAN module [DBD::SQLite](http://search.cpan.org/dist/DBD-SQLite).

Introduction
------------

Choosing to use a database is the first step, the next part is harder,
how to arrange all the pieces of data you need into tables, to
optimise the performance of inserting and retrieving data. There is no
perfect answer, as it will always depend on the uses your application
will make of it. We'll show some techniques on how to consider your
data and its uses, and divide it into tables and related tables. We'll
also touch on some formal definitions, and show some places to get
some more help if you're still stuck.

We are using the example of writing a blogging software or website
throughout this book. This example is chosen as hopefully all readers
will have an idea of how it works. Just in case, we're going to assume
we have one or more `Users` who write articles we'll name `Posts` and
that they'll allow other `Users` to write `Comments` attached to the
articles. If you're still unsure what's going on, please see the
Wikipedia article on "Blog"[^wpblog].



## First, find some data

We're going to need some sample data to explore how to do this, so
first we'll dump out a list of ideas for pieces of data we want for
the blogging software, and discuss briefly why these particular
pieces.

* name (display name)
* dateofbirth (user's dob)
* address (user's location)
* lat_long (user's geo location)
* username (unique login name)
* password (key for user account)
* email (for confirmation and notifications)
* role (commentor, moderator, writer)
* post_title (one line description/headline)
* post_content (actual content)
* post_summary (shortened copy for rss feed or homepage)
* post_created (datetime of post)

## Decide level of detail needed

Some of these are descriptive, but not really required for a blogging
system. Our first principle is to only store the data to the level we
will actually use it. We can always add more later. Our simple system
doesn't care how old the user is, or where they are, so we can drop
the `dateofbirth`, `address` and `lat_long` ideas. We'll keep the
`role` field for demonstration purposes later.

Now we make a few test posts for users 'joe' and 'fred' using the
remaining columns and dumping them in a single table:

+----+----------+----------+----------------+--------+------------+----------------+-------------+-------------+
|name| username | password | email          | role   | post_title | post_content   | post_summary| post_created|
+====+==========+==========+================+========+============+================+=============+=============+
|Joe | joeb     | mypass   | joe@bloggs.com | editor | Post1      | Post 1 content | Post1       | 2011-01-02  |
+----+----------+----------+----------------+--------+------------+----------------+-------------+-------------+
|Joe | joeb     | mypass   | joe@bloggs.com | editor | Post2      | Post 2 content | Post2       | 2011-01-05  |
+----+----------+----------+----------------+--------+------------+----------------+-------------+-------------+
|Joe | joeb     | mypass   | joe@bloggs.com | editor | Post3      | Post 3 content | Post3       | 2011-02-01  |
+----+----------+----------+----------------+--------+------------+----------------+-------------+-------------+
|Fred| fredb    | otherpass| fred@bloggs.com| editor | FPost1     | FPost 1 content| FPost1      | 2011-03-01  |
+----+----------+----------+----------------+--------+------------+----------------+-------------+-------------+

Table: Table with all_data

If we entered our data all in this one table, we'd end up having to
repeat all the data about the user for every post they make. This
explodes the amount of data we end up storing, and also the amount
that is transfered every time we want to display the post.

In order to create a new row, we would have to either force the user
to enter all this data again for each post, with the risk of them not
entering values that match the existing ones, or pull a unique set for
the user from the table, and re-submit them. Either way it makes extra
work for somebody.

If a user wanted to change their email address or password later on,
we would also have to update all their entry rows. This will cause
more work for the database, which would make it busier for other uses,
such as displaying posts to other users.

We would also have to update a lot of rows just to change one piece of
information about the user, for example Joe's email address.

## Don't repeat data 1: Separate related data

This gives us the second technique, don't repeat data. The first way
to do this is to look at the field titles, and notice that some
clearly indicate a set of related fields. The `post_` fields belong
together. We can then attempt to name the separated tables based on
what they contain:

+-----------+----------------+-------------+-------------+
| title     | content        | summary     | created     |
+===========+================+=============+=============+
| Post1     | Post 1 content | Post1       | 2011-01-02  |
+-----------+----------------+-------------+-------------+
| Post2     | Post 2 content | Post2       | 2011-01-05  |
+-----------+----------------+-------------+-------------+
| Post3     | Post 3 content | Post3       | 2011-02-01  |
+-----------+----------------+-------------+-------------+
| FPost1    | FPost 1 content| FPost1      | 2011-03-01  |
+-----------+----------------+-------------+-------------+

Table: Posts table

The name for this one is fairly obvious, based on the fields we've
extracted. We can also drop the `posts_` prefix now.

+-----+----------+-----------+----------------+--------+
|name | username | password  | email          | role   |
+=====+==========+===========+================+========+
|Joe  | joeb     | mypass    | joe@bloggs.com | editor |
+-----+----------+-----------+----------------+--------+
|Fred | fredb    | otherpass | fred@bloggs.com| editor |
+-----+----------+-----------+----------------+--------+

Table: User table (?)

However, how do we know which post belongs to whom? We need to make or
discover a field (or set of fields) which can be used to identify each
user uniquely, and put it into the Posts table. This first unique key
is called the `PRIMARY KEY`. We can choose a piece of existing data
that preferably won't change, eg the `username` field, or we can add a
new and definitely unique artificial integer field.

Note that if we use a field that already exists, like `username`, then
we can still update it (at least most database systems support this),
but we end up with a similar situation to previously described, having
to update all the users posts to change the username / key value.

I prefer the integer approach, so we add a new field named `id` and
store a copy in the Posts table as `user_id`. On the Posts table side
this is called a `FOREIGN KEY`, and in most databases we can use a
`CONSTRAINT` to have it refuse to insert a row of data if the
`user_id` doesn't match an existing value in the `users` table.

The `posts` table itself also needs a unique field for its PRIMARY
KEY, so we'll add one there too:

+----+---------+-----------+----------------+-------------+-------------+
| id | user_id | title     | content        | summary     | created     |
+====+=========+===========+================+=============+=============+
| 1  | 1       | Post1     | Post 1 content | Post1       | 2011-01-02  |
+----+---------+-----------+----------------+-------------+-------------+
| 2  | 1       | Post2     | Post 2 content | Post2       | 2011-01-05  |
+----+---------+-----------+----------------+-------------+-------------+
| 3  | 1       | Post3     | Post 3 content | Post3       | 2011-02-01  |
+----+---------+-----------+----------------+-------------+-------------+
| 4  | 2       | FPost1    | FPost 1 content| FPost1      | 2011-03-01  |
+----+---------+-----------+----------------+-------------+-------------+

Table: Posts table

+----+------+----------+-----------+----------------+--------+
| id | name | username | password  | email          | role   |
+====+======+==========+===========+================+========+
| 1  | Joe  | joeb     | mypass    | joe@bloggs.com | editor |
+----+------+----------+-----------+----------------+--------+
| 2  | Fred | fredb    | otherpass | fred@bloggs.com| editor |
+----+------+----------+-----------+----------------+--------+

Table: Users table 

## SQL break, CREATE TABLE

To actually create a database table, we need to make some more
decisions, like what type of data we want to store in each of our
fields. We'll need to store some text, some numbers and a date/time. As the
numeric primary key is artificial, we can have the database
automatically assign it a value, using the `AUTO INCREMENT` keyword.

The `CREATE TABLE` statement is made up mostly of a list of columns,
each one should contain at least a name and the data
type[^yesweknow]. We're using data types from MySQL[^mysqldatatypes]
here, SQLite will accept almost any type from other databases.

`CREATE TABLE` is the SQL DDL[^DDL] statement to use to set up new tables:

    CREATE TABLE users (
      id INT AUTO_INCREMENT,
      name TINYTEXT,
      username TINYTEXT,
      password TINYTEXT,
      email TINYTEXT,
      role TINYTEXT,
      PRIMARY KEY (id)
    );

    CREATE TABLE posts (
      id INT AUTO_INCREMENT,
      user_id INT,
      created_date DATETIME,
      title TINYTEXT,
      post TEXT,
      PRIMARY KEY (id),
      CONSTRAINT posts_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id)
    );

We can save these into a file, _myblog.sql_. The extension of _.sql_
is not compsulory, but is in general use, and recognised by most
editors. To create a new MySQL database, first run the `CREATE
DATABASE` statement, then import the contents of the file:

    mysql -h <host> -u <user> -p < echo "CREATE DATABASE myblog"

    mysql -h <host> -u <user> -p <database> < myblog.sql

To make an SQLite database we just import the SQL file into a new
database file which will be created if it does not exist yet:

    sqlite3 myblog.db < myblog.sql

## Separate non-related data, flag fields

Joe's written two posts, and Fred wrote one, now Fred comes back and
makes a comment on Joe's first post. We could store our comments in
the posts table, and give them all the same fields as the posts,
however we'd still need a way to decide which items were posts and not
comments, so we don't accidentally display comments as full posts.

One way to do this is to add a flag field to the table, for example a
boolean (true/false) field named `is_post`. Our comments also need to
link back to the posts they are a comment on, so we'll add the
`comment-on` field. For posts of course this is irrelevant, so we'll
leave it empty, or NULL in SQL-speak.

+----+---------+----------+------------+-----------+--------------------+---------+-------------+
| id | user_id | is_post  | comment_on | title     | content            | summary | created     |
+====+=========+==========+============+===========+====================+=========+=============+
| 1  | 1       | true     | NULL       | Post1     | Post 1 content     | Post1   | 2011-01-02  |
+----+---------+----------+------------+-----------+--------------------+---------+-------------+
| 2  | 1       | true     | NULL       | Post2     | Post 2 content     | Post2   | 2011-01-05  |
+----+---------+----------+------------+-----------+--------------------+---------+-------------+
| 3  | 1       | true     | NULL       | Post3     | Post 3 content     | Post3   | 2011-02-01  |
+----+---------+----------+------------+-----------+--------------------+---------+-------------+
| 4  | 2       | true     | NULL       | FPost1    | FPost 1 content    | FPost1  | 2011-03-01  |
+----+---------+----------+------------+-----------+--------------------+---------+-------------+
| 5  | 2       | false    | 1          | FComment  | FComment 1 content |         | 2011-03-10  |
+----+---------+----------+------------+-----------+--------------------+---------+-------------+

Table: Posts (with comments)

This means when fetching the data for either Posts or Comments, we'll
have to filter the table, for example by checking whether the
`comment_on` field is NULL or not. If we also want to add methods to our
code to calculate for example, the number of comments by each user, we
will also have to add a filter.

As a rule of thumb, if the majority of your queries on the data will
need to specify the filter, then its better to just separate the
comments into their own table instead.

+----+---------+-------+-----------------+--------+-------------+
| id | user_id | title | content         | summary| created     |
+====+=========+=======+=================+========+=============+
| 1  | 1       | Post1 | Post 1 content  | Post1  | 2011-01-02  |
+----+---------+-------+-----------------+--------+-------------+
| 2  | 1       | Post2 | Post 2 content  | Post2  | 2011-01-05  |
+----+---------+-------+-----------------+--------+-------------+
| 3  | 1       | Post3 | Post 3 content  | Post3  | 2011-02-01  |
+----+---------+-------+-----------------+--------+-------------+
| 4  | 2       | FPost1| FPost 1 content | FPost1 | 2011-03-01  |
+----+---------+-------+-----------------+--------+-------------+

Table: Posts

+----+---------+-------+-----------+-------------+-------------+
| id | user_id | comment_on | title | content | created |
+====+=========+=======+===========+=============+=============+
| 1  | 2       | 1     | FComment | FComment 1 content | 2011-03-10 |
+----+---------+-------+-----------+-------------+-------------+

Table: Comments

We can also tidy up the Commets table by removing the `summary` field,
as we don't think we'll need to summarise comments.

## Don't repeat data 2: Linking tables

You'll notice that we haven't yet looked at what happens to the data
in the user table when we add comments. We have the `role` field which
identifies which roles each user has. The original idea was to list
their roles for each article, `poster` or `commenter`, but we've lost
that by dumping it into the user table.

Each user can have multiple roles on each post, to store this in our
database, we need a "many to many" relation (many users to many
roles). Rather than putting this in either the users or posts tables,
we can create an extra table to join the two together. We can also
store the roles themselves in their own table and link their id in as
well, or just use the string values.

+---------+---------+-----------+
| user_id | post_id | role      |
+=========+=========+===========+
| 1       | 1       | editor    |
+---------+---------+-----------+
| 1       | 2       | editor    |
+---------+---------+-----------+
| 1       | 3       | editor    |
+---------+---------+-----------+
| 2       | 4       | commentor |
+---------+---------+-----------+
| 2       | 1       | commentor |
+---------+---------+-----------+

Table: users_posts_roles

+----+-----+----------+-----------+-----------------+
| id | name| username | password  | email           |
+====+=====+==========+===========+=================+
| 1  | Joe | joeb     | mypass    | joe@bloggs.com  |
+----+-----+----------+-----------+-----------------+
| 2  | Fred| fredb    | otherpass | fred@bloggs.com |
+----+-----+----------+-----------+-----------------+

Table: Users table

We are again repeating the text for the role names. This time we
can (and should) help avoid this data becoming incorrect by providing
a list for the user (or probably an administrator) to select the role
names from, when setting up or modifying a user account.

This could end up with users being both commentors and editors on the
same post, which would repeat the `user_id` and `post_id` pairs in the
table. This is not too bad as its fairly small data. We could also
avoid it by declaring that the roles are a hierarchy, that is that all
`editor`s are automatically `commentor`s as well.

## SQL break, SELECT ... FROM

Getting data from one table is straight-forward, we use a `SELECT`
statement, for example to get user joe's information:

    SELECT id, name, username, password, email
    FROM users
    WHERE username = 'joeb';
    
To get the data from multiple tables, for example a user and their
posts, we need to use the `JOIN` keyword, and join the tables on the
unique values we created.

    SELECT id, name, username, password, email, posts.title, posts.content, posts.summary, posts.created
    FROM users
    JOIN posts ON users.id = posts.user_id
    WHERE username = 'joeb';

You can enter these into the mysql or sqlite3 clients to see what happens.

## DBIx::Class and SQL

The rest of the book won't dwell much on the actual SQL statements, as
we're trying to abstract them with Perl. If you'd like to know what's
going on behind the scenes in the following chapters, then you can set
the `DBIC_TRACE` environment variable to 1 in your shell. In the bash
shell for example it would look like this:

    export DBIC_TRACE=1
    
All DBIx::Class code in this shell will now output which statements it
is running to the screen. To turn it off again, set it to `0`, or
`unset` it.

Now, on to chapter 3 and some actual Perl code.

[^DDL]: Data Definition Language
[^dbclass]: An online course in using databases, a good introduction to academic techniques.
[^wpblog]: [](http://enwp.org/Blog)
[^mysql]: A free and well-known database that works on various operating systems, see [](http://www.mysql.com). Get the DBD ([](http://metacpan.org/module/DBD::mysql)) to use it with Perl.
[^sqlite]: A free, compact and single-file database that works on various operating systems, see [](http://sqlite.org). To use it with Perl, get [](http://metacpan.org/module/DBD::SQLite) which also contains the database itself.
[^yesweknow]: Yes, SQLite doesn't strictly insist on data types being provided. It's a good idea to provide them anyway for easy transition to other databases, and clarity to other developers.
[^mysqldatatypes]: [](http://dev.mysql.com/doc/refman/5.6/en/data-types.html) - the latest version at time of writing, make sure you find the documentaton that matches your actual installation.
