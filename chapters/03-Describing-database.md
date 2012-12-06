% The DBIx::Class Book
% Jess Robinson
% May 2011

Chapter 3 - Describing your database
====================================

Chapter summary
---------------

This chapter describes how to create a set of Perl classes using
DBIx::Class that describe your database tables, indexes and
relationships. The examples used will be based on a made-up schema
representing a blog software. We will introduce basic User and Post
tables and continue to use them throughout the rest of the book.

Pre-requisites
--------------

Examples given in this chapter will work with the one-file database SQLite[^sqlite], which can be installed for Perl by installing the CPAN module DBD::SQLite[^dbdsqlite].

You should already know what a database is, and understand the basic
SQL operation CREATE TABLE, refer to [](chapter_02-databases-design-and-layout)
if you need to. We will also assume that you know the basics of
writing Perl classes (and packages), and the keywords that go with
them. [^modernperl]

Download the skeleton code for this chapter: [](http://dbix-class.org/book/code/chapter03.zip).

Introduction
------------

DBIx::Class needs to be told about the structure of your database
tables and how the contents of the columns relate to each other, in
order to be able to form valid and efficient queries. This description
is done by creating a set of Perl classes containing definitions of
the tables.

While it is possible to have DBIx::Class dynamically extract this data
from your actual database at startup time, this is considered a method
of last resort. The main reason for this is that unexpected changes to
your database layout should cause your code to complain, and not
attempt to load and run anyway, potentially messing up your data.

Later we will cover ways of versioning and verifying your
schema[^schema] definitions.

Perl classes you need to create
-------------------------------

To fully describe your database structure for DBIx::Class, two types
of classes are needed:

* A **Schema class** defines the central object that is used to
contain and request all other objects representing the database
content. The schema object is created with connection information for
the particular database it will be talking to. The class can be
re-used to connect to a different instance of the database, with a
different connection string, if needed.

* A **Result class** should be defined for each table or view to be
accessed. this is used by DBIx::Class to represent a row of results
from a query done via that particular table or view. Methods acting on
a row of data can be added here.

Other types of classes can be used to extend the functionality of the
schema. These will be introduced later.

A word about module namespaces
------------------------------

Current best practice suggests that you name your DBIx::Class files in
the following way:

    ## The Schema class
    <Databasename|Appname>::Schema

    ## The result classes
    <Databasename|Appname>::Schema::Result::<tablename>

Here, __Databasename|Appname__ refers to the top-level namespace for
your application. If the set of modules are to be used as a standalone
re-usable set for just this database, use the name of the database or
something that identifies it. If your modules are part of an entire
application, then the application top-level namespace may go here.

    # Examples:
    MyBlog::Schema
    MyBlog::Schema::Result::User

While the table names in the database are often named using a plural,
eg _users_, the corresponding Result class is usually named in the
singular, as it respresents a single result, or row of a query.

The Schema class
----------------

The basic Schema class is fairly simple. It needs to inherit from
**DBIx::Class::Schema** and call a class method to load all the
associated Result classes.

    package MyBlog::Schema;
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema';

    __PACKAGE__->load_namespaces();

    1;

`load_namespaces` does the actual work here. It finds and loads all
the files found in the `Result` sub-namespace of your schema (see
[](chapter_03-a-word-about-module-namespaces) above). Files in the
`ResultSet` namespace (of which more in
[](chapter_06-components-and-extending)) will also be loaded, if
present. It can also be configured to use other namespaces or load
only a subset of the available classes by explicitly listing them.

The loaded files are assumed to be actual **Result classes** (see
below). If anything else is found in the sub-namespace, the load will
complain and die.

The Result class
----------------

Result classes are used for two purposes. Calls in the class itself,
which is a subclass of DBIx::Class::ResultSource, are used to describe
the source (table, view or query) structure of each basic building
block you will use to query the database. Secondly the objects that
result from those database queries are based upon your Result classes,
meaning any methods added to the class will be available to call on
those result objects.

When each Result class is loaded by the
[](chapter_03-the-schema-class), a ResultSource instance is created to
contain the database structure information. Later the ResultSource
object can be retrieved from the Schema object if needed, to ask it
information about the schema, for example to list the known columns on
a table.

A Result class is required for each table or view you need to access
or reference in your application. You do not need to create one for
every table and view in the database. For example if your database
contains tables `users`, `posts` and `statistics`, and you do not need
to access the `statistics` table in the code you are using with
DBIx::Class, just don't add a Result class for it.

Result classes should inherit from
**DBIx::Class::Core**[^corecomponent]. This loads a number of useful
sub-components such as the **PK** (Primary key) component for defining
and dealing with primary keys, and the **Relationship** component for
creating relations to other result classes. More details on these
below in [](chapter_03-a-closer-look-at-result-classes).

## Getting started, the User class

To show the Result class in action we will look at a simple `User`
class which might be used to represent users in any web
application. Each line of the complete class is shown together with an
explanation.

Our user table looks like this (in mysql or SQLite):

    CREATE TABLE users (
      id INT AUTO_INCREMENT,
      realname TINYTEXT,
      username TINYTEXT,
      password TINYTEXT,
      email TINYTEXT,
      PRIMARY KEY (id)
    );

The only complexity this class has is the inclusion of a component to
handle password storage and verification. While this class could be
shown with plaintext password storage and checking, it is better to show
re-usable code. You should never store passwords in plain text, always
always encrypt them. To run this code you will therefore need to
install the module
DBIx::Class::InflateColumn::Authen::Passphrase[^dbicap] and
its dependencies from CPAN.

This is the Result class for the users table:

    1. package MyBlog::Schema::Result::User;
    2. use strict;
    3. use warnings;
    4. use base 'DBIx::Class::Core';
    5.
    6. __PACKAGE__->load_components(qw(InflateColumn::Authen::Passphrase));
    7. __PACKAGE__->table('users');

Lines 1-4 are standard Perl code:

- Line 1

The `package` statement tells Perl which namespace the following code is
in.

- Lines 2 and 3

The `use strict` and `use warnings` lines turn on useful error
reporting in Perl.

- Line 4

`use base` tells Perl to make this class inherit from the given class.

A note about notation: `__PACKAGE__` is a Perl keyword which
represents the current package name. Here it is used to call class
methods inherited from DBIx::Class::Core to describe the source table
and its relationships. It is documented in perldata[^perldata].

Then we get to the DBIx::Class specific bits:

- Line 6

`load_components` is an inherited class method which injects new base
classes into the module. The argument is a list of class names, these
can be relative to the `DBIx::Class` namespace, or can be specified as
a full class name using a `+` prefix. Here we're adding
`DBIx::Class::InflateColumn::Authen::Passphrase` which will help us
handle password storage and verificatioon by using the
`Authen::Passphrase` module. See [](chapter_04-creating-user-rows) for
examples of how it helps us maintain passwords.

For more components and details on how to write your own, see
[](chapter_06-components-and-extending).

- Line 7

The `table` class method is used to set the name of the database table
or view this class represents. To use a table in a specific database
schema[^dbschema] supply the schema name and the table name separated by
a `.`, for example: `public.users`. This method must be called before calling
`add_columns` as it also injects the correct base class to make this a
Table source class.

### Describing the table structure

Now you can add lines describing the columns in your table.

    8. __PACKAGE__->add_columns(
    9.     id => {
    10.        data_type         => 'integer',
    11.        is_auto_increment => 1,
    12.    },
    13.    realname => {
    14.      data_type => 'varchar',
    15.      size      => 255,
    16.    },
    17.    username => {
    18.      data_type => 'varchar',
    19.      size      => 255,
    20.    },
    21.    password => {
    22.      data_type          => 'varchar',
    23.      size               => 255,
    24.      inflate_passphrase => 'rfc2307',
    25.    },
    26.    email => {
    27.      data_type => 'varchar',
    28.      size      => 255,
    29.    },
    30. );

    31. __PACKAGE__->set_primary_key('id');
    32. __PACKAGE__->add_unique_constraint('username_idx' => ['username']);

- Line 8

`add_columns` is called to define all the columns in your table that
you wish to tell DBIx::Class about. You do not need to list all the
available database columns, however unless they have default values
set in the database, leaving them out will prevent you from creating
new database rows using this class.

For every column we list, DBIx::Class will create an accessor method
on our Row objects later, using the column name we give here.

The `add_columns` call can provide as much or little description of the
columns as it likes. In its simplest form, it can contain just a list
of column names:

    __PACKAGE__->add_columns(qw/id realname username password email/);

This will work quite happily, but will not take advantage of useful
DBIx::Class functionality, such as fetching the data for
auto-incrementing columns from the database after a row is created.

The longer version with full column info, used above, has several
advantages. It can be used to create actual database tables from the
schema, with all the correct sizes and other attributes. It also
serves as a useful reminder to the developer of the columns available.

We suggest supplying at a minimum, the `data_type` of the column and
`is_autoincrement` on self-incrementing columns where appropriate.

Note: Some databases allow column names containing spaces and other
characters which are not allowed in perl identifiers, and thus cannot
be used for the accessor method names. To get around this we can add
another key to our column description named `accessor` and set its
value to a usable name for the accessor.

- Lines 9 to 12

We add a column called `id` to store the *primary key* of the
table. This will store a unique `integer` for each row in the
table. The primary key will use a self-incrementing field which most
databases supply, so we set `is_auto_increment` to 1.

Setting the `is_auto_increment` flag to true causes this value to be
fetched from the database after a new row is created, and stored in
our `Row` object. It is also used when translating the schema into SQL
`CREATE TABLE` statements, to setup the column appropriately.

- Lines 17 to 20

The `username` column is a `varchar` (string) datatype which requires
a `size` parameter to tell the database the maximum length data in the
column can be. The MySQL `*TEXT` (TINYTEXT, MEDIUMTEXT, LONGTEXT)
types can also be used instead, which are string columns with a preset
lengths.

- Lines 21 to 24

The `password` column is another text column, which will store an
SHA-1[^sha1] representation of the password. The `inflate_passphrase`
setting is used to tell the
DBIx::Class::InflateColumn::Authen::Passphrase module which type of
encryption to use for the passwords. `rfc2307` indicates an encoded string which also stores the type of encoding used, see the Authen::Passphrase[^authenpassphrase] module for details.

- Line 31

The `set_primary_key` method tells DBIx::Class which column or columns
contain your *primary key* data for this table.

The term `PRIMARY KEY` is used in SQL to define a column or set of
columns that be used to uniquely identify a single row in the
table. DBIx::Class uses the same concept to identify rows for update
or deletion. The same unique values will also be used to connect two
tables containing related data.

The list of columns for the `set_primary_key` call do not need to
match the `PRIMARY KEY` in your database, and can even be supplied if
the database does not have primary keys set at all.

- Line 32

`add_unique_constraint` is called to let DBIx::Class know when your
table has other columns which hold unique values across rows (other
than the primary key, which must also be unique). The first argument
is a name for the constraint which can be anything, the second is a
arrayref of column names.

Note: We've just looked at some of the available keys available for
setting on columns. Here are the other available keys and their
uses. Some of these will be put into use later:

default_value
:    string, number or scalar reference (for a function or other literal SQL)

is_nullable
:    true or false value (default is false) which sets up the table in the database to allow `NULL` values in this column. `NULL` is a special SQL keyword which means "no value". DBIx::Class represents NULL values with `undef`.

retrieve_on_insert
:    fetch the value for this column from the database after we create a new row. This is useful for automatically created such as timestamps.


### Cross-Table relationships

The table structure information alone will allow you to query and
manipulate individual tables using DBIx::Class. However, DBIx::Class'
strength lies in its ability to create database queries that join data
across multiple tables. In order to create these queries, the linking
info between tables needs to be defined. This is done using the
various _relationship_ methods.

We'll add in a relationship to a `posts` table to demonstrate using
these. The `posts` table will contain a column called `user_id` to
indicate which User authored each Post entry.

    33. __PACKAGE__->has_many('posts', 'MyBlog::Schema::Result::Post', 'user_id');

- Line 33

To describe a _one to many_ relationship we call the `has_many`
method. For this one, the `posts` table has a column named
`user_id` that contains the _id_ of a row in the `users` table.

The first argument, `posts`, is a name for the relationship, this is
used as an accessor to retrieve the related items. It is also used as
an alias when creating queries to join tables.

The second argument, `MyBlog::Schema::Result::Post`, is the class name
for the related Result class file.

The third argument, `user_id`, is the column in the related table that
contains the primary key of the table we are writing the relationship
on.

Note: When the Schema class is loaded, all relationship classes are
verified, so this `has_many` line will cause the code not to compile
until the `Post` Result class exists. We will be adding it soon,
comment out this line for now if you wish to check if your schema
compiles.

Other relationship types are available:

* belongs_to
    
    The `Posts` table has a column named `user_id` which is used to
store the `id` value of the user that authored the post. We create a
`belongs_to` relationship called `user` on the `Post` class, which
will return the user object for that author. SQL calls this a `FOREIGN
KEY` column.

        __PACKAGE__->belongs_to('user', 'MyBlog::Schema::Result::Post', 'user_id');

* has_one

    An `Address` table contains one home address row for each
user. The `Address` table contains a `user_id` column to store the
`id` of user living at this address. In the `User` class we setup a
`has_one` call to state this relationship.

        __PACKAGE__->has_one('home_address', 'MyBlog::Schema::Result::Address', 'user_id');

    `has_one` is like a `has_many` call except that it knows in
advance it will will have exactly one match, so the accessor method
will return one object, not a set of possibly zero or more.

    On the `Address` class, we add a `belongs_to` relationship just like in the `Post` class.

* might_have

    The `User` may or may not have a home address in our database, we
want to make it optional to provide that information (hooray!). We
create a `might_have` relationship instead of the `has_one`. The
difference between these two is that any SQL queries between the two
tables will include a `LEFT` keyword in the `JOIN` statement. This
tells the database that we want all Users, regardless of whether they
have an Address entry or not.

        __PACKAGE__->might_have('home_address', 'MyBlog::Schema::Result::Address', 'user_id');


Note: There is no corresponding `might_belong_to` relationship. We can
configure a `belongs_to` relationship to allow for example, a post to
exist without an author. To do this, set the `join_type` attribute in
the fourth argument to the relationship call:

        __PACKAGE__->belongs_to('user', 'MyBlog::Schema::Result::Post', 'user_id', { join_type => 'LEFT' });


## A closer look at Result classes

The following is a look at how Result classes work internally. You
don't necessarily need to know this to use DBIx::Class, however it
will likely to be useful for debugging and better
understanding. Result classes are fairly complex entities. They serve
both as the basis to create a `ResultSource` object to hold the table
layout definitions, and as a base `Row` object returned from querying
the database. They are also built by injecting base classes in several
ways.

Result classes should inherit from `DBIx::Class::Core`. Core is a
empty class (no code of its own) which inherits from
`DBIx::Class::Relationship`', `DBIx::Class::InflateColumn`,
`DBIx::Class::PK`, `DBIx::Class::Row` and
`DBIx::Class::ResultSourceProxy::Table`. These are all useful parts
for building Result classes representing tables or views.

Of these, the `ResultSourceProxy::Table` class is the one which sets
up the ResultSource object and injects the correct type of base class
for this Result class. The `table` class method does the actual work
by taking the name of the actual database table in the backend
database, and constructing the `ResultSource` object based upon
it. This must be called before the `add_columns` class method which
only exists in the newly injected base class. To retrieve information
about your columns and so on later in your code, you can get the
ResultSource object by calling the `result_source` method on `Row` and
`ResultSet` objects.

Note: Later on (in
[](chapter_05-real-or-virtual-views-and-stored-procedures)) we will
see how to construct a Result class (and thus ResultSource object)
representing a database view instead of a table. We can of course
happily pretend that views are tables if we just want to read from
them.

The `Relationship` base class adds more new injected base classes for
use with both ResultSource and Row objects. These allow us to
construct various types of links between our tables. Relationships are
a fundamental DBIx::Class concept and will be explained and used
throughout this book.

The rest of the classes inherited from `Core` are used to add
functionality to the `Row` objects which result from actual database
queries. Briefly these are:

* `InflateColumn` - Return objects representing column data instead of scalars, see [](chapter_06-turning-column-data-into-useful-objects)

* `PK` - Provides the `id` and `ident_condition` methods to return the unique value or values represnting the `Row` object.

* `Row` - The bulk of the Row object functionality, provides the `insert`, `update`, `delete` methods plus many many more.

The original idea of all these sub-classes was to allow developers to
construct Result classes using only a subset of the parts if not all
of them were needed. However this turns out to be very rarely the
case, so we advocate using DBIx::Class::Core as your base class.

Note: You may have noticed, if you're actually looking at the source,
that I skipped over the `PK::Auto` class that `Core` imports. This is
because it is empty, all the functionality has been moved into the
`Row` class, closer to where it is used.

## Your turn, The Post class

The posts table looks like this in mysql:

    CREATE TABLE posts (
      id INT AUTO_INCREMENT,
      user_id INT,
      created_date DATETIME,
      title VARCHAR(255),
      post VARCHAR(255),
      INDEX posts_idx_user_id (user_id),
      PRIMARY KEY (id),
      CONSTRAINT posts_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id)
    );

You will need to create a `belongs_to` relationship for this class. Use it like this:

    __PACKAGE__->belongs_to('user', 'MyBlog::Schema::Result::User', 'user_id');

As before, the first argument, `user`, is the name of the
relationship, used as an accessor to get the related `User`
object. It is also used in searching to join across the tables.

The second argument is the related class, the `User` class we created
before.

The third argument is the column in the current class that contains
the primary key of the related class, the *foreign key* column.

You should also use the
DBIx::Class::InflateColumn::DateTime[^datetime] component, which will
turn the `created_date` field into a DateTime object for you. No
configuration is needed.

Create the Result class for it as MyBlog::Schema::Result::Post.

When you're done, run this test which you can find in the
_create-post-class.t_ file in the downloadable content for this
chapter.

    #!/usr/bin/perl

    use strict;
    use warnings;

    use Test::More;

    use_ok('MyBlog::Schema');

    my $db = 't/var/test.db';
    unlink $db;

    my $schema = MyBlog::Schema->connect("dbi:SQLite:$db");
    $schema->deploy();

    ## New Post source must exist;
    ok($schema->source('Post'), 'Post source exists in schema');

    ## Not running source tests if not there, will have failed above already
    SKIP: {
        my $source = $schema->source('Post');
        skip "Source Post not found", 7 if(!$source);

        ## Expected component
        isa_ok($schema->source('Post'), 'DBIx::Class::InflateColumn::DateTime', 'DateTime component has been added');

        ## Expected columns:
        foreach my $col (qw/id user_id created_date title post/) {
            ok($schema->source('Post')->has_column($col), "Found expected Post column '$col'");
        }
        is_deeply([$schema->source('Post')->primary_columns()], ['id'], 'Found expected primary key col "id" in Post source');


        ## Expected relationships:
        ok($schema->source('Post')->relationship_info('user'), 'Found a relationship named "user" in the Post source');
        is($schema->source('Post')->relationship_info('user')->{attrs}{accessor}, 'single', 'User relationship in Post source is a single accessor type');
    }

    done_testing(11);

If you get stuck you can look at the copy of the Post class provided in the _exercises_ section of the downloadable code. You will need this class for later chapters, so make sure you have a working copy before continuing.

Basic usage
-----------

### Create a database from SQL

If you already have an SQL file, or you feel more comfortable writing
one, you can create your initial database layout using it. In the
downloadable content for this chapter you will find the _myblog.sql_
file which contains the SQL for the two tables we've been looking
at. To create an SQLite database we will need the SQLite
DBD[^dbdsqlite], which should have been installed along with
DBIx::Class, then run the built-in `sqlite3` binary:

    sqlite3 myblog.db < myblog.sql

### Create a database using DBIx::Class

DBIx::Class can also be used to create a database using your class files. To do this you will need the SQL::Translator[^sqlt] package installed.

First `connect` to the Schema class (this returns a Schema object), using a DSN[^dsn]. Then use the `deploy` method on the Schema object. This calls SQL::Translator to create a set of SQL CREATE statements for the database we connected to, then it sends the statements to the database itself.

    perl -MMyBlog::Schema -le'my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db"); $schema->deploy();'

We will discuss more about deploying in [](chapter_07-installing-versioning-and-migrating) when talking about how to change your schema without
having to destroy your existing data.

### Quick usage 

A short script to try out your classes:

    #!/usr/bin/env perl
    use strict;
    use warnings;

    use MyBlog::Schema;
    use Authen::Passphrase::SaltedDigest;

    my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db");
    my $fred = $schema->resultset('User')->create({ 
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      realname => 'Fred Bloggs',
      email => 'fred@bloggs.com',
    });
    
    print $fred->email;

Learn what all this does in Chapter 4!

Alternative class creation
--------------------------

Now that you've (hopefully) read this chapter and understood how the
classes that DBIx::Class uses work, we'll take a short look at how to
extract all this data automatically from an existing database, if you
have one.

The separate module DBIx::Class::Schema::Loader[^loader], is available
on CPAN. It can be used to query most makes of relational database and
write out a set of Result class files and a Schema class for
you. These classes will also contain a checksum, which enables you to
add your own code to the classes, and still be able to re-run the
database export when the database layout is changed.

Without further ado, install the module, then run the included
`dbicdump` script:

    dbicdump MyBlog::Schema 'dbi:SQLite:myblog.db'

This is the most basic way to use the tool, this will create a set of
files in the current directory, using `MyBlog::Schema` as the
top-level namespace, and pulling the data from the SQLite database in
the _myblog.db_ file.

There are many possible options to refine the output, you can
`exclude` some tables from the export, choose a particular `db_schema`
to get tables from, and choose which `dump_directory` to put the files
in. Refer to the whole list in the documentation[^loaderoptions]. Some
of these will make more sense as you go through the book, refer back
to the options documentation as you go.

The created Result class files will by default be named in the
singular, so a table named `users` will produce a class named
`User`. The classes will also contain appropriate relationships, as
long as the database contains the appropriate constraints.

What's next
-----------

You now have a couple of well-defined Result classes we can use to
actually create and query some data from your database. On to chapter
4 where we look at how to that and much more.


[^sqlite]: [](http://www.sqlite.org)
[^dbdsqlite]: [](http://metacpan.org/module/DBD::SQLite)
[^dbicap]: [](http://metacpan.org/module/DBIx::Class::InflateColumn::Authen::Passphrase)
[^authenpassphrase]: [](http://metacpan.org/module/Authen::Passphrase)
[^modernperl]: Read Learning Perl or Modern Perl to gain a basic understanding of Perl classes and packages.
[^schema]: A collection of classes used to describe a database for DBIx::Class is called a "schema", after the main class, which derives from DBIx::Class::Schema.
[^dbschema]: Database schemas are used to create subsets of tables in a database, usually to assign different user permissions to sets of tables. They don't exist in all databases, MySQL doesn't have any, and SQLite uses the same notation to 
[^corecomponent]: It is also possible to inherit purely from the `DBIx::Class` class, and then load the `Core` component, or each required component, as needed. Components will be explained later.
[^dsn]: Data Source Name, connection info for a database, see [DBI](http://search.cpan.org/perldoc?DBI)
[^loader]: [](http://metacpan.org/module/DBIx::Class::Schema::Loader)
[^loaderoptions]: [](http://metacpan.org/module/DBIx::Class::Schema::Loader::Base#CONSTRUCTOR-OPTIONS)
[^perldata]: [](http://metacpan.org/module/perldata).
[^dbdsqlite]: [](http://metacpan.org/module/DBD::SQLite)
[^sqlt]: [](http://metacpan.org/module/SQL::Translator)
[^datetime]: The module is included as part of the DBIx::Class distribution, so no need to install it. The documentation can be viewed here: [](http://metacpan.org/module/DBIx::Class::InflateColumn::DateTime)
