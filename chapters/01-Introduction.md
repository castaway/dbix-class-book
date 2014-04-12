% The DBIx::Class Book
% Jess Robinson
% January 2012

Chapter 1 - Introduction and general data storage
=================================================

If you are already sure that DBIx::Class is the solution to your Perl data storage problems, then you can probably skip this chapter and move straight on to [](chapter_02-databases-design-and-layout), or [](chapter_03-describing-your-database) to start learning. This chapter explains what DBIx::Class is and when to use it instead of some other ways of storing data.

What is DBIx::Class?
--------------------

DBIx::Class is an ORM[^ORM] built upon DBI[^DBI], SQL::Abstract[^sqla] and SQL::Translator[^SQLT].

DBI provides the foundation by abstracting away how to actually access each database system, with a standard for database drivers for Perl.

SQL::Abstract converts Perl data structures into SQL DML[^DML] in a generic fashion suitable for most databases. It also has a number of extensions to cover parts of SQL which are not standardised.

SQL::Translator can convert SQL DDL[^DDL] between various databases, it is used to create `CREATE TABLE` and similar statements.

DBIx::Class adds the layer which extracts the definition of the database tables into Perl classes, allows querying of the data without writing SQL manually, and promotes re-use of code.

Methods of data storage with Perl
---------------------------------

There are many ways to store data with Perl, so why use this particular one? Some of the common choices are listed here, together with their strengths and weaknesses. Make sure you've made the right choice before continuing on to learn about databases and DBIx::Class.

Note that none of the choices are all-exclusive, you can use multiple types of data storage in your application. For example you can use an RDBMS to keep finanial data and orders safe, while using a NoSQL system to store user data.

### Data::Dumper and Storable

Data::Dumper[^datadumper] is a module for outputting a string representation of a Perl data structure. It's used mostly for debugging purposes. The data output by Data::Dumper can in theory be read back in, using eval. To output Perl data structures to disk and read them back in, it's recommended to use the Storable[^storable] standard module. Storable provides 'nstore' and 'retrieve' functions that will save a structure to a file and reload it.

#### Pros

* Part of core Perl.
* Requires only an available file system to use.

#### Cons

* No data-sharing with non-Perl systems.
* No control over which data is added, changed or removed (permissions).
* No transaction support - data lost if file system disappears mid write/read.
* No permissions system
* No support for any type of searching

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

CPAN[^CPAN] has modules such as XML::Simple[^xmlsimple], JSON[^json], Text::xSV[^textxsv] and YAML[^yaml] to read and write many of the common text-based data sharing formats. These can be used to share data with other websites, languages or software that support them.

#### Pros

* Interaction with other systems.
* Network transportable data.
* Data streaming.
* Human-readable.
* Searching can be done using XPath.

#### Cons

* No transactions built-in.
* No control over which data is added, changed or removed (permissions).
* In-line structure, lots of boilerplate/descriptive content around the data.

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

Binary file formats are used for compact storage and faster access. Predefined binary formats include Images, such as JPEG or PNG formats, which can be read and written using the Imager[^imager] module. Music files are also stored in binary formats. CPAN also provides modules for manipulating MP3 tags, such as MP3::Tag[^mp3tag].

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

Databases are systems for storing structured data, in a pre-defined layout. The layout of the data is set up for a particular use or application and the database system (RDBMS[^RDBMS]) enforces the constraints on the data to keep it consistent. Databases are accessed in Perl using DBI[^DBI] and the driver for the chosen database, popular ones are the open source systems Postgres[^pg], MySQL[^mysql] and SQLite[^sqlite]. DBI also supports the big commercial databases such as Oracle[^oracle], DB2[^db2] and MS SQL Server[^mssql].

#### Pros

* Structured data with constraints built-in.
* Sharable with other applications, standard access.
* Control over data access / authentication.
* Transactions.
* Scalable for large amounts of data.
* Many ways to search and combine the data.

#### Cons

* Extra external application and drivers required.

#### Useful for

* Applications with persistent structured and related data.

#### Example

    use strict;
    use warnings;

    use DBI;

    my $dbh = DBI->connect("dbi:SQLite:mydb.db");

    $dbh->do("CREATE TABLE users(id integer primary key, username varchar(50), password varchar(50)");

    my $sth_insert = $dbh->prepare("INSERT INTO users (username, password) VALUES(?, ?)");
    $sth_insert->execute("castaway", "mypass");

    my $sth_select = $dbh->prepare("SELECT id, username, password FROM users");
    $sth_select->execute();

    while (my $row = $sth_select->fetchrow_hashref) {
      printf("id: %d, username: %s", $row->{id}, $row->{username});
    }


### NoSQL systems

NoSQL actually means "Not a traditional relational database". Some NoSQL systems do in fact use the SQL language or a subset of it. There are several subtypes of NoSQL systems, Key-Value storage, Document storage, Big-Table and Graph storage. Generally they are usable similarly to RDBMS', and provide more performance and ease of use, countered with less promise of consistency and transactions. CPAN provides modules for several popular NoSQL systems, MongoDB[^mongodb], CouchDB[^couchdb].

#### Pros

* Faster than traditional databases.
* No structure defintions required.
* Structured searching usually included.

#### Cons

* Less consistency, constraint support.
* Transactions only supported in some systems.

#### Useful for

* Large scale performant applications that can afford to lose consistency.

#### Example

    use strict;
    use warnings;
    use MongoDB;

    my $connection = MongoDB::Connection->new(host => 'localhost', port => 27017);
    my $database   = $connection->foo;
    my $collection = $database->bar;
    my $id         = $collection->insert({ some => 'data' });
    my $data       = $collection->find_one({ _id => $id });

Why relational databases and DBIx::Class?
------------------------------------------

DBIx::Class was started back in 2005 as a "research project", or so the original author, Matt Trout, will claim if you ask him. At the time Class::DBI[^classdbi] was the module to use if you wanted to abstract your SQL into Perl speak. Some brave developers put some of the early DBIC releases into production code and that was that. Since then it as grown to be one of the larger Perl community projects, with many releases by many members of the community, and an even longer list of contributors.

I started using DBIx::Class early on in 2006, I forget exactly why, possibly something to do with SQL::Translator. I stayed for the communal feel, the responsiveness of the team to answer questions and fix bugs. At some point I got named "Documentation Queen", as I actually like writing documentation, and seem to be good at marshalling other people to write some, when they find an issue or can't understand the existing docs.

As for "why relational databases", they're versatile, covering almost any sitution or type of data you'd need to store, and then some. They come in many forms, free, stable, commercial, experimental, new, you can pick one to suit. This is not to say that I would always pick a relational database for every data storage need. As shown in the various methods available above I pick depending on my requirements: quick script (data::dumper, storable), interoperability (json, xml, imager etc), long-term large amounts (databases). I will admit to not yet having much interaction with "NoSQL" databases, I believe generally they are used for short-term storage, alongside traditional relational systems.

Presumably you picked up this book to learn about DBIx::Class. or because someone said DBIx::Class was the current Perl best practice for talking to relational databases with Perl. So let's get on with it!

Before you start
----------------

The sources of the various exercises and even code snippets for this book can be found online at dbix-class.org[^codedownload]. Some chapters will require you to install more modules from CPAN (apart from DBIx::Class itself), follow the instructions on the CPAN install[^cpaninstall] page to do this. If you get stuck, you can ask for help on IRC channel #dbix-class, or contact me via dbix-class-book@dbix-class.org

[^ORM]: Object-relational Mapper, or Mapping is the technique of converting data represented in simple values, such as strings in a database, into objects containing the data and having appropriate methods to act upon it.
[^sqla]: [](http://metacpan.org/dist/SQL-Abstract)
[^SQLT]: [](http://metacpan.org/dist/SQL-Translator)
[^DBI]: [](http://metacpan.org/dist/DBI) Perl's Database Interface, a module for standardising querying various RDBMS systems.
[^RDBMS]: Relational Database Management Systems - databases such as Oracle, DB2, MySQL, Postgres and MS SQL Server.
[^DML]: Data Manipulaton Language, the part of SQL which is used to add, change and remove data.
[^DDL]: Data Definition Language, SQL statements to define tables, indexes and views for the data storage.
[^CPAN]: The [Comprehensive Perl Archive Network](http://pause.cpan.org)
[^datadumper]: [](http://metacpan.org/module/Data::Dumper)
[^storage]: [](http://metacpan.org/module/Storable)
[^xmlsimple]: [](http://metacpan.org/module/XML::Simple)
[^json]: [](http://metacpan.org/module/JSON)
[^textxsv]: [](http://metacpan.org/module/Text::xSV)
[^yaml]: [](http://metacpan.org/module/YAML)
[^imager]: [](http://metacpan.org/module/Imager)
[^mp3tag]: [](http://metacpan.org/module/MP3::Tag)
[^pg]: [](http://metacpan.org/module/DBD::Pg)
[^mysql]: [](http://metacpan.org/module/DBD::mysql)
[^sqlite]: [](http://metacpan.org/module/DBD::SQLite)
[^oracle]: [](http://metacpan.org/module/DBD::Oracle)
[^db2]: [](http://metacpan.org/module/DBD::DB2)
[^mssql]: [](http://metacpan.org/module/DBD::Sybase)
[^mongodb]: [](http://metacpan.org/module/MongoDB)
[^couchdb]: [](http://metacpan.org/module/CouchDB::Client)
[^classdbi]: [](http://metacpan.org/module/Class::DBI)
[^codedownload]: [](http://www.dbix-class.org/book)
[^cpaninstall]: [](http://www.cpan.org/modules/INSTALL.html)
