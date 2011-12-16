Chapter 4 - Creating, Reading, Updating and Deleting
====================================================

Chapter summary
---------------

In this chapter we will show how to do basic database operations using your DBIx::Class classes. We are using the MyBlog schema described in [chapter 3]()

Pre-requisites
--------------

We will be giving code examples and comparing them to the SQL statements that they produce, you should have basic SQL knowledge to understand this chapter. The database we are using is provided as an SQL file to import into an [SQLite database](http://search.cpan.org/dist/DBD-SQLite) to get started. You should also have basic knowledge of object-oriented code and Perl classes.

[Download url]() / preparation?

Introduction
------------

The DBIx::Class classes (also called your DBIC schema) contain all the data needed to produce and execute SQL commands on the database. To run commands we just manipulate the objects representing the data.

## Create a Schema object using a database connection

All the database manipulation with DBIx::Class is done via one central Schema object, which maintains the connection to the database via a [storage object](## storage link). To create a schema object, call `connect` on your DBIx::Class::Schema subclass, passing it a [Data Source Name][^dsn].

    my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db");
    
Keep the `$schema` object in scope, if it disappears, other DBIx::Class objects you have floating about will stop working. 

To pass a username and password for the database, just add the strings as extra arguments to `connect`, for example when using MySQL:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

You can also pass various [DBI](http://search.cpan.org/dist/DBI) connection parameters by passing a fourth argument containing a hashref. This is also used by DBIx::Class to set options such as the correct type of quote to use when quoting table names, eg:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword", { quote_char => "`'", quote_sep => '.' });

For more detailed information about all the available connection arguments, see the [connect_info documentation](http://search.cpan.org/perldoc?DBIx::Class::Storage::DBI)

## Accessing data, the empty query aka ResultSet

To manipulate any data in your database, you first need to create a **ResultSet** object. A ResultSet is an object representing a potential query, it is used to store the conditions and joins needed to produce the SQL statement.

ResultSets can be fetched using the **Result class** names, for example the users table is in `User.pm`, to fetch its ResultSet, using the `resultset` method:

    my $users_rs = $schema->resultset('User');

Now we can move on to some actual database operations ... 

## Creating users

Now that we have a ResultSet, we can start adding some data. To create one user, we can collect all the relevant data, and initiate and insert the **Row** all at once, by calling the `create` method:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->create({
      realname => 'Fred Bloggs',
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
    });
    
`create` is the equivalent of calling the `new_result`[^new_result] method, which
returns a **Row** object, and then calling the `insert` method on it,
so you can also do this:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->new_result();
    $fred->realname('Fred Bloggs');
    $fred->username('fred');
    $fred->password(Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
    ));
    $fred->email('fred@bloggs.com');
    $fred->insert();

Note how all the columns described in the `User.pm` class using `add_columns` appear on the **Row object** as accessor methods.

To see what's going on, set the shell environment variable [`DBIC_TRACE`](## appendix?) to a true value, and DBIx::Class will display the SQL statement for either of these code samples on STDOUT:

    INSERT INTO users (realname, username, password, email) VALUES (?, ?, ?, ?): 'Fred Bloggs', 'fred', 'XXYYZZ', 'fred@bloggs.com'

NB: The `?` symbols are placeholders, the actual values will be quoted according to your database rules, and passed in.

As the `id` column was defined as being `is_auto_increment` we haven't
supplied that value at all, the database will fill it in, and the
`insert` call will fetch the value and store it in our `$fred`
object. It will also do this for other database-supplied fields if
defined as `retrieve_on_insert` in `add_columns`.

### Your turn, create a User and verify with a test

Now that's all hopefully made sense, time for a bit of Test-Driven-Development. 

This is a short Perl test that will check that a user, and only one user, with the `email` of **alice@bloggs.com** exists in the database. You can type it up into a file named **check-alice-exists.t** in t/ directory, or unpack it from the provided tarball.

Note, there are tests for a couple of other things too, happy coding!

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use Test::More;
    use_ok('MyBlog::Schema');

    unlink 't/var/myblog.db';
    my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
    $schema->deploy();
    ## Your code goes here!
    
    
    ## Tests:   
    my $users_rs = $schema->resultset('User')->search({ email => 'alice@bloggs.com' });
    is($users_rs->count, 1, 'Found exactly one alice user');

    my $alice = $users_rs->next();
    is($alice->id, 1, 'Magically discovered Alice's PK value');
    is($alice->username, 'alice', 'Alice has boring ole username of "alice"');
    ok($alice->password->match('aliceandfred'), "Guessed Alice's password, woot!');
    like($alice->realname, qr/^Alice/, 'Yup, Alice is named Alice');
    
    done_testing;

Finished? If you get stuck, solutions are included with the downloadable code, and in the Appendix.

## Importing multiple rows at once

Creating users one at a time when they register is all very useful,
but sometimes we want to import a whole bunch of data at once. We can
do this using the `populate` method on **ResultSet**. 

Populate can be called with either an arrayref of hashrefs, one for
each row, using the column names as keys; or an arrayref of arrayrefs,
with the first arrayref containing the column names, and the rest
containing the values in the same order.

Here's an example that will add Fred and Alice at the same time.

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    $users_rs->populate([
      [qw/realname username password email/],
      ['Fred Bloggs', 'fred', Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'mypass'), 'fred@bloggs.com'],
      ['Alice Bloggs, 'alice', Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred'), 'alice@bloggs.com']
    ]);

Populate is most useful in _void context_, that is without requesting
a return value from the call. In this case it will use DBI's
`execute_array` method to insert multiple sets of row data. In list
context `populate` will call `create` repeatedly and return a list of
**Row** objects.

This code will do the same work as the above example, but return
DBIx::Class **Row** objects for later use:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @users = $users_rs->populate([
    {
      realname => 'Fred Bloggs',
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'mypass'),
      email    => 'fred@bloggs.com',
    },
    {
      realname => 'Alice Bloggs, 
      username => 'alice', 
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred'), 
      email    => 'alice@bloggs.com',
    }
    ]);

## Your turn, import some users from a CSV file and verify

The downloadable content for this chapter contains a file named
_multiple-users.csv_ containing several user's data in
comma-separated-values format. To read the lines from the file you can
parse it using a module like
[Text::xSV](https://metacpan.org/module/Text::xSV). The test file can also be found in the Appendix if you don't have the downloadable content.

Data file:

    "realname", "username", "password", "email"
    "Janet Bloggs", "janet", "fredsdaughter", "janet@bloggs.com"
    "Dan Bloggs", "dan", "sillypassword", "dan@bloggs.com"

Add your import code to this Perl test, then run to see how you did:

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use Text::xSV;
    
    use Test::More;
    use_ok('MyBlog::Schema');

    unlink 't/var/myblog.db';
    my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
    $schema->deploy();
    
    my $csv = Text::xSV->new();
    $csv->load_file('t/data/multiple-users.csv');
    $csv->read_header();
    
    while ($csv->get_row()) {
      my $row = $csv->extract_hash();

      ## Your code goes here!


    }

    ## Tests:
    
    is($schema->resultset('User')->count, 2, 'Two users exist in the database'));
    my $janet = $schema->resultset('User')->find({ username => 'janet' });
    ok($janet, 'Found Janet');
    is($janet->email, 'janet@bloggs.com', 'Janet has the correct email address');
    my $dan = $schema->resultset('User')->find({ username => 'dan' });
    ok($dan, 'Found Dan');
    ok($dan->password->match('sillypassword'), "Got Dan's password right");

Lookup the solution if you get stuck.

## Finding and changing a User's data later on

We've entered several users into our database, now it would be useful
to be able to find them again, and log them in or update their
data. If you've been paying close attention to the tests we've used to
check your progress, you'll notice the `find` ResultSet method.

`find` can be used to find a single database row, using either its
primary key or a known unique set of columns. These are both named in
the **Result Class** using `set_primary_key` and
`add_unique_constraint` respectively. By default `find` will try all
the given columns against the primary and unique keys to find the best
match, this will not work well if no key columns are present.

To login, the user will give you their username and password data, to
verify against a securely stored password, we need to first find the
User object, then test against the password.

Enough chatter, here's some code:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my $fred = $users_rs->find({ username => 'fred' }, { key => 'username_idx' });
    if( defined($fred) && $fred->password->match($password) ) {
        print "Yup that's definitely Fred\n";
    }
    
We explcitly name the `username_idx` unique constraint to help `find`
create the correct query. It will return either a DBIx::Class::Row
object, or undefined to indicate that no matching row was found. The
Row object has accessor methods matching the column names provided in
the **Result Class**, which will return the values stored in the
database. If an InflateColumn component has been used, then an object
representing the data will be returned instead.

Now that we've verified that fred is who he says he is, we can allow
him to update his email address or change his password, and store
those changes.

This example uses a small console based programm to illustrate, as
there wasn't room for an entire Web application.

    my $username = prompt('x', 'Your username', 'Enter your username', '');

    ## Find user row:
    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my $fred = $users_rs->find({ username => $username }, 
                               { key => 'username_idx' });

    ## Output the email address value:
    print "Your email address is set to: ", $fred->email, "\n";
    use Term::Prompt;
    my $new_email = prompt('x', 'New Email', 'Enter a valid email address', $fred->email);
    my $password = prompt('p', 'Your password', 'Enter your password', '');

    ## Verify user:    
    if( !defined($fred) || !$fred->password->match($password) ) {
        print "Sorry, you're not Fred, not changing the email address\n";
    }
    
    ## Update changed email address in database:
    $fred->email($new_email);
    $fred->update();

## <Can't think of a useful exercise here>

## Create a Post entry for the user

We've entered some single unrelated rows into the database, now we'll
look at how the relations work. In DBIx::Class *related* data means
data stored across multiple tables which is related in some way.

[%# yes we know this is at odds to how "real" relations in RDBMS' are described.. %]

In the `User` class we defined a `has_many` relationship to the `Post`
class, indicating that a user can create multiple posts. In the
database the `user_id` field stores the id of the Post-owning user
against each Post row.

Once we have a Row object representing a user, we can create related
Post entries without having to spell out the relationship:

    $fred->create_related('posts', {
        title => 'My first post!',
        post => 'A very short post',
    });

This will automatically pick up the `id` value from the `$fred`
object, and insert it into the `user_id` column in the Posts
table. The `$fred` object must be a User row that exists in the
database.
    
In true perlish spirit, this can also be written as:

    $fred->posts->create({
        title => 'My first post!',
        post => 'A very short post',
    });

The `posts` method is created by our `has_many` relation, it will
return a **DBIx::Class::ResultSet** object with a condition for all
the one or more related Post entries.

## Your turn, insert a set of posts from an offline edit

Alice likes to write her blog posts when she's out and about without
network, and then later import them. She's devised a local storage
based on XML (as the CSV format doesn't get along well with the
newlines inside her text). Write some code to import the posts from the
example XML.

This test script includes the code to parse the XML file into a Perl
data structure.

  ## TODO

## Update many rows at once, getting rid of rude names

We've seen how to interact with a single database row at a time, how
to fetch and update it. We can also update a whole set of rows with a
change that applies to all rows at once.

We failed initially to exclude any words from our signup validation,
so users have been created with rude words as real names, which will be
displayed to other users.

First we search for the users that match our disallowed list, we can
use the `like` operator to match parts of strings, an arrayref creates
a list of alternate conditions:

(Pick your own set of unwanted words ;)

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @badwords = ('john', 'joe', 'joseph');
    my $badusers_rs = $users_rs->search({
      realname => [ map { { 'like' => "%$_%"} } @badwords ],
    });
    
The result is a ResultSet which contains the condition we want, now we
can update all the rows at once by applying `update` to the ResultSet.

   $badusers_rs->update({ realname => 'XXXX' });

## Deleting a row or rows, and cascading

If you've been reading this entire chapter you might have guessed by
now which method we can use to delete a row, or even multiple rows,
from the database, its `delete`.

To remove a single user from the system, find the row object and call
the `delete` method on it:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my $fred2 = $users_rs->find({ username => 'fred2' });
    $fred2->delete;

Poof, gone. The `$fred` object is still there, with its contents, but
the data it represented in the database is gone. To discover whether
an object you have represents actual data, use the `in_storage`
method, the result will be `0` (false) when the row data is not yet or
no longer in the database, and `1` (true) if it is.

Your database will automatically remove any rows related to this one
using foreign keys, if set up correctly. This means all posts created
by the user *fred2* will be deleted. If the database does not remove
them, DBIx::Class will make an attempt itself, as the `has_many`
relation is set up to cascade deletes by default. To change this
behaviour, set up the relationship with `cascade_delete` set to 0:

    32. __PACKAGE__->has_many('posts', 'MyBlog::Schema::Result::Post', 'user_id', { cascade_delete => 0 });


To remove a multiple rows at once, create a resultset object that matches the
rows to remove, and call the `delete` method on it:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @badwords = ('john', 'joe', 'joseph');
    my $users_to_delete = $users_rs->search({
      realname => [ map { { 'like' => "%$_%"} } @badwords ],
    });
    $users_to_delete->delete;

Don't forget to backup your data before you try these, just in
case. If you are trying to hide or deactivate data, consider having a
field in your table for `archived` or similar, and setting it to a
true value to indicate the data is no longer in use.

## Advanced create/update/delete
## find_or_create, update_or_create, multi create

Now we go a bit wild, there are a bunch of useful methods and
techniques which simplify your code by combining various other methods
we've already looked at in this chapter. I'll give a description and
usage hint for each one, then we'll do some more tests.

* Multi-create

`create` can do more than just straight-forward creation of single
rows, it can also be given a data structure with more levels of
related data to create rows for, as long as the top level represents
the table you started on.

For example, you can do this:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    
    $users_rs->create({
      realname => 'John Smith',
      username => 'johnsmith',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'johnspass',
      ),
      email => 'john.smith@example.com',
      
      posts => [
      {
        title => "John's first post",
        post  => 'Tap, tap, is this thing on?',
      },
      {
        title => "John's second post",
        post => "Anybody out there?",
      }
      ],
    });
      
But not this:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    
    ## Attempt to create a post on the User ResultSet!?
    $users_rs->create({
      title => "John's first post",
      post => 'Tap, tap, is this thing on?',
      user => {
        realname => "John Smith",
        ...
      }

You can also do this:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->find({ username => 'fred' });
    my $posts_rs = $schema->resultset('Post');
    
    $postss_rs->create({
      title => "John's first post",
      post => 'Tap, tap, is this thing on?',
      user => $fred,
    });


Related objects are added using the relation name, and using a hashref
(for foreign key relationships) or an arrayref hashrefs (the other
side, has_many, has_one, might_have) to add the data. Or you can link
to another row using the row object (which will be inserted into the
database, if it has not yet been).
    
* find_or_create and find_or_new

We can already `find` single rows based on their unique values, and
`create` new rows. If we try to create a new row using data that
already matches unique values in the database, we will get an error,
let's test:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->create({ 
      realname => 'Fred Bloggs',
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
    });
   
    my $fred2 = $users_rs->create({ 
      realname => 'Fred Bloggs',
      username => 'fred',  ## oops, username already exists.
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
    });

Oops! For usernames, this is probably what we want to happen, instead
of overwriting the existing user, it just fails. It would be more
useful if it instead returned the existing user row, so that we can
use it. For example to send the user a password reset email.

`find_or_create` will start by running a `find` based on the primary
or unique values passed in the data, if it finds a match it will
return the matching row. If no matching row is found, it will create a
new row. If we repeat our exercise using find_or_create:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred = $users_rs->create({ 
      realname => 'Fred Bloggs',
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
    });
   
    my $fred2 = $users_rs->find_or_create({ 
      realname => 'Fred Bloggs',
      username => 'fred',  ## oops, username already exists.
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
    });

    print $fred->id;
    print $fred2->id;

Notice that `$fred` and `$fred2` have the same primary key (id), they
are representing the same row. This technique only works when you are
passing in values for the unique or primary keys.

NOTE: Using find_or_create can produce race conditions, as it does two
separate SQL commands.

To discover whether your returned Row object is a new one or an
existing one, use `find_or_new` instead. This will return a Row object
that is in the database, or a new, uninserted object. Check
`in_storage` to see if the object is uninserted, then call `insert` to
put the data in the database.

* update_or_create



[^new_result]: new_result creates a Row object that stores the data given, but does not enter it into the database. The `in_storage` method can be used to check the status of a Row object (true == is in the database).
