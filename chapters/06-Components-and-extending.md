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
understood the basic setup in [Chapter 3](03-Describing-database) and
understand how to use
[mro method dispatching](https://metacpan.org/module/mro#next::method).

NOTE: On versions of perl before 5.10.x you will need to read
[the Class::C3 docs](https://metacpan.org/module/Class::C3#METHOD-REDISPATCHING)
instead.

We will be giving code examples and tests using Test::More so you
should be familiar with Perl unit testing. The database we are using
is provided as an SQL file you can import into an
[SQLite database](http://search.cpan.org/dist/DBD-SQLite) to get
started.

[Download code](http://dbix-class.org/book/code/chapter06.zip)

Introduction
------------

We've already mentioned a couple of useful components in
[Chapter 3](03-Describing-database) for expanding simple database
content into objects, we'll explain how this works and how to add your
own inflations. We'll also cover storing data that isn't in the
database, adding re-usable query methods and validation.

## Turning column data into useful objects

The data we store in databases is generally simple, or scalar data,
strings, numbers, timestamps, IPs. The DBIx::Class featues we've seen
so far will extract this data into an object representing a single Row
or Result. The actual content returned by the accessors is however
still the same simple data. We can add *Inflation/Deflation*
components to our Result classes to convert the data to and from
objects.

We can add any inflation/deflation functionality to our Result class
by using the `inflate_column` class method:

This example uses the
[Email::Address](http://metacpan.org/module/Email::Address) module,
you will need to install it from CPAN to run this snippet.

    ## Add to the existing MyBlog/Schema/Result/User.pm
    
    use Email::Address;
    
    __PACKAGE__->inflate_column('email', {
      inflate => sub { my $emailstring = shift; return Email::Address->parse($emailstring); },
      deflate => sub { my $emailobj = shift; return $emailobj->address(); },
    });

The code reference for the `deflate` value is run when creating a new user, if you supply an object for the `email` value, for example:

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
    
Using the deflator is not compulsory, we can still pass in a string
value to store, which will bypass the deflate code.

The code reference supplied as the `inflate` value is run when you
call the Row accessor `email`, so now if we fetch a user, we can
examine the email address more closely:

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
      
To re-use your Inflation/Deflation code, it can be made into a
component module and added to each Result class as needed, using the
`load_components` class method already seen in Chapter 3. Generic
re-usable components go into the `DBIx::Class::InflateColumn`
namespace, components in other namespaces can be loaded by prepending
a `+` to the name. So we can make this a MyBlog component:

    package MyBlog::Schema::InflateColumn::Email;
    
    use strict;
    use warnings;
    
    use Email::Address;
    
    sub register_column {
      my ($self, $column, $info, @rest) = @_;
      $self->next::method($column, $info, @rest);
 
      return unless defined $info->{'is_email'};
      
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
    
Note how components have to hook into `register_column` when adding
inflate/deflate, and then somehow decide which columns to add the code
to. The name of the column and the info hash used in `add_columns` are
passed as parameters. We let the normal `register_column` activities
happen by calling the mro method dispatching call `next::method`, then
run the extra code to assign the inflate/deflate code to the chosen
column.

Now we can use this instead:

    ## in MyBlog/Schema/Result/User.pm

    __PACKAGE__->load_components('+MyBlog::Schema::InflateColumn::Email', 'InflateColumn::Authen::Passphrase'); 

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

Note that inflation and deflation code is only run for objects and
references, plain scalar values and undef bypass the code completely.

## More column data filtering and extending

Inflation and deflation are one way to change or adapt the data on the
way into or out of the database. Another component that can be used to
change the content is the provided `FilterColumn` component. This is
used to arbitrarily change any data, not just references and objects.

    ## in MyBlog/Schema/Result/User.pm

    __PACKAGE__->load_components('FilterColumn', 
      '+MyBlog::Schema::InflateColumn::Email', 
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

FilterColumn, unlike the InflateColumn code, is also passed the Row
object, giving the code access to other values in the same row.

This is one way to remove any accidental whitespace at the beginning
and end of a string value such as the `username` column, before saving
it to the database.

Another way would be to rename the actual accessor method for the
column, and write your own. This code can do anything you like, and
also gets the Row object.

    ## in MyBlog/Schema/Result/User.pm

    __PACKAGE__->load_components(
      '+MyBlog::Schema::InflateColumn::Email', 
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
`update` methods, for examples see the section
[Setting default values and validation](#Setting-default-values-and-validation).

## Your turn, encode the user's real names

Several ways to extend the Result class and change the database values
going in and out of the storage layer. For this exercise you're going
to obfuscate the user's stored `realname` in the database, preferably
in such a way that it can be converted back to the actual value when
retrieved.

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

To add methods to your Row object to perform calculations or
manipulations on your data at runtime, we just need to add the methods
to the Result class, which the Row object inherits from.

Suppose we wanted to be able to get the host portion of the user's
email address, without the overhead of creating the Email::Address
object everytime we access the `email` accessor, as we had in
[Turning column data into useful objects](#Turning-column-data-into-useful-objects)
above. We can just add our own separate method:

    ## in MyBlog/Schema/Result/User.pm

    use Email::Address;

    __PACKAGE__->load_components(
      'InflateColumn::Authen::Passphrase'
    ); 

    sub get_email_host {
      my ($row) = @_;
      
      return Email::Address->parse($row->email)->host;
    }
    
And call it on the User object:

    my $freduser = = $schema->resultset('User')->find({
      username => 'fredbloggs'
    }, {
      key => 'username_idx',
    });
    
    ## The email accessor now returns an Email::Address object:
    print $freduser->get_email_host, "\n";

Adding methods to ResultSets is also a useful technique to make
reusable and chainable queries. By default resultsets are created from
the `DBIx::Class::ResultSet` class. To replace this with your own
class and methods, write a class for the corresponding Result class,
in the _ResultSet_ namespace. 

We can store our PostsAndUser query from the
[Further queries and helpers](Further-queries-and-helpers#Real-or-virtual-Views-and-stored-procedures)
chapter as a method instead of a view:

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
    
Now the query can be assembled and run by DBIx::Class on demand, to try it out:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $posts_rs= $schema->resultset('Post');
    
    my $posts_with_user = $posts_rs->posts_and_user($fred_id);

## Storing your own data

An often asked question is how to store more, non-database data into
the Row objects, for the convenience of keeping all the data
together. As Row objects inherit from our Result classes, we can add
accessors for other data there. DBIX::Class uses the
[Class::Accessor::Grouped](http://metacpan.org/module/Class::Accessor::Grouped)
module underneath, so so add our own accessors we can just use the
inherited class methods:


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
DBIx::Class implements its own `new` method, we need to use
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
`datetime` value, and currently we have to always supply the timestamp
to store. We can however default this value to the current date&time
in several way. 

One straight-forward way is to let the database itself supply the
value, to include this in the DDL SQL created when running the
`deploy` method, add the `default_value` key to your column info data
in the Result class:

    package MyBlog::Schema::Result::Post;

    __PACKAGE__->add_columns(
    # ...
    created_date => {
      data_type            => 'datetime',
      default_value        => \'CURRENT_TIMESTAMP',
      retrieve_on_insert   => 1,
    }
    );
    
`CURRENT_TIMESTAMP` should be converted by
[SQL::Translator](http://metacpan.org/module/SQL::Translator) into the
correct incantation for your particular database (if not please help
us fix it!). `retrieve_on_insert` is used to ensure that this created
value is fetched and stored in any new Row objects after insertion
into the database.

We can also have the code supply the timestamp value, which gives us
more flexibility about when the value is supplied or updated. First
install the component
[DBIx::Class::TimeStamp](http://metacpan.org/module/DBIx::Class::TimeStamp)
from CPAN. Add it as a component to the `Post` Result class, and use
the `set_on_create` and `set_on_update` column info keys to control
when the values are set:

    package MyBlog::Schema::Result::Post;

    __PACKAGE__->add_columns(
    # ...
    created_date => {
      data_type            => 'datetime',
      set_on_create        => 1,
      set_on_update        => 0,
    }
    );

This time we don't need the `retrieve_on_insert` as the value is set
into the object from the Perl code.

In either case we `create` new Post entries just by supplying all the
required other needed values and leaving out the `created_date` value:

    my $schema = MyBlog::Schema->connect("dbi:mysql:dbname=myblog", "myuser", "mypassword");

    my $users_rs= $schema->resultset('User');
    my $fred = $users_rs->find({ username => 'fred' });
    
    $fred->create_related('posts', {
       title => 'My Post',
       post => 'Some content',
    });
    
You'll notice that out of the five columns for the posts table we can
skip three, `id` as its an auto increment primary key and will be supplied by
the database, `user_id` as we're creating a related entry and get the
value from the user object, and now `created_date` as its defaulted.

## Writing your own components



## Encoding content (passwords)

## Auditing, previewing data
