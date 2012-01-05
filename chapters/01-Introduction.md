% The DBIx::Class Book
% Jess Robinson
% January 2012

Chapter 1 - Introduction and general data storage
=================================================

This book will introduce you to DBIx::Class, the Perl module for dealing with your database(s).

If you are already sure that DBIx::Class is the solution to your Perl data storage problems, then you can probably skip this chapter and move straight on to [Chaper 2, "Databases, design and layout"](02-Database-design), or [Chapter 3, "Describing your database"](03-Describing-database) to start learning. This chapter explains what DBIx::Class is and when to use it instead of some other ways of storing data.

What is DBIx::Class?
--------------------

DBIx::Class is an ORM[^ORM] built upon [DBI](http://metacpan.org/dist/DBI)[^DBI], [SQL::Abstract](http://metacpan.org/dist/SQL-Abstract) and [SQL::Translator](http://metacpan.org/dist/SQL-Translator).

DBI provides the foundation by abstracting away how to actually access each database system, with a standard for database drivers for Perl.

SQL::Abstract converts Perl data structures into SQL DML[^DML] in a generic fashion suitable for most databases. It also has a number of extensions to cover parts of SQL which are not standardised.

DBIx::Class adds the layer which extracts the definition of the database tables into Perl classes, allows querying of the data without writing SQL manually, and promotes re-use of code.

Methods of data storage with Perl
---------------------------------

There are many ways to store data with Perl, so why use this particular one? Some of the common choices are listed here, together with their strengths and weaknesses. Make sure you've made the right choice before continuing on to learn about databases and DBIx::Class.

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


### Databases

Databases are systems for storing structured data, in a given layout.

### NoSQL systems



Why a database?
----------------

Why DBIx::Class?
----------------



[^ORM]: Object-relational Mapper, or Mapping is the technique of converting data represented in simple values, such as strings in a database, into objects containing the data and having appropriate methods to act upon it.
[^DBI]: Perl's Database Interface, a module for standardising querying various RDBMS[^RDBMS] systems.
[^RDBMS]: Relational Database Management Systems - databases such as Oracle, DB2, MySQL, Postgres and MS SQL Server.
[^DML]: Data Manipulaton Language, the part of SQL which is used to add, change and remove data.
[^CPAN]: The [Comprehensive Perl Archive Network](http://pause.cpan.org) 
