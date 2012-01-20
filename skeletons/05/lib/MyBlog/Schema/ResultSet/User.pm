package MyBlog::Schema::ResultSet::User;
    
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

__PACKAGE__->load_components(qw/Helper::ResultSet::SetOperations/);

1;
