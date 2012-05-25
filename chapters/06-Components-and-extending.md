Chapter 6 - Components and extending
====================================

Chapter summary
---------------

In this chapter we take a look at adding functionality to the Row and
ResultSet objects, beyond the basic database access and storage that
DBIx::Class provides. The distribution contains a few of modules to
use for this and many more can be found on CPAN. 

Pre-requisites
--------------

You will need to have
understood the basic setup in [](chapter_03-describing-your-database) and
understand how to use
[mro method dispatching](http://metacpan.org/module/mro#next::method).

NOTE: On versions of perl before 5.10.x you will need to read
[the Class::C3 docs](http://metacpan.org/module/Class::C3#METHOD-REDISPATCHING)
instead.

We will be giving code examples and tests using Test::More so you
should be familiar with Perl unit testing. The database we are using
is provided as an SQL file you can import into an
[SQLite database](http://metacpan.org/dist/DBD-SQLite) to get
started.

[Download code](http://dbix-class.org/book/code/chapter06.zip)

Introduction
------------

We've already mentioned a couple of useful components in
[](chapter_03-describing-your-database) for expanding simple database
content into objects, now we'll explain how this works and how to add your
own inflations. We'll also cover storing data that isn't in the
database, adding re-usable query methods and validation.

## Turning column data into useful objects

The data we store in databases is generally simple, or scalar data,
strings, numbers, timestamps, IPs. The DBIx::Class featues we've seen
so far will extract this data into an object representing a single
Row. The actual content returned by the accessor methods is however
still the same simple data. To turn it into more useful objects we can
add *InflateColumn* components to our Result classes to convert the
data to and from objects.

In
[](chapter_03-getting-started-the-user-class)
we use the existing InflateColumn component for Authen::Passphrase, to
automatically hash passwords as we store them in the database. It also
adds a method to verify a password entered by the user. If you can't
find an existing InflateColumn class that suits your data, you can
create your own inflation using the `inflate_column` Result class
method.

For one-off requirements, `inflate_column` can be used directly in the
Result class that needs it, no need to create a separate module. This
example shows how to use it to turn a string containing an email
address into an object based on the
[Email::Address](http://metacpan.org/module/Email::Address) class,
which will allow checking if the entered email is valid, and extract
components such as the username and the host. To try out this example,
install the Email::Address module from CPAN first.

Edit the existing `MyBlog/Schema/Result/User.pm` and add to the bottom
under the relationship definitions:

    use Email::Address;
    
    __PACKAGE__->inflate_column('email', {
      inflate => sub { my $emailstring = shift; return Email::Address->parse($emailstring); },
      deflate => sub { my $emailobj = shift; return $emailobj->address(); },
    });
    
We assign two code references to the `email` column. The `inflate`
code is run whenever we need to turn the email string into an object,
for example when using the `$user->email` accessor method to fetch the
email column. The `deflate` code is run on `create` and `update` to
convert a provided Email::Address object into a suitable string to
store in the database.

This example shows `deflate` in action, supplying an Email::Address
object as the `email` column value:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs= $schema->resultset('User');
    my $fred = $users_rs->create({ 
      realname => 'Fred Bloggs',
      username => 'fredbloggs',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => Email::Address->parse('fred@bloggs.com'),
    });
    
The deflator can be bypassed if you don't want or need to create an
extra object when supplying the email value, just provide a string
instead of the object. Deflation is only applied to array references,
hash references or objects, plain scalars and scalar references are
ignored and passed through directly to the rest of the DBIx::Class
code.

NOTE: Scalar references are ignored by deflate as they are used to
send literal (unquoted) pieces of SQL to the database, for example
`mydatetimefield => \'now()'` will send `now()` instead of `'now()'`
as the value for the field `mydatetimefield`.

The `inflate` in action example shows how to `find` the user row as
normal, and use the `email` accessor to get an Email::Address object:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $freduser = = $schema->resultset('User')->find({
      username => 'fredbloggs'
    }, {
      key => 'username_idx',
    });
    
    ## The email accessor now returns an Email::Address object:
    print $freduser->email->host, "\n";
    
    ## We can still get the original data:
    print $freduser->get_column('email');
      
The inflator can also be bypassed, to get the database contents
directly, use the `get_column` method on the Row object.

    $user->get_column('email');

To re-use your Inflation/Deflation code, it can be made into a
component module and added to each Result class as needed, using the
`load_components` class method already seen in Chapter 3. Generic
re-usable components can be put into the `DBIx::Class::InflateColumn`
namespace and shared on CPAN for everyone else to use. Components
which are more for local use only can use your application namespace,
these can be loaded by prepending a `+` to the class name. So we can
make this a MyBlog component:

    package MyBlog::InflateColumn::Email;
    
    use strict;
    use warnings;
    
    use Email::Address;
    
    ## Extend register_column to add the inflate/deflate methods for
    ## each column with a true value for the 'is_email' key
    sub register_column {
      my ($self, $column, $info, @rest) = @_;
      $self->next::method($column, $info, @rest);
 
      return unless $info->{'is_email'};
      
      $self->inflate_column(
        $column => {
            inflate => sub {
                my $emailstring = shift; 
                return Email::Address->parse($emailstring);
            },
            deflate => sub {
                my $emailobj = shift; 
                return $emailobj->address();
            },
        }
      );
    }
    
Note how components can hook into `register_column` when adding
inflate/deflate, and then somehow decide which columns to add the code
to. This is usually done by having the user of the component fill in a
true value for a new column info key, such as the `is_email` in this
case. You may want to localise the key name to avoid conflicts with
other components, eg to `is_myblog_email`. 

`register_column` is called once for each column created in
`add_columns` and is passed the name of the column and the column info
hashref as parameters. We let the normal `register_column` activities
happen by calling the mro method dispatching call `next::method`, then
run the extra code to assign the inflate/deflate code to the chosen
column.

Now we can add the component to `MyBlog/Schema/Result/User.pm` instead
of calling `inflate_column`:

    __PACKAGE__->load_components('+MyBlog::InflateColumn::Email', 'InflateColumn::Authen::Passphrase'); 

    __PACKAGE__->add_columns(
       # ...
       email => {
         data_type => 'varchar',
         is_email => 1,
         size => 255,
       },
    );
    
    __PACKAGE__->inflate_column('email', {
      inflate => sub { my $emailstring = shift; return Email::Address->parse($emailstring); },
      deflate => sub { my $emailobj = shift; return $emailobj->address(); },
    });

With the exact same results when using the resulting User objects.

NOTE: The order of the components in the `load_components` call will
determine which order they are run, the first-listed components are
run first.

## Filtering any column data in and out

Inflation and deflation are one way to change or adapt the data on the
way into or out of the database. Another component that can be used to
change the content is the provided `FilterColumn` component. This is
used to arbitrarily change any data, not just references and objects.

Filtering is not built into the `Core` component, so first we need to
load the `FilterColumn` component itself, then we can use the
`filter_column` class method to provide `filter_to_storage` and
`filter_from_storage` code references for the data conversion. In this
example we filter the `username` data to remove any extra whitespace
at either end:

    ## in MyBlog/Schema/Result/User.pm

    __PACKAGE__->load_components('FilterColumn', 
      '+MyBlog::InflateColumn::Email', 
      'InflateColumn::Authen::Passphrase'
    ); 

    __PACKAGE__->filter_column( username => {
      filter_to_storage => sub { 
        my ($row, $value) = @_; 
        $value =~ s/^\s+//; 
        $value =~ s/\s+$/;
      },
      filter_from_storage => sub {},
    });

The `filter_column` code refs, unlike the `inflate_column` code, are
also passed the Row object, giving the code access to other values in
the same row.

This is one way to remove any accidental whitespace at the beginning
and end of a string value such as the `username` column, before saving
it to the database.

## Overriding the column accessors

Instead of using `filter_column` this could also be done by replacing
the accessor method. By default the accessor methods are named after
the column names defined in `add_columns`, we can use the `accessor`
key to ask for a different method name. With the accessor renamed, we
can write the actual method named after the column ourselves, and call
internally on the new actual accessor. This code can do anything you
like, and is passed the Row object and any value being assigned.

Replace the `username` accessor in `MyBlog/Schema/Result/User.pm` with
some code to trim the data passed in:

    __PACKAGE__->load_components(
      '+MyBlog::InflateColumn::Email', 
      'InflateColumn::Authen::Passphrase'
    ); 

    __PACKAGE__->add_columns(
      # ...
      username => {
        data_type => 'varchar',
        size      => 255,
        accessor  => '_username',
      },
      # ...
    );
    
    
    sub username {
      my ($row, $value) = @_;
      
      if(defined($value)) {
        $value =~ s/^\s+//; 
        $value =~ s/\s+$/;
        $row->_username($value);
      }
      
      return $row->_username;
    }

Unlike FilterColumn and InflateColumn, this code will only have an
affect when the accessor method itself is called. It will not be run
when the `create` or `new` methods are called. To achieve the
equivalent functionality we'll also have to overload the `new`, and
`update` methods, we'll show this later in the section
[](chapter_06-writing-your-own-components).

## Your turn, encode the user's real names

Now we've seen several ways to extend the Result class and change the
database values going in and out of the storage layer. For this
exercise you're going to obfuscate the user's stored `realname` in the
database, preferably in such a way that it can be converted back to
the actual value when retrieved.

You can implement this one however you like, the test will merely
verify that the plain stored value in the database is not the same
string as the one we put in, but when fetched via the accessor,
matches.

You may need to change code in the Result/User.pm file or the test
file, make a separate copy of the skeleton code to work on then go ahead:

You can find this test in the file **encode_real_name.t**.

    #!/usr/bin/env perl
    use strict;
    use warnings;
    
    use Authen::Passphrase::SaltedDigest;
    use Test::More;
    use_ok('MyBlog::Schema');

    unlink 't/var/myblog.db';
    my $schema = MyBlog::Schema->connect('dbi:SQLite:t/var/myblog.db');
    $schema->deploy();

    my $users_rs = $schema->resultset('User');
    ## Add some initial data:
    my %usernames = (
      fred => 'Fred Bloggs',
      joe  => 'Joe Bloggs',
    );

    ## Populate in list context, forces use of create() and any deflators.
    my @users = $users_rs->populate([
    {
      realname => $usernames{fred},
      username => 'fred',
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'mypass'),
      email    => 'fred@bloggs.com',
      posts    => [
        {  title => 'Post 1', post => 'Post 1 content', created_date => DateTime->new(year => 2012, month => 01, day => 01) },
        {  title => 'Post 2', post => 'Post 2 content', created_date => DateTime->new(year => 2012, month => 01, day => 03) },
      ],
    },
    {
      realname => $usernames{joe},
      username => 'joe',
      password => Authen::Passphrase::SaltedDigest->new(algorithm => "SHA-1", salt_random => 20, passphrase=>'sillypassword'),
      email    => 'joe@bloggs.com',
    },
    ]
    );


    foreach my $username (keys %usernames) {
      ## can we retrieve fred+joes realnames:
      
      my $user = $users_rs->find({ username => $username });
      is($user->realname, $usernames{$username}, "$username still retrievable");
      
      ## are they different in the database:
      isnt($user->get_column('realname'), $usernames{$username}, "$username isnt stored as itself");      
    }
    
    ## Extra test, make sure both realnames in the database arent stored as the same thing
    isnt($users_rs->find({ username => 'fred' })->get_column('realname'),
         $users_rs->find({ username => 'joe' } )->get_column('realname'),
         'Users arent stored exactly the same');
         
    done_testing;


## Methods on Row and ResultSet objects

To add your own methods to your Row object to perform calculations or
manipulations on your data at runtime, we just need to add the methods
to the Result class, which the Row object inherits from.

Suppose we wanted to be able to get the host portion of the user's
email address, without the overhead of creating the Email::Address
object everytime we access the `email` accessor, as we had in
[](chapter_06-turning-column-data-into-useful-objects)
above. We can just add our own separate method:

    ## in MyBlog/Schema/Result/User.pm

    use Email::Address;

    __PACKAGE__->load_components(
      'InflateColumn::Authen::Passphrase'
    ); 

    sub get_email_host {
      my ($self) = @_;
      
      return Email::Address->parse($self->email)->host;
    }

Here `$self` is the Row object, so you can query other column values
or even related tables if needed. Now we just `find` a user object to
call it on:

    my $freduser = = $schema->resultset('User')->find({
      username => 'fredbloggs'
    }, {
      key => 'username_idx',
    });
    
    ## This is still a string:
    print $freduser->email, "\n";
    
    ## get_ema_host returns the hostname from the email:
    print $freduser->get_email_host, "\n";

Adding methods to ResultSets is also a useful technique to make
reusable and chainable queries. By default resultsets are created from
the `DBIx::Class::ResultSet` class. To extend this with your own class
and methods, write a class with the same name as the corresponding
_Result_ class, but change the namespace to _ResultSet_.

We can replace our literal SQL-based PostsAndUser view from the
[](chapter_05-real-or-virtual-views-and-stored-procedures) chapter,
and store it as a DBIx::Class created query in a ResultSet
method. Create a new file as `MyBlog/Schema/ResultSet/Post.pm`:

    package MyBlog::Schema::ResultSet::Post;
    
    use strict;
    use warnings;
    
    use base 'DBIx::Class::ResultSet';
    
    sub posts_and_user {
      my ($self, $user_id) = @_;
      
      return $self->search(
        {
          'user.id' => $user_id,
        },
        {
          prefetch => ['user'],
        }
      );
    }
    
    1;
    
This new file will be automatically loaded as the ResultSet class for
the Post ResultSource, by the `load_namespaces` method in our Schema
class.
    
The query can now be assembled and run by DBIx::Class on demand, to try it out:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $posts_rs= $schema->resultset('Post');
    
    my $posts_with_user = $posts_rs->posts_and_user($fred_id);

## Storing your own data

An often asked question is how to store more, non-database data into
the Row objects, for the convenience of keeping all the data
together. As Row objects inherit from our Result classes, we can add
accessors for other data there. DBIX::Class uses the
[Class::Accessor::Grouped](http://metacpan.org/module/Class::Accessor::Grouped)
module underneath, so to add our own accessors we can just use the
inherited class methods, for example `mk_group_accessors`:


    package MyBlog::Schema::Result::Email;
    
    use strict;
    use warnings;
    
    use base 'DBIx::Class::Core';
    
    __PACKAGE__->mk_group_accessors(simple => qw(dateofbirth));
    
And then just use the method to read and write the value:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User');
    my $user = $users_rs->find({ username => 'fred' });
    
    $user->dateofbirth('1980-01-10');
    
    my $dob = $user->dateofbirth();
    
This can of course also be done with
[Moose](http://metacpan.org/module/Moose) attributes instead. As
DBIx::Class implements its own `new` method, we'll need to add
[MooseX::NonMoose](http://metacpan.org/module/Moose) as well:

    package MyBlog::Schema::Result::Email;
    
    use Moose;
    use MooseX::NonMoose;
    
    extends 'DBIx::Class::Core';
    
    has 'dateofbirth' => (is => 'rw');
    
Just the same usage:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs = $schema->resultset('User');
    my $user = $users_rs->find({ username => 'fred' });
    
    $user->dateofbirth('1980-01-10');
    
    my $dob = $user->dateofbirth();

Using Moose of course enables you to add default values, validation,
types and so on. See the
[attributes manual](http://metacpan.org/module/Moose::Manual::Attributes)
for more details.

## Setting default values

Our `created_date` column in the Post table is set up to take a
`datetime` value, currently we have to always supply the timestamp to
store for every create post. As this is the date of post creation, it
would be useful to be able to just ignore that field and have it
default to the current datetime. There are a number of ways to do this
with DBIx::Class.

One straight forward way is to let the database itself supply the
value using the SQL keyword `DEFAULT`. We can have DBIx::Class'
`deploy` method (as described in [](chapter_03-describing-your-database))
output this keyword by adding the `default_value` key to the column
info data in the Result class:

    package MyBlog::Schema::Result::Post;

    __PACKAGE__->add_columns(
    # ...
    created_date => {
      data_type            => 'datetime',
      default_value        => \'CURRENT_TIMESTAMP',
      retrieve_on_insert   => 1,
    }
    );

We use a scalar reference here to indicate that the content should be
sent literally to the database, and not turned into a quoted string
value. `CURRENT_TIMESTAMP` is the correct way to indicate the current
date and time in the syntax of some relational databases, it will be
converted (by
[SQL::Translator](http://metacpan.org/module/SQL::Translator)) into
the correct incantation for your particular
database[^pleasehelp]. 

The `retrieve_on_insert` key has been added to instruct DBIx::Class to
fetch the default value from the database and store it in the Row
object after the row is created.

An alternative method is to supply the value for the timestamp field
in Perl, automatically adding it to the Row object just before it is
sent to the database. This gives us more flexibility about if and when
the value is supplied or updated. There is a separate component on CPAN which provides this functionality, [DBIx::Class::TimeStamp](http://metacpan.org/module/DBIx::Class::TimeStamp). Install it from CPAN then add it as a component to the `Post` Result class:

    package MyBlog::Schema::Result::Post;
    
    use strict;
    use warnings;
    
    use base 'DBIx::Class::Core';
    
    __PACKAGE__->load_components(qw/TimeStamp/);

Note that we have replaced the existing `InflateColumn::DateTime`
component, the TimeStamp loads the DateTime component for you, as it
uses that functionality itself.

Now edit the `add_columns` call to include the new keys
`set_on_create` and `set_on_update` in the column info hashref for the
`created_date` field to control when the values are set:

    package MyBlog::Schema::Result::Post;

    __PACKAGE__->add_columns(
    # ...
    created_date => {
      data_type            => 'datetime',
      set_on_create        => 1,
      set_on_update        => 0,
    }
    );

As implied by the key names, `set_on_create` is set to a true value to
have TimeStamp provide a datetime value when a new Row is `create`d,
and `set_on_update` controls whether TimeStamp will update the value
in the field when updates are made to the Row. As we want the field to
contain only the datetime the Post was created, we only set the
former. This time we don't need the `retrieve_on_insert` as the value
is set into the object from the Perl code, and doesn't need fetching
from the database.

After choosing a method to use and setting up the Post Result class,
we now `create` new Post entries just by supplying all the
required other needed values and leaving out the `created_date` value:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs= $schema->resultset('User');
    my $fred = $users_rs->find({ username => 'fred' });
    
    $fred->create_related('posts', {
       title => 'My Post',
       post => 'Some content',
    });
    
You'll notice that out of the five columns for the posts table we can
skip three, `id` as it is an auto increment primary key and will be supplied by
the database, `user_id` as we're creating a related entry and get the
value from the user object, and now `created_date` as it is defaulted.

To default any type of value in your Perl code, you can use the
component
[DBIx::Class::DynamicDefault](http://metacpan.org/module/DBIx::Class::DynamicDefault)
from CPAN. (Which is used by the TimeStamp component
underneath). Here's how to implement the default our `created_date`
value using this instead of DBIx::Class::TimeStamp:

    package MyBlog::Schema::Result::Post;

    use strict;
    use warnings;
    
    use base 'DBIx::Class::Core';
    
    use DateTime;

    __PACKAGE__->add_columns(
    # ...
    created_date => {
      data_type                        => 'datetime',
      dynamic_default_on_create        => 'set_created_date',
      dynamic_default_on_update        => '',
    }
    );

    sub set_created_date {
      return DateTime->now();
    }

DynamicDefault allows you to supply a code reference or the name of a
method to call when updating or creating a Row. The method will be
called on the Row object itself, so you can write it in the Result
class.


## Writing your own components

Back in our Email::Address example in the section
[](chapter_06-turning-column-data-into-useful-objects) we showed how
to create your own component to apply column inflation/deflation to
several Result classes. Now we take a look at some more methods that
are commonly extended to add more functionality.

Before building your own component make sure you've checked on CPAN to
see if there is already a component that does what you need, and ask
in the IRC community channel "#dbix-class" at irc.perl.org.

If you've done all that and you'd still like to write your own then
you first need to decide which parts of the process of creating,
inserting, updating and deleting data you want to extend. We'll look
at all the available Schema, ResultSource, Row and ResultSet methods
and dicuss why you would need each one.

For each of these, you can use Class::C3 / mro method dispatching with
`$self->next::method` to call the normal code workflow. This is
demonstrated for each method.

### Result class - new

Extending the `new` method in your Result class can be used to
influence how the values passed to the `create` method are
handled. `create` itself just calls `new` then `insert`, so there is
no need to override it.

For example to create / import a user and a bunch of existing posts
using a simple arrayref of post titles and contents:

    package MyBlog::Schema::Result::User;
    
    # ...
    
    sub new {
      my ($class, $attrs) = @_;

      # convert input of [ [], []] to [{}, {}]      
      my $posts = [map { +{ title => $_->[0], post => $_->[1] }} 
        @{ $attrs->{posts} }];
      $attrs->{posts} = $posts;
      
      $self->next::method($attrs);
    }

Which will now cope with this structure:

    my $userdata = {
      username => 'fred',
      realname => 'Fred Bloggs',
      password => Authen::Passphrase::SaltedDigest->new(
         algorithm => "SHA-1", 
         salt_random => 20,
         passphrase => 'mypass',
      ),
      email => 'fred@bloggs.com',
      posts => [ [ 'First Post', 'Post1 content' ], [ 'Post two', 'Post2 content']],
      };
      
      $schema->resultset('User')->create($userdata);


### Result class - insert

Extensions to `new` will be applied as the Row object is created. To
change data just as it's being inserted into the database, for example
to set a timestamp (datetime) field at the last possible moment,
extend the `insert` method instead.

    package MyBlog::Schema::Result::Post;
    
    # ...
    use DateTime;
    
    sub insert {
      my ($self) = @_;

      $self->created_date(DateTime->new);
      $self->next::method();
    }

Of course, the
[DBIx::Class::TimeStamp](http://metacpan.org/module/DBIx::Class::TimeStamp)
module exists to do this particular defaut-value setting for you. To
set defaults for things other than datetime fields, use the
[DBIx::Class::DynamicDefault](http://metacpan.org/module/DBIx::Class::DynamicDefault)
module.

### Result class - update

While the `create` method can handle creation of related rows, the
`update` method does not yet as it is more difficult to determine what
is required. For example, does a User update with a set of Posts mean
replace all the existing Posts, or just add new ones? We can however
enhance it to fit our own needs.

As we've extended `new`, we could also amend `update` in the same way
so that it takes the same data structures and adds more posts for the
user. To do this we extract the code written for `new` and re-use it:

    package MyBlog::Schema::Result::User;
    
    # ...
    
    sub post_array_to_hashref {
      my ($self, $posts_array) = @_;
      
      # convert input of [ [], []] to [{}, {}]      
      my $posts = [map { +{ title => $_->[0], post => $_->[1] }} 
        @{ $attrs->{posts} }];
      
      return $posts;
    }
    
    sub new {
      my ($class, $attrs) = @_;
      
      $attrs->{posts} = $self->post_array_to_hashref($attrs->{posts});
      
      $self->next::method($attrs);
    }
    
    sub update {
      my ($self, $attrs) = @_;
      
      ## Collect and remove the posts values, as update doesn't know what to do with them
      my $posts = delete $attrs->{posts};
      $self->next::method($attrs);

      ## Add new posts for each post, this does not replace existing posts  
      my $post_hashrefs = $self->post_array_to_hashref($posts);     
      $self->create_related('posts', $_) for (@{$posts});
      
      return $self;
    }

### Result class - delete

The `delete` method can be extended, for example, to remove any associated
non-database content, or empty a local cached copy. 

Using the imaginary class UserImages, which holds paths to stored
images on disc, we have it remove (unlink) the file on delete of the
row:

    package MyBlog::Schema::Result::UserImages;
    
    # ...
        
    sub delete {
      my ($self) = @_;

      $self->next::method();
      unlink($self->image_path);
    }

This example has the extending code after the actual delete (the
`next::method`) to ensure that it only happens if the database DELETE
didn't fail.

Again, there is already a module to deal with file and path storage,
[DBIx::Class::InflateColumn::FS](http://metacpan.org/module/DBIx::Class::InflateColumn::FS),
so use it unless you have more complicated needs.

### ResultSet - delete / update

Don't miss out the methods available on the ResultSet objects, which
will `update` or `delete` multiple rows at once. Note that there are
also `delete_all` and `update_all` methods available which will run
each update or delete operation individually on the Row objects, and
thus call any code you have added in your Result Class.

As shown earlier in
[](chapter_05-data-set-manipulation-and-resultset-extension), we need
to create an extra ResultSet class to extend ResultSet methods. By
default the base `DBIx::Class::ResultSet` class is used, to extend it
for a particular ResultSet type, create a file in the
MyBlog::Schema::ResultSet namespace, and add your methods:

    package MyBlog::Schema::ResultSet::User;
    
    use strict;
    use warnings;
    
    use base 'DBIx::Class::ResultSet';

    sub update {
      my ($self, $attrs) = @_;
      
      $self->next::method($attrs);
    }

    sub delete {
      my ($self) = @_;
      
      $self->next::method();
    }
    
    1;

### Aside -  Querying column and other source data

Each Row or ResultSet object has access to the ResultSource object
created by loading the Result class, via the `result_source`
method. The ResultSource can be queried for information about the
columns and relationships, here are some of the available methods:

* `columns` - A list of the column names added using `add_columns`.
* `column_info` - The hashref of data provided to `add_columns` for a given column.
* `relationships` - A list of relationship names added in the Result class.
* `relationship_info` - A hashref of data about the given relationship, details are in the docs for `add_relationship`.
* `unique_constraints` - A hash of unique constraints defined using `add_unique_constraint`, keyed on the constraint name.

Generally when overloading Row or ResultSet objects you can just
retrieve the data for the new keys by querying the ResultSource in the
overloaded Row and ResultSet methods. Here's an example using the
`update` overload:

    sub update {
      my ($self, $attrs) = @_;
      
      foreach my $col ($self->result_source->columns) {
        if($self->result_source->column_info($col)->{set_on_create} {
          $self->$col(DateTime->new);
        }
    }

### Result class - register_column

The `register_column` method is run once for each column that is
created using `add_columns`, this is the place to do any complicated
calculations needed if you have added new keys to your column info, as
it will only be run once upon load of the Schema. 

In this example, if we want to allow the user to set some extra keys,
but also provide defaults, we can check and set these in
`register_column`.

    sub register_column {
        my ($self, $column, $info, @rest) = @_;
        $self->next::method($column, $info, @rest);

        ## Skip this column unless we care about it
        return unless defined $info->{'is_somethingwecareabout'};

        my $my_class = $info->{my_set_class} || 'Some::Class';
        eval "use $my_class";
        $self->throw_exception("Error loading $my_class: $@") if $@;

        ## Setup the inflation based on the class: 
        $self->inflate_column(
            $column => {
                inflate => sub { return $my_class->new(shift); },
                deflate => sub { return scalar shift->new; },
            }
        );
    }

### Schema class - register_class

The Schema class is also available for extension or adding components,
`register_class` for example is called for each Result class loaded by
`load_namespaces`.

[^pleasehelp]: SQL::Translator supports at least SQLite, MySQL, Postgres, SQL Server. If this doesn't work for your particular database, please contact the team on IRC or via the CPAN bug report system.
