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

If you already had data in your posts tables, you should see a
changeset id and corresponding history and log tables for the most
recent state of the existing data, and another set for the post entry
we just added.

TODO: Accessing the journalling tables/data?

Replcation, sharing the load
----------------------------

### How to use DBIx::Class with a master/slave database setup.


Some databases, notably MySQL, come with settings to allow the data
entered in one database, the *master* copy, to be automatically copied
(also called 'replicated') into one or more mirror databases. This can
be used purely for backing up data, or it can be used to share the
load on the master database, and access speed of remote applications,
by sending read-only operations to the copies. The copies are often
called *slaves* or *replicants*.

You can use the master database with this kind of setup quite normally
with DBIx::Class, just connect to it in the usual way.

We can also take advantage of replication by adjusting our DBIx::Class
setup to teach it more about how our database is replicated. To do
this we need to add some configuration to the Schema which will
configure the Storage object.

NB: The storage object is normally created for you based on the
connection information given to the `connect` method, and the database
type. It is used transparently to send the correct SQL statements to
the database for you.

To try out replication, you will need to install a few more modules
from CPAN. As replication is implemented as an add-on for use when
needed, these dependent modules are not installed by default, they are
optional. The current dependencies are Moose[^Moose] and
MooseX::Types[^moosextypes], for an up to date list, look at the
optional dependencies[^replicateddeps].

Getting down to the details, we can add replication settings to our
schema at any point, or even just for particular applications or tools
using the schema. We `clone` the Schema object and setup the new
storage settings:

    my $schema = MyBlog::Schema->clone;
    $schema->storage_type([
      '::DBI::Replicated' => {
        balancer_type => '::Random',
        balancer_args => {
          auto_validate_every => 5,
          master_read_weight => 1
        },
        pool_args => {
          maximum_lag => 2
        }
      }
    ]);

    $schema->connection('dbi:mysql:mydatabase', 'mybloguser', 'myblogpasswd');

    $schema->storage->connect_replicants(
      [$dsn1, $user, $pass, \%opts],
      [$dsn2, $user, $pass, \%opts],
      [$dsn3, $user, $pass, \%opts],
    );

Alternately we can set the new storage settings directly on the Schema
class, which will make them available for any use of the class in the
application:

    MyBlog::Schema->storage_type([ ... ]);
    my $schema = MyBlog::Schema->connect( ... );

    $schema->storage->connect_replicants([ ... ]);

Setting this new storage class,
`DBIx::Class::Storage::DBI::Replicated` will wrap and replace the
existing storage. It gets passed a hashref of settings which define
how the replication will work, briefly these are:

* balancer_type
    We have a choice of ::First or ::Random, as the names suggest, these will either return the first available replicant or a random one from the selection.
    
* auto_validate_every
    The interval in seconds to validate whether the replicants are available. If any fail the test or lag more than the "maximum_lag" seconds, they are set to inactive and not used.
    
* master_read_weight
    By default the master is not used to read from at all, setting this to 1 will give it the same probability to be used as the replicants.

* maximum_lag
    The number of seconds offset behind the master each replicant is allowed to be before being marked invalid / unsuable.
    
To put this all to use, we just need to use our schema normally. To
enforce integrity of a particular set of transactions, use a
transaction as described in
[](chapter_05-preventing-race-conditions-with-transactions-and-locking).
    

A bit of Candy in your code
---------------------------

If you find the `__PACKAGE__` syntax ugly or cumbersome for defining
your DBIx::Class classes, then there's some help for you in the shape
of DBIx::Class::Candy[^Candy].

Here's an example using it with our `User` class:

    package MyBlog::Schema::Result::User;
    
    use DBIx::Class::Candy 
      -autotable  => 'v1',
      -components => [qw/InflateColumn::Authen::Passphrase/];
    
    primary_column => 'id' => {
      data_type => 'integer',
      is_auto_increment => 1,
    };
    
    column 'realname' => {
      data_type => 'varchar',
      size => 255,
    };

    column 'username' => {
      data_type => 'varchar',
      size => 255,
    };

    column 'password' => {
      data_type => 'varchar',
      size => 255,
      inflate_passphrase => 'rfc2307',
    };

    unique_column 'email' => {
      data_type => 'varchar',
      size => 255,
    };
    
    has_many 'posts' => 'MyBlog::Schema::Result::Post', 'user_id';

Several things to note:

* Candy imports `strict` and `warnings` for you and sets the parent
class for you.

* No need to specify the table name, `users`, Candy will use your
class name to decide what to call the table. The defaults are
sensible, you can influence them if you need to.

* You can create tables with multi-column primary keys by using the
`primary_key` method multiple times.

* `unique_column` creates a column and a unique constraint in one call.

That's it, prettier code, all done.

Moose
-----

How to use Moose in your DBIx::Class classes.

Catalyst
--------

How to use DBIx::Class as a model in your Catalyst website.



[SQLT]: [](http://metacpan.org/module/SQL::Translator)
[DBICDH]: [](http://metacpan.org/module/DBIx::Class::DeploymentHandler)
[Moose]: [] (http://metacpan.org/module/Moose)
[moosextypes]: [](http://metacpan.org/module/MooseX::Types)
[replicateddeps]: [](http://metacpan.org/module/DBIx::Class::Optional::Dependencies#Storage::Replicated)
