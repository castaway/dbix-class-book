Chapter 4 - Creating, Reading, Updating and Deleting
====================================================

Chapter summary
---------------

In this chapter we will show how to do basic database operations using your DBIx::Class classes. We are using the MyBlog schema described in [](chapter_03-describing-your-database)

Pre-requisites
--------------

We will be giving code examples and comparing them to the SQL statements that they produce. You should have basic SQL knowledge to understand this chapter. The database we are using is provided as an SQL file to import into an SQLite database[^sqlite] to get started. You should also have basic knowledge of object-oriented code and Perl classes.

Download the skeleton code for this chapter:[](http://dbix-class.org/book/code/chapter04.zip).

Introduction
------------

The DBIx::Class classes (also called your DBIC schema) contain all the data needed to produce and execute SQL commands on the database. To run commands we just manipulate the objects representing the data.

## Create a Schema object using a database connection

All the database manipulation with DBIx::Class is done via one central Schema object, which maintains the connection to the database via a storage object[^storage]. To create a schema object, call `connect` on your DBIx::Class::Schema subclass, passing it a Data Source Name[^dsn].

    use MyBlog::Schema;

    my $schema = MyBlog::Schema->connect("dbi:SQLite:myblog.db");
    
To pass a username and password for the database, just add the strings as extra arguments to `connect`, for example when using MySQL:

    use MyBlog::Schema;

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", 
                                         "myuser", 
                                         "mypassword"
                                        );

You can also pass various DBI[^dbi] connection parameters by passing a fourth argument containing a hashref. This is also used by DBIx::Class to set options such as the instruction to quote all table and column names in the SQL, eg:

    use MyBlog::Schema;

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", 
                                         "myuser", 
                                         "mypassword", 
                                         { quote_names => 1 }
                                        );

For more detailed information about all the available connection arguments, see the connect_info documentation[^connectinfo].

As seen in the previous chapter, [](chapter_03-create-a-database-using-dbix-class), the `$schema` can be used to create the actual database tables and other structure ready for use. To continue, you will need a working database, so make sure you have one before moving on. For a quick start, run the `deploy` command:

    $schema->deploy();

## Accessing data, the empty query aka ResultSet

To manipulate any data in your database, you first need to create a **ResultSet** object. A ResultSet is an object representing a potential query. It stores the conditions and joins needed to produce the SQL statement. Each ResultSet is based on a single ResultSource (table) and can add joins to other tables for filtering or extra data.

To get a ResultSet object, we call the Schema `resultset` method, passing the name of a **Result class**. For example, `User.pm` describes the `users` table. To fetch its ResultSet, using the `resultset` method:

    my $users_rs = $schema->resultset('User');

Note: If you are using an automatically created set of Result classes (as described at the end of [](chapter_03-alternative-class-creation)), do take a good look at the created classes. Generally auto-created classes will be named in the singular, that is table `users` will produce a class named `User`. Linking tables, will be turned into CamelCase[^camelcase], so a table named `user_roles` will be converted to a class named `UserRoles`.

Now we can move on to some actual database operations ... 

## Creating user rows

Now that we have a ResultSet, we can start storing some data in our database. To create a user, we can collect all the relevant data, and then initiate and insert the new **Row** all at once, by calling the `create` method:

    use Authen::Passphrase::SaltedDigest;

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

Note here that the `password` value is an object which encrypts the
actual password "mypass" using `SHA-1`. The `InflateColumn` component
we added to the User class in
[](chapter_03-getting-started-the-user-class), allows us to pass in an
object as a value, instead of a plain scalar (string or number). The
component will reduce the result to a string in the database, and
re-create the object when we re-fetch the row data later on.

`create` is the equivalent of calling the `new_result`[^new_result]
method, which returns a **Row** object, and then calling the `insert`
method on the row. `new_result` makes a fresh Row object, storing the
values we passed in, but does not insert it into the database. The Row
object can then be used or passed around to change its data or add
more, any constraints are not checked until we try and insert it into
the database.

We can create the same user a different way, using `new_result`
instead and setting the values separately:

    use Authen::Passphrase::SaltedDigest;

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

Note how all the columns described in the `User` class using `add_columns` appear on the **Row object** as accessor methods.

To see what's going on, we can set the shell environment variable DBIC_TRACE[^DBIC_TRACE] to a true value, and DBIx::Class will display the SQL statement for either of these code samples on STDOUT:

    INSERT INTO users (realname, username, password, email) VALUES (?, ?, ?, ?): 'Fred Bloggs', 'fred', '{SSHA}GGccJQItu3l8a4SUkYy1lRqffGnCPtZanwM+gQrqwGh5GEOoz0m1Sg==', 'fred@bloggs.com'

NB: The `?` symbols are placeholders, the actual values will be quoted according to your database rules, and passed in.

As the `id` column is defined as being `is_auto_increment` we haven't
supplied that value at all. The database will fill it in, and the
`insert` call will fetch the value and store it in our `$fred` Row
object. It will also do this for other database-supplied fields if
defined as `retrieve_on_insert` in `add_columns`.

### Your turn, create a User and verify with a test

Now that's all hopefully made sense, it's time for a bit more
Test-Driven-Development.

This is a short Perl test that will check that a user, and only one
user, with the `email` of **alice@bloggs.com** exists in the
database. You can type it up into a file named
**check-alice-exists.t** in t/ directory, or unpack it from the
provided tarball. 

Add code in the provided space (after "Your code goes here!" to create
the alice user in the database. Examine the tests that follow to see
what the rest of the user should look like.

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
    is($alice->id, 1, "Magically discovered Alice's PK value");
    is($alice->username, 'alice', 'Alice has boring ole username of "alice"');
    ok($alice->password->match('aliceandfred'), "Guessed Alice's password, woot!");
    like($alice->realname, qr/^Alice/, 'Yup, Alice is named Alice');
    
    done_testing;

Finished? If you get stuck, solutions are included with the downloadable code, in the exercises section.

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
      ['Fred Bloggs', 'fred', Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'mypass')->as_rfc2307, 'fred@bloggs.com'],
      ['Alice Bloggs', 'alice', Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred')->as_rfc2307, 'alice@bloggs.com']
    ]);

Note how we need to call `as_rfc2307` on the Authen::Passphrase object
in order to fetch the string representation to store in the password
field. This is because when the `populate` method is called in **void
context**[^voidcontext] it sends the data straight to the database, and 
bypasses any components or overridden methods in your Result class. In void context the creation of rows is also faster[^executearray]

`populate` can also be called in list context, it will then just call
the `create` method repeatedly list of **Row** objects.

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
      realname => 'Alice Bloggs', 
      username => 'alice', 
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred'), 
      email    => 'alice@bloggs.com',
    }
    ]);

## Your turn, import some users from a CSV file and verify

The downloadable content for this chapter contains a file named
_t/data/multiple-users.csv_ containing several user's data in
comma-separated-values format. To read the lines from the file you can
parse it using a module like
[Text::xSV](http://metacpan.org/module/Text::xSV). 

Data file:

    "realname", "username", "password", "email"
    "Janet Bloggs", "janet", "fredsdaughter", "janet@bloggs.com"
    "Dan Bloggs", "dan", "sillypassword", "dan@bloggs.com"

Add your import code to this Perl test, then run to see how you did
(you can find the downloadable copy in _t/import-users.t_):

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
    
    my $users_rs = $schema->resultset('User');
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

Look up the solution in the exercises directory if you get stuck.

## Finding and changing a User's data later on

We've entered several users into our database. Now it would be useful
to be able to find them again, and log them in or update their
data. If you've been paying close attention to the tests we've used to
check your progress, you'll notice the `find` ResultSet method.

`find` can be used to find a single database row, using either its
primary key or a known unique set of columns. These are both named in
the **Result Class** using `set_primary_key` and
`add_unique_constraint` respectively. By default `find` will try all
the given columns against the primary and unique keys to find the best
match. This will not work well if no key columns are present.

To login, the user will give you their username and password data, to
verify against a securely stored password. We need to first find the
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
object, or `undef` to indicate that no matching row was found. The Row
object we get back has accessor methods matching the column names
provided in the **Result Class**, which will return the values that
were fetched from the database. If an InflateColumn component has been
used, then an object representing the data will be returned instead.

Now that we've verified that fred is who he says he is, we can allow
him to update his email address or change his password, and store
those changes.

This example uses a small console based program to
illustrate. (Performing this behaviour on DBIx::Class objects
demonstrates how you can share a database layer between a command-line
program and a web application, for example.)

To run this example, you will need to install
Term::Prompt[^termprompt] from CPAN.

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

## Create a Post entry for the user

We've entered some single unrelated rows into the database, now we'll
look at how to use the relations. In DBIx::Class *related* data means
data stored across multiple tables which is related in some way. For
example the Post table contains blog post entries which are related to
their authors.

Note that the in more formal definitions of Relational Databases,
"relation" means a set of related data in one table. We apologise for
any confusion.

In the `User` class we defined a `has_many` relationship to the `Post`
class, indicating that a user can create multiple posts. In the
database the `user_id` field stores the `id` value of the Post-owning
user for each Post row.

Now that we have a Row object representing a user, we can create a
Post entry without having to spell out the relationship:

    $fred->create_related('posts', {
        title => 'My first post!',
        post => 'A very short post',
        created_date => DateTime->now(),
    });

This will automatically pick up the `id` value from the `$fred`
object and insert it into the `user_id` column in the Posts
table. The `$fred` object must be a User row that exists in the
database.

Note how the `created_date` value can be supplied using a DateTime
object, the appropriately formatted datetime value for your backend
database system will be inserted into the row.
    
In true perlish TIMTOWTDI spirit, this can also be written as:

    $fred->posts->create({
        title => 'My first post!',
        post => 'A very short post',
        created_date => DateTime->now(),
    });

The `posts` method is created by our `has_many` relation. It will
return a **DBIx::Class::ResultSet** object with a condition for all
the one or more related Post entries. 

To create an un-inserted Post entry that we can pass around / edit
before putting into the database, we can of course also use
`new_result` here instead of `create`.

## Your turn, insert a set of posts from an offline edit

Alice likes to write her blog posts when she's out and about without
network, and then later import them. She's devised a local storage
based on XML (as the CSV format doesn't get along well with the
newlines inside her text). Write some code to import the posts from the
example XML.

The XML data for this exercise can be found in the file
_t/data/multiple-posts.xml_. You can find the skeleton code in the
file _t/import-posts.t_.

This test script includes the code to parse the XML file into a Perl
data structure, so you just need to add the code to insert the posts
into the database.

To run the test you will need to install the XML::Simple[^xmlsimple] module.

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use XML::Simple;
    use Authen::Passphrase::SaltedDigest;
    use DateTime::Format::Strptime;
 
    use Test::More;
    use_ok('MyBlog::Schema');

    unlink 't/var/myblog.db';
    my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
    $schema->deploy();

    my $alice = $schema->resultset('User')->create(
    {
      realname => 'Alice Bloggs', 
      username => 'alice', 
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'aliceandfred'), 
      email    => 'alice@bloggs.com',
    });
    
    my $dt_formatter = DateTime::Format::Strptime->new( pattern => '%F %T' );
    my $xml_posts = XMLIn('t/data/multiple-posts.xml');
    
    foreach my $post_xml (@$xml_posts) {
      my $postdate = $dt_formatter->parse_datetime($post_xml->{created_date});

      ## Your code goes here!

      ## End your code
    }

    ## Tests:
    
    is($schema->resultset('Post')->count, 2, 'Two posts exist in the database');
    my @posts = $alice->posts->all();
    foreach my $post (@posts) {
      ok($post->title eq 'In which Alice writes a blog post' ||
         $post->title eq "Alice's second blog post",
         'Got correct post title');
      ok($post->post =~ /^This being a new blog/ ||
         $post->post =~ /^Alice ponders over life/,
         'Got correct post content');
    }


## Update many rows at once, getting rid of rude names

We've seen how to interact with a single database row at a time, how
to fetch and update it. It is also possible to update a whole set of
rows with a change that applies to all rows at once.

Let's assume we initially forgot to exclude any words from our user
signup validation, so users have been created with rude words as real
names, which will be displayed to other users.

First we need to search for the users that match our disallowed
list, for this we can use the `-like` operator to match parts of
strings. Using an arrayref of values produces a set of OR'd conditions
in the SQL:

(Pick your own set of unwanted words ;)

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    ## I just don't like names beginning with J
    my @badwords = ('john', 'joe', 'joseph', 'jess', 'james');
    my $badusers_rs = $users_rs->search({
      realname => [ map { { '-like' => "%$_%"} } @badwords ],
    });
    
The result is a ResultSet which contains the condition we want. Now we
can update all the rows at once by applying `update` to the ResultSet.

    $badusers_rs->update({ realname => 'XXXX' });

Here's the SQL this outputs, to show you what is going on:

    UPDATE users SET realname = 'XXXX' WHERE
    realname LIKE '%john%' OR realname LIKE '%joe%' OR
    realname LIKE '%joseph%' OR realname like '%jess%' OR
    realname LIKE '%james%';
    
Note that the "%" character is a wildcard in the LIKE operator, and
matches any number of unspecified characters.

See [](chapter_05-introducing-search-conditions-and-attributes) for more
details on search conditions.

## Deleting a row or rows, and cascading

If you've been reading this entire chapter you might have guessed by
now which method we can use to delete a row, or even multiple rows,
from the database, it's `delete`.

To remove a single user from the system, find the row object and call
the `delete` method on it:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my $fred2 = $users_rs->find({ username => 'fred2' });
    $fred2->delete;

Poof, gone. The `$fred2` object is still there, with its contents, but
the data it represented in the database is gone. To discover whether
an object you have represents actual data, use the `in_storage`
method, the result will be `0` (false) when the row data is not yet or
no longer in the database, and `1` (true) if it is.

Your database should automatically remove any rows related to this one
using foreign keys, if set up using foreign key constraints. This
means all posts created by the user *fred2* will be
deleted. DBIx::Class will by default, also make an attempt to remove
related rows, **after** the original row is removed. This will throw
errors if your database has constraints/foreign keys set up to ensure
data integrity, but the data has not been removed for some reason.

Related rows are removed according to the `has_many` relationships set
up in the Result class. The attempt to delete related rows can be
turned off by setting the `cascade_delete` attribute on the
relationship to a false value:

    32. __PACKAGE__->has_many('posts', 
                              'MyBlog::Schema::Result::Post', 
                              'user_id', 
                              { cascade_delete => 0 },
                             );


To remove multiple rows at once, create a resultset object that matches the
rows to remove, using `search`, then call the `delete` method on it:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my @badwords = ('john', 'joe', 'joseph', 'jess', 'james');
    my $users_to_delete = $users_rs->search({
      realname => [ map { { 'like' => "%$_%"} } @badwords ],
    });
    $users_to_delete->delete;

Don't forget to backup your data before you try these, just in
case. If you are trying to hide or deactivate data, consider having a
field in your table for `archived` or similar, and use the `update`
method instead of `delete` to just change the `archived` field value
to indicate the data is no longer in use.

## Advanced create/update/delete

Now we go a bit wild. There are a bunch of useful methods and
techniques which simplify your code by combining methods
we've already looked at in this chapter. I'll give a description and
usage hint for each one, then we'll do some more tests/exercises.

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
            created_date => DateTime->now,
          },
          {
            title => "John's second post",
            post => "Anybody out there?",
            created_date => DateTime->now,
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
    
    $posts_rs->create({
      title => "John's first post",
      post => 'Tap, tap, is this thing on?',
      user => $fred,
    });


Related objects are added using the relation name, and using a hashref
(for foreign key relationships) or an arrayref of hashrefs (the other
side, `has_many`, `has_one`, and `might_have`) to add the data. Or you
can link to another row using the row object (which will be inserted
into the database, if it has not yet been).
    
* find_or_create and find_or_new

We can already `find` single rows based on their unique values, and
`create` new rows. If we try to create a new row using data that
already matches unique values in the database, we will get an error
thrown by the database:

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
use it--for example, to send the user a password reset email.

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

Notice that `$fred` and `$fred2` have the same primary key (id); they
represent the same row. This technique only works when you are
passing in values for the unique or primary keys.

`find_or_create` can produce race conditions, as it does a separate
`SELECT` statement followed by an `INSERT` statement, if it needs to
create the user. To work around this, start a transaction by using the
`txn_do` method on the Schema object:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    $schema->txn_do(sub {
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
    });

For more on transactions, see
[](chapter_05-preventing-race-conditions-with-transactions-and-locking).

To discover whether your returned Row object is a new one or an
existing one, use `find_or_new` instead. This will return a Row object
that is in the database, or a new, uninserted object. Check
`in_storage` to see if the object is uninserted, then call `insert` to
put the data in the database.

* update_or_create

The complementary method to `find_or_create` is `update_or_create`,
which allows us to update an existing row, or create a new one if
there is no such row. As with `find_or_create` this is all based on
having a primary key, or a unique set of columns.

So we can replace this sort of code:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');
    my $fred_exists = $users_rs->find({ username => 'fred' });

    if($fred_exists) {
      $fred_exists->update({ 
        realname => 'Fred Barney',
        email => 'fred@barney.com',
      });
    } else {
      $fred_exists->update({ 
        realname => 'Fred Barney',
        email => 'fred@barney.com',
        username => 'fred',
        password => Authen::Passphrase::SaltedDigest->new(
           algorithm => "SHA-1", 
           salt_random => 20,
           passphrase => 'mypass',
        ),
      });
    }
    
With this much shorter version:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    $users_rs->update_or_create({ 
        realname => 'Fred Barney',
        email => 'fred@barney.com',
        username => 'fred',
        password => Authen::Passphrase::SaltedDigest->new(
           algorithm => "SHA-1", 
           salt_random => 20,
           passphrase => 'mypass',
        ),
      });
    }

Even though we provide all the data to `update_or_create`, the `update`
portion will only sent an update statement to the database for the
columns that have changed.

As with `find_or_create`, this method will issue multiple statements,
so it is subject to possible race conditions. Run it inside a
transaction to prevent collisions:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");
    my $users_rs = $schema->resultset('User');

    my $schema->txn_do( sub {
      $users_rs->update_or_create({ 
        realname => 'Fred Barney',
        email => 'fred@barney.com',
        username => 'fred',
        password => Authen::Passphrase::SaltedDigest->new(
           algorithm => "SHA-1", 
           salt_random => 20,
           passphrase => 'mypass',
        ),
      });
   });
      
See [](chapter_05-preventing-race-conditions-with-transactions-and-locking) for more on transactions.

## Your turn, trying out the advanced CRUD methods

Time to have a go yourself. We'll do a slightly more complicated test,
to ensure that your code actually uses the new methods, I'm going to
provide a new ResultSet class that records which methods you call.

To pass this test you'll need to create a user with username
**joebloggs**, and some initial `Post` entries for the user. Then
we'll add user **alicebloggs** checking that she doesn't exist
already, and finally we'll update **fredbloggs** and change his
password to **freddy**.

This test can be found in the file **advanced-methods.t**.

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use Test::More;
    use Authen::Passphrase::SaltedDigest;
    use_ok('MyBlog::Schema');
    
    package Test::ResultSet;
    use strict;
    use warnings;
    
    use base 'DBIx::Class::ResultSet';
    __PACKAGE__->mk_group_accessors('simple' => qw/method_calls/);

    sub new {
      my ($self, @args) = @_;
      $self->method_calls({});
      $self->next::method(@args);
    }

    sub create {
      my ($self, @args) = @_;
      $self->method_calls->{create}++;
      $self->next::method(@args);
    }

    sub find_or_create {
      my ($self, @args) = @_;
      $self->method_calls->{find_or_create}++;
      $self->next::method(@args);
    }

    sub update_or_create {
      my ($self, @args) = @_;
      $self->method_calls->{update_or_create}++;
      $self->next::method(@args);
    }

    package main;
    
    unlink 't/var/myblog.db';
    my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
    $schema->deploy();
    foreach my $source ($schema->sources) {
      $schema->source($source)->resultset_class('Test::ResultSet');
    }
    my $users_rs = $schema->resultset('User');
    
    
    ### Multi-create test, add joebloggs and his posts here:
    ## Your code goes here!

    ## Your code end
    is($users_rs->method_calls->{create}, 1, 'Called "create" just once');
    ok($users_rs->find({ username => 'joebloggs' }), 'joebloggs was created');
    ok($schema->resultset('Post')->search(
      { 'user.username' => 'joebloggs'},
      { join => 'user' }
    )->count >= 2, 'Got at least 2 posts by joebloggs');

    ## find_or_create test, add alicebloggs here with existance check
    ## Your code goes here:
    

    ## Your code end
    is($users_rs->method_calls->{find_or_create}, 1, 'Called "find_or_create" just once');
    ok($users_rs->find({ username => 'alicebloggs' }), 'alicebloggs was created');

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
    ## update_or_create test, update fred's password here:
    ## Your code goes here:
    
    ## Your code end
    is($users_rs->method_calls->{update_or_create}, 1, 'Called "update_or_create" just once');
    my $fred = $users_rs->find({ username => 'fredbloggs' });
    ok($fred, 'got fredbloggs');
    if($fred) {
      ok($fred->password->match('freddy'), 'Updated password');
    }
    
    done_testing;

If you get stuck there's a working copy in the _exercises/_ directory
in the download for this chapter.

[^sqlite]: [](http://metacpan.org/module/DBD::SQLite)
[^storage]: Storage backend, only available one is DBI, []((http://metacpan.org/module/DBIx::Class::Storage)
[^dbi]: [](http://metacpan.org/dist/DBI)
[^connectinfo]: [](http://metacpan.org/module/DBIx::Class::Storage::DBI#connect_info)
[^new_result]: new_result creates a Row object that stores the data given, but does not enter it into the database. The `in_storage` method can be used to check the status of a Row object (true == is in the database).
[^DBIC_TRACE]: An environment variable to turn on debugging info which dumps the SQL queries made. Use `set DBIC_TRACE=1` on Windows or csh, and `export DBIC_TRACE=` on bash-like shells.
[^dsn]: See the DBI documentation for more on how these work, essentially they consist of `dbi:` followed by the name of the DBD (database driver) you are using, eg `SQLite:`, followed by a custom description of the actual database, depending on driver used.
[^voidcontext]: Calling a function or method without requesting the return value.
[^executearray]: The populate method uses the DBI `execute_array` method in void context.
[^xmlsimple]: [](http://metacpan.org/module/XML::Simple)
[^termprompt]: [](http://metacpan.org/module/Term::Prompt)
