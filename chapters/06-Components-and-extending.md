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
when the `create` or `new` methods are called. This functionality will
be explained later in the section
[Setting default values and validation](#Setting-default-values-and-validation).

## Methods on Row/ResultSet objects

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

## Storing your own data

## Setting default values, validation 

## Encoding content (passwords)

## Auditing, previewing data
