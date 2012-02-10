% The DBIx::Class Book
% Jess Robinson
% February 2012

Chapter 2 - Databases, design and layout
========================================

Chapter summary
---------------

This chapter explains how to effectively lay out the data you want to
store in your database into tables.

Pre-requisites
--------------

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

## First, find some data

We're going to need some sample data to explore how to do this, so
first we'll dump out a list of ideas for pieces of data we want for
the blogging software, and discuss briefly why these particular
pieces.

* name (display name)
* dateofbirth (user's dob)
* address (user's location)
* latlon (user's geo location)
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
the `dateofbirth`, `address` and `latlon` fields. We'll keep the
`role` field for demonstration purposes later.

Now we make a few posts for users 'joe' and 'fred' using the remaining columns:

+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|name | username | password | email | role | post_title | post_content | post_summary | post_created |
+====+========+=========+======+=====+===========+=============+=============+=============+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post1 | Post 1 content | Post1 | 2011-01-02 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post2 | Post 2 content | Post2 | 2011-01-05 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post3 | Post 3 content | Post3 | 2011-02-01 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor | FPost1 | FPost 1 content | FPost1 | 2011-03-01 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+

Table: Table with all_data

If we entered our data all in this one table, we'd end up having to
repeat all the data about the user for every post they make. This
explodes the amount of data we end up storing, and also the amount
that is transfered every time we want to display the post.

We would also have to update a lot of rows just to change one piece of
information about the user, for example Joe's email address.

## Don't repeat data 1: Separate related data

This gives us the second principle, don't repeat data. The first way
to do this is to look at the field titles, and notice that some
clearly indicate a set of related fields. The `post_` fields belong
together. We then attempt to name the tables based on what they
contain:

+-----------+-------------+-------------+-------------+
| title | content | summary | created |
+===========+=============+=============+=============+
| Post1 | Post 1 content | Post1 | 2011-01-02 |
+-----------+-------------+-------------+-------------+
| Post2 | Post 2 content | Post2 | 2011-01-05 |
+-----------+-------------+-------------+-------------+
| Post3 | Post 3 content | Post3 | 2011-02-01 |
+-----------+-------------+-------------+-------------+
| FPost1 | FPost 1 content | FPost1 | 2011-03-01 |
+-----------+-------------+-------------+-------------+

Table: Posts table

The name for this one is fairly obvious, based on the fields we've
extracted. We can also drop the `posts_` prefix now.

+----+----------+-----------+------+-----+
|name | username | password | email | role |
+====+==========+===========+======+=====+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor |
+----+----------+-----------+------+-----+
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor |
+----+----------+-----------+------+-----+

Table: User table (?)

However, how do we know which post belongs to whom? We need to make or
discover a field (or set of fields) which can be used to identify each
user uniquely, and put it into the Posts table. This first unique key
is called the `PRIMARY KEY`. We can choose a piece of existing data
that preferably won't change, eg the `username` field, or we can add a
new and definitely unique artificial integer field.

I prefer the integer approach, so we add a new field named `id` and
store a copy in the Posts table as `user_id`. On the Posts table side
this is called a `FOREIGN KEY`, and in most databases we can use a
`CONSTRAINT` to have it refuse to insert a row of data if the
`user_id` doesn't match an existing value in the `users` table.

## SQL break, CREATE TABLE

To actually create a database table, we need to make some more
decisions, like what type of data we want to store in each of our
fields. We'll need to store some text, some numbers and a date. As the
numeric primary key is artificial, we can have the database
automatically assign it a value, using the `AUTO INCREMENT` keyword.

`CREATE TABLE` is the SQL DDL[^DDL] statement to use to set up new tables:

    CREATE TABLE users (
      id INT AUTO_INCREMENT,
      name TINYTEXT,
      username TINYTEXT,
      password TINYTEXT,
      email TINYTEXT,
      PRIMARY KEY (id)
    );

    CREATE TABLE posts (
      id INT AUTO_INCREMENT,
      user_id INT,
      created_date DATETIME,
      title VARCHAR(255),
      post TEXT,
      PRIMARY KEY (id),
      CONSTRAINT posts_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id)
    );

We can save these into a file, using the (not compulsory) extension
".sql". To create a new MySQL database, first run the `CREATE
DATABASE` statement, then import the contents of the file:

    mysql -h <host> -u <user> -p < echo "CREATE DATABASE myblog"

    mysql -h <host> -u <user> -p <database> < myblog.sql

To make an SQLite database we just import the SQL file into a new
database (it stores one database per file):

    sqlite3 myblog.db < myblog.sql

## Don't repeat data 2: Linking tables

Joe's written two posts, and Fred wrote one, now Fred comes back and makes a comment on Joe's first post. We'll 


[^DDL] Data Definition Language
