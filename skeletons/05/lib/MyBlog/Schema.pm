package MyBlog::Schema;

use warnings;
use strict;

our $VERSION = '0.01';

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces();

=head1 NAME

MyBlog::Schema - DBIx::Class Schema for my blogging project

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

This module represents a database schema for a Blog, used in the
DBIx::Class tutorial.

    use MyBlog::Schema;

    my $schema = MyBlog::Schema->connect('dbi:SQLite:my.db');
    ...

=head1 AUTHOR

Jess Robinson, C<< <castaway at desert-island.me.uk> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MyBlog::Schema

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Jess Robinson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of MyBlog::Schema
