% The DBIx::Class Book
% Jess Robinson
% March 2014

Chapter 0 - Preamble
========================================

This book will introduce you to the current best practices of accessing databases using the Perl module DBIx::Class. It will assume a working knowledge of Perl and Object Orientation (OO) in Perl. Some knowledge of relational databases and SQL (the language used to query them), will also be helpful. An introduction to SQL is included in this book to help you get started, we reccommend that you expand this knowledge with further learning.

Please note that the practices shown in this book were "current best practice" at the time of going to press. Software evolves over time, so you are advised to keep track of book updates (see dbix-class.org) and other software updates by keeping up with the latest [DBIx::Class releases](http://www.metacpan.org/releases/DBIx-Class) on CPAN.

For further help and support, join the DBIx::Class [mailing list](http://lists.scsys.co.uk/mailman/listinfo/dbix-class) or use the [IRC channel - irc.perl.org#dbix-class](https://chat.mibbit.com/#dbix-class@irc.perl.org)

The examples and code in this book are mostly based on a fictional piece of blogging software which uses a database for storing users, posts and comments. The SQL to create the full database, and the entire DBIx::Class schema created and discussed in the book can be downloaded from [The DBIx::Class book page](http://dbix-class.org/book).

The database contains the following tables:

* Users

Each "user" of the blog has a row in this table. Users are attached to Posts, each post is written by exactly one user/author. Users are also attached to Comments, each comment has exactly one user/author.

* Posts

Each article on the blog is stored in one row in the posts table. Each post is written by one user/author, and may have zero or more comments attached to it.

* Comments

Each comment on a blog article is stored in one row in the comments table. Each comment is written by one user/author, and is attached to a particular post entry.

Following along with the examples
---------------------------------

While reading this book you may wish to write out or copy and run the examples given on your own computer. To do this you will need to install at least the following software:

* [Perl](http://perl.org) you should have this already! You will need a version later than 5.8.0.

* The Perl [DBI](http://www.metacpan.org/release/DBI) module. This is the base module for talking to databases from Perl.

* A database server. We use [SQLite](http://sqlite.org) as it is simple to obtain, install and use. It is a self-contained one-file database. The examples are likely to work on other databases, the text will state if they are not generic.

* A Perl Database Driver matching your chosen database. The [DBD::SQLite](http://www.metacpan.org/release/DBD-SQLite) module also includes SQLite itself
