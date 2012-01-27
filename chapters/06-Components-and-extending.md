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

## Adding methods to Row/ResultSet objects

## Storing your own data

## Setting default values, validation 

## Encoding content (passwords)

## Auditing, previewing data
