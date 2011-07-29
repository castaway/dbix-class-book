Chapter 4 - Creating, Reading, Updating and Deleting
====================================================

Chapter summary
---------------

In this chapter we will show how to do basic database operations using your DBIx::Class classes. We are using the MyBlog schema described in [chapter 3]()

Pre-requisites
--------------

We will be giving code examples and comparing them to the SQL statements that they produce, you should have basic SQL knowledge to understand this chapter. The database we are using is provided as an SQL file to import into an [SQLite database](http://search.cpan.org/dist/DBD-SQLite) to get started. You should also have basic knowledge of object-oriented code and Perl classes.

Introduction
------------

The DBIx::Class classes (also called your DBIC schema) contain all the data needed to produce and execute SQL commands on the database. To run commands we just manipulate the objects representing the data.

## Create a Schema object using a database connection

All the database manipulation with DBIx::Class is done via one central object, which maintains the connection to the database via a [storage object](## storage link). To create a schema object, call `connect` on your DBIx::Class::Schema subclass, passing it a [Data Source Name][^dsn].

    my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db");
    
Keep the `$schema` object in scope, if it disappears, other DBIx::Class objects you have floating about will stop working. 

To pass a username and password for the database, just add the strings as extra arguments to `connect`, for example when using MySQL:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

You can also pass various [DBI](http://search.cpan.org/dist/DBI) connection parameters by passing a fourth argument containing a hashref. This is also used by DBIx::Class to set options such as the correct type of quote to use when quoting table names, eg:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword", { quote_char => "`'");

For more detailed information about all the available connection arguments, see the [connect_info documentation](http://search.cpan.org/perldoc?DBIx::Class::Storage::DBI)

## Accessing data, the empty query aka ResultSet

To manipulate any data in your database, you first need to create a **ResultSet** object. A ResultSet is an object representing a potential query, it is used to store the conditions and joins needed to producte the SQL statement.

ResultSets can be fetched using the **Result class** names, for example the users table is in `User.pm`, to fetch its ResultSet, using the `resultset` method:

    my $users_rs = $schema->resultset('User');

Now we can move on to some actual database operations ... 

## Creating users

Now that we have a ResultSet, we can start adding some data. To create one user, we can collect all the relevant data, and initiate and insert the **Row** all at once, by calling `create`:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword", { quote_char => "`'");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->create({
      realname => 'Fred Bloggs',
      username => 'fred',
      password => 'mypass',
      email => 'fred@bloggs.com',
    });
    
`create` is the equivalent of calling `new_result` followed by `insert`, so you can also do this:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword", { quote_char => "`'");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->new_result();
    $fred->realname('Fred Bloggs');
    $fred->username('fred');
    $fred->password('mypass');
    $fred->email('fred@bloggs.com');
    $fred->insert();

Note how all the columns described in the `User.pm` class appear on the **Row object** as accessor methods.

Using the environment variable [`DBIC_TRACE`](## appendix?) set to a true value, will display the SQL statement for either of these on STDOUT:

    INSERT INTO users (realname, username, password, email) VALUES (?, ?, ?, ?): 'Fred Bloggs', 'fred', 'mypass', 'fred@bloggs.com'

NB: The `?` symbols are placeholders, the actual values will be quoted according to your database rules, and passed in.

## We also didn't provide a value for the auto-incrementing primary key here, t

## Create a User entry, prove it worked with a test

## Importing multiple rows at once, test results

## Finding and updating one row

## Create a Post entry for the user

## Update many rows at once

## Deleting a row or rows

## Advanced create/update/delete
