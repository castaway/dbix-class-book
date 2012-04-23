% The DBIx::Class Book
% Jess Robinson
% January 2012

Chapter 1 - Introduction and general data storage
=================================================

This book will introduce you to DBIx::Class, the Perl module for dealing with your database(s).

If you are already sure that DBIx::Class is the solution to your Perl data storage problems, then you can probably skip this chapter and move straight on to [](chapter_02-databases-design-and-layout), or [](chapter_03-describing-your-database) to start learning. This chapter explains what DBIx::Class is and when to use it instead of some other ways of storing data.

What is DBIx::Class?
--------------------

DBIx::Class is an ORM[^ORM] built upon [DBI](http://metacpan.org/dist/DBI)[^DBI], [SQL::Abstract](http://metacpan.org/dist/SQL-Abstract) and [SQL::Translator](http://metacpan.org/dist/SQL-Translator).

DBI provides the foundation by abstracting away how to actually access each database system, with a standard for database drivers for Perl.

SQL::Abstract converts Perl data structures into SQL DML[^DML] in a generic fashion suitable for most databases. It also has a number of extensions to cover parts of SQL which are not standardised.

DBIx::Class adds the layer which extracts the definition of the database tables into Perl classes, allows querying of the data without writing SQL manually, and promotes re-use of code.

Methods of data storage with Perl
---------------------------------

There are many ways to store data with Perl, so why use this particular one? Some of the common choices are listed here, together with their strengths and weaknesses. Make sure you've made the right choice before continuing on to learn about databases and DBIx::Class.

Note that none of the choices are all-exclusive, you can use multiple types of data storage in your application. For example you can use an RDBMS to keep finanial data and orders safe, while using a NoSQL system to store user data.

### Data::Dumper and Storable

[Data::Dumper](http://metacpan.org/module/Data::Dumper) is a module for outputting a string representation of a Perl data structure. Its used mostly for debugging purposes. The data output by Data::Dumper can in theory be read back in, using eval. To output Perl data structures to disc and read them back in, its reccommended to use the [Storable](http://metacpan.org/module/Storable) standard module. Storable provides 'nstore' and 'retrieve' functions that will save a structure to a file and reload it. 

#### Pros

* Part of core Perl.
* Requires only an available file system to use.

#### Cons

* No data-sharing with non-Perl systems.
* No control over which data is added, changed or removed (permissions).
* No transaction support - data lost if file system disappears mid write/read.
* No permissions system

#### Useful for

* Caching data between successive runs of a script.

#### Example

    use strict;
    use warnings;
    use Storable;

    # Read previously stored data    
    my $list = retrieve('/tmp/my-cached-data.dat');
    
    # Update cache
    $list->{oranges} = 4;
    
    # Save new cache
    nstore($list, '/tmp/my-cached-data.dat');


### XML/JSON/CSV/YAML

CPAN[^CPAN] has modules such as [XML::Simple](http://metacpan.org/module/XML::Simple), [JSON](http://metacpan.org/module/JSON), [Text::xSV](http://metacpan.org/module/Text::xSV) and [YAML](http://metacpan.org/module/YAML) to read and write many of the common text-based data sharing formats. These can be used to share data with other websites, languages or software that support them.

#### Pros

* Interaction with other systems.
* Network transportable data.
* Data streaming.
* Human-readable.

#### Cons

* No transactions built-in.
* No control over which data is added, changed or removed (permissions).
* Large amounts of data.

#### Useful for

* Human-readable configuration files.
* Interacting with other software that already uses these formats.

#### Example

    use strict;
    use warnings;
    
    use XML::Simple;
    
    my $xml = '<some><format from="another">system</format></some>';
    my $perldata = XMLIn($xml);
    
    $perldata->{some}{format}{from} = 'this';

### Binary formats

Binary file formats are used for compact storage and faster access. Predefined binary formats include Images, such as JPEG or PNG formats, which can be read and written using the [Imager](http://metacpan.org/module/Imager) module. Music files are also stored in binary formats, CPAN provides also modules for manipulating MP3 tags, such as [MP3::Tag](http://metacpan.org/module/MP3::Tag). 

#### Pros

* Well-defined existing formats, readable with a large number of programs.
* Good for visual data, eg graphs.

#### Cons

* No transactions.
* Not human-readable without more software.
* Can design own format, but then only readable if the format is implemented into other systems.

#### Useful for

* Making small changes, eg metadata in images and music.
* Visual data, eg creating graphs.

#### Example

    use strict;
    use warnings;
    
    use Image::ExifTool qw(:Public);
    
    my $exift = Image::ExifTool->new();
    $exift->ExtractInfo('a.jpg');
    my $orig_datetime = $exitf->GetValue('DateTimeOriginal');
    
    $exift->SetNewValue('Artist', 'Fred');
    $exift->WriteInfo('a.jpg');


### Relational Databases

Databases are systems for storing structured data, in a pre-defined layout. The layout of the data is set up for a particular use or application and the database system (RDBMS) enforces the constraints on the data to keep it consistent. Databases are access in Perl using DBI[^DBI] and the driver for the chosen database, popular ones are the open source systems [Postgres](http://metacpan.org/module/DBD::Pg), [MySQL](http://metacpan.org/module/DBD::mysql) and [SQLite](http://metacpan.org/module/DBD::SQLite). DBI also supports the big commercial databases such as [Oracle](http://metacpan.org/module/DBD::Oracle), [DB2](http://metacpan.org/module/DBD::DB2) and [MS SQL Server](http://metacpan.org/module/DBD::Sybase).

#### Pros

* Structured data with constraints built-in.
* Sharable with other applications, standard access.
* Control over data access / authentication.
* Transactions.
* Scalable for large amounts of data.

#### Cons

* Extra external application and drivers required.

#### Useful for

* Applications with persistent structured and related data.

#### Example

### NoSQL systems

NoSQL actually means "Not a traditional relational database", some do in fact use the SQL language or a subset of it. There are several subtypes of NoSQL systems, Key-Value storage, Document storage, Big-Table and Graph storage. Generally they are usable similarly to RDBMS', and provide more performance and ease of use, countered with less promise of consistency and transactions. CPAN provides modules for several popular NoSQL systems, [MongoDB](http://metacpan.org/module/MongoDB), [CouchDB](http://metacpan.org/module/CouchDB::Client).

#### Pros

* Faster than traditional databases.
* No structure defintions required.

#### Cons

* Less consistency, constraint support.
* Transactions only supported in some system.

#### Useful for

* Large scale performant applications that can afford to lose consistency.

#### Example

Why a relational database?
--------------------------

Why DBIx::Class?
----------------




[^ORM]: Object-relational Mapper, or Mapping is the technique of converting data represented in simple values, such as strings in a database, into objects containing the data and having appropriate methods to act upon it.
[^RDBMS]: Relational Database Management Systems - databases such as Oracle, DB2, MySQL, Postgres and MS SQL Server.
[^DBI]: Perl's Database Interface, a module for standardising querying various RDBMS[^RDBMS] systems.
[^DML]: Data Manipulaton Language, the part of SQL which is used to add, change and remove data.
[^CPAN]: The [Comprehensive Perl Archive Network](http://pause.cpan.org) 
