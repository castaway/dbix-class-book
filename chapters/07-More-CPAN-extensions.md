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


Installing, Versioning and Migrating
-------------------------------------

### Installing tables, views and indexes

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

After deploying and using this database schema, we may later want to
make some changes and add or change columns on the existing tables. As
an example we'll add a new column to the `User` table,
`dateofbirth`. Before we actually start adding the new column, we need
to setup our existing Schema class to support versioning. Back in
[](chapter_03-the-schema-class) we didn't set a `$VERSION` for our
Schema, we add one now to define the initial version:

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
DBIx::Class::DeploymentHandler[^DBICDH]
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
_bin/install.pl_. To see what tables this creates, run it with
`--setup` to produce the SQL files, and look in the _sql_/
directory. Running the script a second time without the `--setup`
argument will create the database including the versioning tables. You
can then review these using the `sqlite3` binary:

    perl bin/install.pl --setup
    perl bin/install.pl
    
    sqlite3 t/var/myblog.db ".dump"
    
Now the setup is done, we can actually add the new column to `User.pm`
and update the `$VERSION` in the `Schema.pm`:

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

We create the SQL containing ALTER TABLE statements by using the two
new version script arguments and re-running the script:

    perl bin/install.pl --setup --from='0.01' --to='0.02'

Then to upgrade the database:

    perl bin/install.pl --from='0.01' --to='0.02'

DeploymentHandler can do much more, including allowing the user to
supply Perl scripts to be run during upgrades to migrate the actual
data around, useful for example if a table gets split out into several
related tables.

## Your turn, create VERSION 0.03, adding a Comments table

For this you will need to create a new Result class from scratch like
the Post class back in [](chapter_03-your-turn-the-post-class), then
add appropriate code to the test below, which you can find in the file
**upgrade_to_comments.t**.

TODO
    
Tracking data changes
---------------------

Now we have the database installed and maintained, we get down to the
business of putting data in it. Some applications need to track
changes to the content, you may want to be able to look at historical
values, for example previous content of webpages or posts. A more
likely use for this than our blog app is a Wiki[^Wiki] or CMS[^CMS]
type application.

Luckily, there is already a module which will help out by creating a
set of paralell tables, two for each existing source table you want to
track changes in. It only tracks changes using transactions, each is
assigned a unique changeset identifier. To try this out, install the
DBIx::Class::Journal[^Journal] module from the CPAN.

Let's update our Blog schema to track changes to the Posts table
automatically, edit the _MyBlog/Schema.pm_ file:

    package MyBlog::Schema;
    use warnings;
    use strict;
    
    use base 'DBIx::Class::Schema';
 
    __PACKAGE__->load_components(qw/Schema::Journal/);
    __PACKAGE__->journal_sources([qw/ Post /]);

    __PACKAGE__->load_namespaces();
    
    1;

We've added the Journal component, and used the `journal_sources`
class method to instruct it to only track changes to the Post table
data.

To setup an initial deployment of the journalling tables for our
existing tables and data, we need to run the `bootstrap_journal`
method just once. This will import any existing Posts into the new
tables so that we have a starting point to base new changes on top of.

We can add this to our script for DeploymentHandler in the install
section. If you skipped the [](chapter_07-versions-and-upgrades)
section above, you can find the script in the _bin/install.pl_ file.

    if($setup) {
      $dh->prepare_install;
    } else {
      $dh->install;
      $dh->schema->bootstrap_journal();
    }

Run the script to add the new tables, and investigate the results
using the `sqlite3` binary:

    perl bin/install.pl
    
    sqlite3 t/var/myblog.db ".dump"

You will see four new tables. 

* `changeset` to store the identifiers of each new changeset
(transaction), which includes a `user_id` if you want to associate an
existing user with the change

* `change_log` each actual database operation in the changeset is
recorded here with a new row, which keeps track of the order in which
they happened.

* `posts_auditlog` records the start and possible end of each posts
row, with the id from the `posts` table mapped to a `create_id` or a
`delete_id` changeset id.

* `posts_audithistory` records all the rows of the original posts
table, with a new row for each change. It stores the `change_id`
against each one.

Now we can insert another post for user fred, using a transaction, and
examine the results:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    $schema->txn_do(sub {
      my $freduser = = $schema->resultset('User')->find({
        username => 'fredbloggs'
      }, {
        key => 'username_idx',
      });
      $schema->changeset_user($freduser->id);

      $freduser->create_related('posts', {
        title => 'Testing table content tracking',
        post => 'Table tracking post content',      
      });
    });

Looking in the tables we now have:

+=====+===========+================+================================+=============================+
| id  |  user_id  |  created_date  | title                          | post                        |
+-----+-----------+----------------+--------------------------------+-----------------------------+
| 1   |  1        | 2012-04-13     | Testing table content tracking | Table tracking post content |
+-----+-----------+----------------+--------------------------------+-----------------------------+

Table: posts table

+=====+===========+=============+=====================+
| id  | user_id   | session_id  | set_date            |
+-----+-----------+-------------+---------------------+
| 1   | 1         |             | 2012-04-13 10:00:00 |
+-----+-----------+-------------+---------------------+

Table: change_set

+=====+==============+========+
| id  | changeset_id | order  |
+-----+--------------+--------+
| 1   | 1            | 1      |
+-----+--------------+--------+

Table: change_log

+===========+===========+====+
| create_id | delete_id | id |
+-----------+-----------+----+
| 1         |           | 1  |
+-----------+-----------+----+

Table: posts_auditlog

+===========+=====+===========+================+================================+=============================+
| change_id | id  |  user_id  |  created_date  | title                          | post                        |
+-----------+-----+-----------+----------------+--------------------------------+-----------------------------+
| 1         | 1   |  1        | 2012-04-13     | Testing table content tracking | Table tracking post content |
+-----------+-----+-----------+----------------+--------------------------------+-----------------------------+


Table: posts_audithistory

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
[DBICDH]: [](http://metacpan.org/module/DBIx::Class::DeploymentHandler)
