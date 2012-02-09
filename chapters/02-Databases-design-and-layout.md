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
the `dateofbirth`, `address` and `latlon` fields.

Now we make a few posts for user 'joe' using the remaining columns:

+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|name | username | password | email | role | post_title | post_content | post_summary | post_created |
+====+========+=========+======+=====+===========+=============+=============+=============+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post1 | Post 1 content | Post1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post2 | Post 2 content | Post2 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post3 | Post 3 content | Post3 |
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor | FPost1 | FPost 1 content | FPost1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+

Table: Table with all_data

If we entered our data all in this one table, we'd end up having to
repeat all the data about the user for every post they make. This
explodes the amount of data we end up storing, and also the amount
that is transfered every time we want to display the post.

We would also have to update a lot of rows just to change one piece of
information about the user, for example Joe's email address.

## Don't repeat data

This gives us the second principle, don't repeat data. We'll start by
making a random guess at what to do, and split the table into three:

+----+----------+-----------+------+-----+
|name | username | password | email | role |
+====+==========+===========+======+=====+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor |
+----+----------+-----------+------+-----+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor |
+----+----------+-----------+------+-----+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor |
+----+----------+-----------+------+-----+
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor |
+----+----------+-----------+------+-----+

Table: User names table


+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|name | username | password | email | role | post_title | post_content | post_summary | post_created |
+====+========+=========+======+=====+===========+=============+=============+=============+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post1 | Post 1 content | Post1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post2 | Post 2 content | Post2 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post3 | Post 3 content | Post3 |
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor | FPost1 | FPost 1 content | FPost1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+


+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|name | username | password | email | role | post_title | post_content | post_summary | post_created |
+====+========+=========+======+=====+===========+=============+=============+=============+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post1 | Post 1 content | Post1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post2 | Post 2 content | Post2 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
|Joe  | joeb     | mypass   | joe@bloggs.com | editor | Post3 | Post 3 content | Post3 |
|Fred  | fredb   | otherpass   | fred@bloggs.com | editor | FPost1 | FPost 1 content | FPost1 |
+----+--------+---------+------+-----+-----------+-------------+-------------+-------------+
