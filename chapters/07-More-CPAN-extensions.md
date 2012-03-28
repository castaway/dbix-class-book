Chapter 7 - DBIx::Class extensions
==================================

Chapter summary
---------------

Now we'll take a look at some more extensions and add-ons to
DBIx::Class, some of which exist as separate distributions on CPAN,
that can enhance DBIx::Class in various ways. This is not a
comprehensive list of everything available, and covers commonly used
or needed tools at the time of writing.

If you are reading this significantly (years) after this work was
published, it would be a good idea to check on CPAN whether the
mentioned modules have been marked as DEPRECATED. You can also ask on
the IRC channel, #dbix-class on irc.perl.org, or tweet @dbix_class, to
check if any have been replaced by newer modules or techniques.


Deploying, Versioning and Migrating
-----------------------------------

# Tools that will help you install upgrades to your database structure and content.

So far we've looked at how to describe the database layout in Perl
classes and how to use it to interact with data in the database
itself. In
[](chapter_03-making-a-database-using-dbix-class)
and in the various exercises we saw that running the `deploy` method
on a connected Schema object will create the described tables in the
database.

To recap to send a series of SQL `CREATE` statements to the connected
database:

    my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db");
    $schema->deploy();
    
You may also have noticed that the excercises also contain an `unlink`
statement to first remove the SQLite database. We do this to have a
clean database to work with, but also because attempting to run
`CREATE` statements on a database that already has tables in it will
result in lots of warnings, as the database won't overwrite the
existing table.

The `deploy` method will also take some parameters, so we can ask it
to include `DROP TABLE` statements for each table it's creating like
this:

    $schema->deploy({ add_drop_table => 1});

Now there may be complaints about tables not existing when we try to
run DROP TABLE statements on an empty database, but at least we will
definitely get a fresh database from it. This is actually passed
through to the workhorse for writing DDL SQL, SQL::Translator[^SQLT],
which will, if the database type supports it, also add `IF EXISTS` to
the SQL, and only drop tables that are already there.





Auditing, previewing data
-------------------------

Replcation
----------

How to use DBIx::Class with a master/slave database setup.

Candy
-----

How to write your DBIx::Class classes using a prettier format.

Moose
-----

How to use Moose in your DBIx::Class classes.

Catalyst
--------

How to use DBIx::Class as a model in your Catalyst website.



[SQLT]: [](http://metacpan.org/module/SQL::Translator)
