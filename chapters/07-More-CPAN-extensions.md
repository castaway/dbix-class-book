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

### Deploying tables, views and indexes

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

To `deploy` only some of the tables described in the Schema, for
instance after adding a new Result class, we can also pass a
restricted list of `sources` to create tables for, so to just create
the `posts` table, pass an arrayref with just that name:

    $schema->deploy({ sources => ['Post'] });

### Versions and upgrades

Later on after deploying and using this database schema, later on we
add some features and need to add or change columns on the existing
tables, as an example we'll add a new column to the `User` table,
`dateofbirth`. Before we actually start adding the new column, we need
to setup our existing Schema class to support versioning. Back in
[](chapter_03-the-schema-class) we didn't set a `VERSION`, we add one
now to define the initial version:

    package MyBlog::Schema;
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema';
    
    our $VERSION = '0.01';

    __PACKAGE__->load_namespaces();

    1;
    
The tools for managing database versioning create and manage extra
tables in your database to store information about the version of the
Schema that is installed. To complete the setup for the initial
version, install
[DBIx::Class::DeploymentHandler](http://metacpan.org/module/DBIx::Class::DeploymentHandler)
from CPAN, then create a Perl script to create the SQL files and
install the database including versioning tables:

    #!/usr/bin/env perl
    
    use DBIx::Class::DeploymentHandler;
    use MyBlog::Schema;
    get Getopt::Long;
    
    my $setup = 0;
    GetOptions('setup' => \$setup);
    
    
    my $schema = MyBlog::Schema->connect("dbi:SQLite:t/var/myblog.db");
    my $dh = DBIx::Class::DeploymentHandler->new({
      schema => $schema,
      databases => ['SQLite'],
    });
    
    if($setup) {
      $dh->prepare_install;
    } else {
      $dh->install;
    }

`prepare_install` is used to run SQL::Translator[^SQLT] to create the
SQL for both the tables in our Schema, and the versioning tables. The
SQL produced is written out to a directory named _sql_. To deploy the
contents of that directory, we can copy it to whichever machine we
want to install this database application on, and run `install`.

You can find a copy of this in the downloadable code, under
_bin/install.pl_. To see what tables this creates, run it twice and then
look in the database using the `sqlite3` binary:

    perl bin/install.pl --setup
    perl bin/install.pl
    
    sqlite3 t/var/myblog.db ".dump"
    
Now the setup is done, we can actually add the new column to `User.pm`
and update the VERSION in the `Schema.pm`:

    package MyBlog::Schema;
    
    # ...
    our $VERSION = '0.02';
    
    
    package MyBlog::Schema::Result::User;
    
    # ...
    
    __PACKAGE__->add_columns(
    # ...
      'dateofbirth' => {
        data_type => 'date',
      }
    );

The next step is to produce more SQL, which can be used to convert
installations using the original Schema without the `dateofbirth`
field to the new Schema. We add `prepare_upgrade` to our script,
together with the versions it should convert from and to:

    #!/usr/bin/env perl
    
    use DBIx::Class::DeploymentHandler;
    use MyBlog::Schema;
    get Getopt::Long;
    
    my $setup = 0;
    my $from_ver = 0;
    my $to_ver = 0;
    GetOptions('setup'  => \$setup,
               'from:s' => \$from_ver,
               'to:s'   => \$to_ver);
    
    my $schema = MyBlog::Schema->connect("dbi:SQLite:t/var/myblog.db");
    my $dh = DBIx::Class::DeploymentHandler->new({
      schema => $schema,
      databases => ['SQLite'],
    });
    
    if($setup) {
      $dh->prepare_install;

      if($from_ver && $to_ver) {
        $dh->prepare_upgrade({
          from_version => $from_ver,
          to_version   => $to_ver,
        });

      }
    } else {

      if($from_ver && $to_ver) {
        $dh->upgrade;
      } else {
        $dh->install;
      }

    }

We create the SQL by adding the two version parameters and re-running
the script:

    perl bin/install.pl --setup --from='0.01' --to='0.02'

    perl bin/install.pl --from='0.01' --to='0.02'
    
    
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
