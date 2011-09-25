% The DBIx::Class Book
% Jess Robinson
% May 2011

Chapter 3 - Describing your database
====================================

Chapter summary
---------------

This chapter describes how to create a set of Perl modules using
DBIx::Class that describe your database tables, indexes and
relationships. The examples used will be based on a made-up schema
representing a blog, we will introduce basic User and Post tables.

Pre-requisites
--------------

[%# This should probably be at the beginning of the book as its prevalent? #%]

Examples given in this chapter will work with the one-file database [SQLite](http://www.sqlite.org), which can be installed for Perl by installing the CPAN module [DBD::SQLite](http://search.cpan.org/dist/DBD-SQLite).

You should already know what a database is, and understand the basic
SQL operation CREATE TABLE, refer to [Chapter 2](02-Database-design)
if you need to. We will also assume that you know the basics of
writing Perl classes (and packages), and the keywords that go with
them. [^modernperl]

[%# this bit needs moving into the main text somewhere #%]
If you already have a database that you are using you can still create
these files by hand following this chapter. You can also use
[DBIx::Class::Schema::Loader](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader) to create them automatically. Read the
documentation of that manual, or look in
[Appendix2](http://search.cpan.org/perldoc?DBIx::Class::Tutorial::Appendix2) on how to do that.

Introduction
------------

DBIx::Class needs to be told about the structure of your database
tables and how the contents of the columns relate to each other, in
order to be able to form valid and efficient queries. This description
is done by creating a set of Perl classes containing the definitions.

While it is possible to have DBIx::Class dynamically extract this data
from your actual database at startup time, this is considered a method
of last resort.[^schemaloader] The main reason for this is that
changes to your database layout in unexpected ways should cause your
code to complain, and not attempt to load and run anyway, potentially
messing up your data.

Later we will cover ways of versioning and verifying your schema[^schema] definitions.

Perl classes you need to create
-------------------------------

To fully describe your database structure for DBIx::Class, two types
of classes are needed:

* A **Schema class** defines the central object that is used to
contain and request all other objects representing the database
content. The schema object is created with connection information for
the particular database it will be talking to. The class can be
re=used to connect to a different instance of the database, with a
different connection string, if needed.

* A **Result class** should be defined for each table or view to be
accessed, this is used by DBIx::Class to represent a row of results
from a query done via that particular table or view. Methods acting on
a row of data can be added here.

Other types of classes can be used to extend the functionality of the
schema, these will be introduced later.

<a name="#a-word-about-namespaces"></a>

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
singular, as it respresents a single result, or row of the query.

The Schema class
----------------

The basic Schema class is fairly simple, it needs to inherit from
**DBIx::Class::Schema** and call a class method to load all the
associated Result classes.

    package MyBlog::Schema;
    use warnings;
    use strict;
    use base 'DBIx::Class::Schema';

    __PACKAGE__->load_namespaces();

    1;

`load_namespaces` does the actual work here, it finds and loads all
the files found in the `Result` subnamespace of your schema, see [A
word about namespaces](#a-word-about-namespaces) above. It can also be
configured to use other namespaces, or load only a subset of the
available classes, by explicitly listing them.

The loaded files are assumed to be actual **Result classes** (see
below) if anything else is found in the subnamespace, the load will
complain and die.

[%#
For discussions of alternative styles and methods of writing Schema
classes, see [Alternative Schema classes](#pod_Alternative Schema classes) below.
%]

The Result class
----------------

Result classes are used for two purposes. Calls in the class itself,
which is a subclass of DBIx::Class::ResultSource, are used to describe
the source (table, view or query) structure of each basic building
block you will use to query the database. Secondly the objects that
result from those database queries are based on your Result classes,
meaning any methods added to the class will be available to call on
those result objects.

When each Result class is loaded by the [Schema
class](#the-schema-class), a ResultSource instance is created to
contain the database structure information. Later the ResultSource
object can be retrieved from the Schema object if needed, to ask it 
information about the schema, for example to iterate through the
known columns on a table.

Result classes are only needed for each data source you need to access
in your application, you do not need to create one for every table and
view in the database.

Result classes should inherit from
**DBIx::Class::Core**[^corecomponent]. This loads a number of useful
sub-components such as the **PK** (Primary key) component for defining
and dealing with primary keys, and the **Relationship** component for
creating relations to other result classes.

## Getting started, the User class

To show the Result class in action we will look at a simple `User`
class which might be used to represent users in any web
application. Each line of the complete class is shown together with an
explanation.

Our user table looks like this (in mysql or SQLite):

    CREATE TABLE users (
      id INTEGER AUTOINCREMENT PRIMARY KEY,
      realname VARCHAR(255),
      username VARCHAR(255),
      password VARCHAR(255),
      email VARCHAR (255)
    );

This is the result class for the users table:

    1. package MyBlog::Schema::Result::User;
    2. use strict;
    3. use warnings;
    4. use base 'DBIx::Class::Core';
    5.
    6. __PACKAGE__->load_components(qw(InflateColumn::Authen::Passphrase));
    7. __PACKAGE__->table('users');

Lines 1-4 are standard Perl code:

- Line 1

The `package` statement tells Perl which module the following code is
defining.

- Lines 2 and 3

The `use strict` and `use warnings` lines turn on useful error
reporting in Perl.

- Line 4

`use base` tells Perl to make this module inherit from the given module.

A note about notation: ___PACKAGE___ is the same as the current
package name in Perl, and continues to be correct for inherited
classes, so you will see it all over the example code. It is
documented in [perldata](http://search.cpan.org/perldoc?perldata).

Then we get to the DBIx::Class specific bits:

- Line 6

`load_components` comes from [DBIx::Class::Componentised](http://search.cpan.org/perldoc?DBIx::Class::Componentised) and is
used to load a series of modules whose methods can delegate to each
other. Thus components need to be loaded in a specific order. The
[DBIx::Class::Core](http://search.cpan.org/perldoc?DBIx::Class::Core) component should always be loaded last so that
its methods are called after those of other components.

Here we're loading an inflate/deflate module to which can inflate database content into an object, and deflate incoming data from an object back into the database. The Authen::Passphrase module hashes passwords as they're entered into the database, and inflate back to an object which can be used to verify them.

For some examples of other useful components, see Chapter XX

- Line 7

The `table` method is used to store the name of the database table this class represents. The name of a database view can also be used here. The method is inherited from `DBIx::Class::ResultSourceProxy::Table` which is loaded as a subclass by `DBIx::Class::Core`.

Calling the `table` method sets up the [DBIx::Class::ResultSource](http://search.cpan.org/perldoc?DBIx::Class::ResultSource)
instance ready for adding columns to, so this method must be
called __before__ `add_columns` (see below).

### Describing the table structure

Now you can add lines describing the columns in your table.

    8. __PACKAGE__->add_columns(
    9.     id => {
    10.        data_type => 'integer',
    11.        is_auto_increment => 1,
    12.    },
    13.    realname => {
    14.      data_type => 'varchar',
    15.      size => 255,
    16.    },
    17.    username => {
    18.      data_type => 'varchar',
    19.      size => 255,
    20.    },
    21.    password => {
    22.      data_type => 'varchar',
    23.      size => 255,
    24.      inflate_passphrase => 'rfc2307',
    25.    },
    26.    email => {
    27.      data_type => 'varchar',
    28.      size => 255,
    29.    },
    30. );

    31. __PACKAGE__->set_primary_key('id');
    32. __PACKAGE__->add_unique_constraint('username_idx' => ['username']);

- Line 8

`add_columns` is called to define all the columns in your table that
you wish to tell DBIx::Class about, you may leave out some of the
table's columns if you wish. 

The `add_columns` call can provide as much or little description of the
columns as it likes, in its simplest form, it can contain just a list
of column names:

    __PACKAGE__->add_columns(qw/id realname username password email/);

This will work quite happily.

The longer version with full column info, used above, has several
advantages. It can be used to create actual database tables from the
schema, with all the correct sizes and other attributes. It also
serves as a useful reminder to the developer of the columns available.

For the full documentation of the `add_columns` method, see the
DBIx::Class::ResultSource docs.

- Lines 9 to 12

We add a column called `id` to store the _primary key_ of the
table. This will store a unique `integer` for each row in the
table. The primary key will use a self-incrementing field which most
databases supply, so we set `is_auto_increment` to 1.

- Line 15

The username column is a `varchar` datatype which requires a `size`
parameter to tell the database the maximum length data in the column
can be.

- Line 31

The `set_primary_key` method tells DBIx::Class which column or columns
contain your _primary key_ data for this table.

The _primary key_ should contain a column or set of columns that can
be used to uniquely identify a single row in the table. DBIx::Class
will use them to delete or update single rows.

[%# mention this with the create() call ? 
The primary key columns are used by DBIx::Class to determine which
values it should add to the row object after it has been inserted into
the database. They are also used when automatically joining two
tables.

This and other methods dealing with primary keys are described in
[DBIx::Class::PK](http://search.cpan.org/perldoc?DBIx::Class::PK).

#%]

- Line 32

`add_unique_constraint` is called to let DBIx::Class know when your
table has other columns which hold unique values across rows (other
than the primary key, which must also be unique). The first argument
is a name for the constraint which can be anything, the second is a
arrayref of column names.

### Cross-Table relationships

The table structure information alone will allow you to query and
manipulate individual tables using DBIx::Class. However, DBIx::Class'
strength lies in its ability to create database queries that join
across multiple tables. In order to create these queries, the linking
info between tables needs to be defined. This is done using
_relationship_ methods.

    32. __PACKAGE__->has_many('posts', 'MyBlog::Schema::Result::Post', 'user_id');

- Line 32

To describe a _one to many_ relationship we call the `has_many`
method. For this one, the `posts` table has a column named
`user_id` that contains the _id_ of the `users` table.

The first argument, `posts`, is a name for the relationship, this is
used as an accessor to retrieve the related items. It is also used
when creating queries to join tables.

The second argument, `MyBlog::Schema::Result::Post`, is the class name
for the related Result class file.

The third argument, `user_id`, is the column in the related table that
contains the primary key of the table we are writing the relationship
on.

### Notes on Result classes

- Data types

    The `data_type` field for each column in the `add_columns` is a free
text field, it is only used by DBIx::Class when deploying (creating
tables) the schema to a database. At that point `data_type` values
are converted to the appropriate type for your database by
[SQL::Translator](http://search.cpan.org/perldoc?SQL::Translator).

- Column names

    In an ideal world, all column names in your database would be valid
perl identifiers, that is consist of only word [a-zA-Z_] or digit
[0-9] characters. As this is not always the case, the column info
hashref for each column can also contain an `accessor` key which
provides a valid perl identifier name which will be used to create the
accessor method for the column.

[%# this goes elsewhere!
Note that the original name will still need to be used when creating new rows or searching on the database.
#%]

- More relationship types

* belongs_to

    Defines an accessor method for fetching the foreign row referenced by a foreign key column. 

* has_one

    Creates an accessor for fetching a single row that contains our _primary key_. This is like `has_many` but assumes exactly one matching row.

* might_have

    Accessor for a single matching row that contains our _primary key_. Very similar to `has_one`, but creates a `left` type join as the related row may not exist at all.

### Exercise: The Post class

The posts table looks like this in mysql:

    CREATE TABLE posts (
      id INT AUTO_INCREMENT,
      user_id INT,
      created_date DATETIME,
      title VARCHAR(255),
      post TEXT,
      INDEX posts_idx_user_id (user_id),
      PRIMARY KEY (id),
      CONSTRAINT posts_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id)
    );

You will need to create a `belongs_to` relationship for this class. Use it like this:

    __PACKAGE__->belongs_to('user', 'MyBlog::Schema::Result::User', 'user_id');

As before, the first argument, `user`, is the name of the
relationship, used as an accessor to get the related _User_
object. It is also used in searching to join across the tables.

The second argument is the related class, the _User_ class we created
before.

The third argument is the column in the current class that contains
the primary key of the related class, the _foreign key_ column.

Create the Result class for it as MyBlog::Schema::Result::Post.

#### Test it!

See appendix ## or the downloadable content for the skeleton Chapter 3 code. Add your Post.pm file to the lib/MyBlog/Schema/Result/ directory. Run the test in t/create-post-class.t file.

Basic usage
-----------

### Create a database

In the appendix ## and in the downloadable content, there is an .sql
file containing the tables described in this chapter. To run this you will need [the SQLite DBD](http://search.cpan.org/dist/DBD-SQLite), which should have been installed along with DBIx::Class, then you can create the database like this:

    sqlite3 myblog.db < myblog.sql

### Making a database using DBIx::Class

DBIx::Class can also be used to create a database using your class files. To do this you will need the [SQL::Translator](http://search.cpan.org/dist/SQL-Translator) package installed.

First `connect` to the Schema class (this returns a Schema object), using a DSN[^dsn]. The `deploy` method on the Schema object calls SQL::Translator to output the appropriate SQL CREATE statements for the chosen database given in the DSN, then it sends the statements to the database itself.

    perl -MMyBlog::Schema -le'my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db"); $schema->deploy();'

We will discuss [deployment](http://search.cpan.org/perldoc?DBIx::Class::Tutorial::Deployment) more
at length later when talking about how to change your schema without
having to destroy your existing data.

### Quick usage 

A short script to test your classes:

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


CONCLUSIONS
-----------

You now have a couple of well-defined Result classes we can use to
actually create and query some data from your database.


[^modernperl]: Read Learning Perl or Modern Perl to gain a basic understanding of Perl classes and packages.
[^schemaloader]: [DBIx::Class::Schema::Loader](http://search.cpan.org/dist/DBIx-Class-Schema-Loader]
[^schema]: A collection of classes used to describe a database for DBIx::Class is called a "schema", after the main class, which derives from DBIx::Class::Schema.
[^corecomponent]: It is also possible to inherit purely from the `DBIx::Class` class, and then load the `Core` component, or each required component, as needed. Components will be explained later.
[^dsn]: Data source name, connection info for a database, see [DBI](http://search.cpan.org/perldoc?DBI)


