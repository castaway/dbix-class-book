## Skeleton Post.pm code for Chapter 03

package MyBlog::Schema::Result::Post;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('posts');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    user_id => {
        data_type => 'integer',
    },
    created_date => {
        data_type => 'datetime',
    },
    title => {
        data_type => 'varchar',
        size => 255,
    },
    post => {
        data_type => 'varchar',
        size => 255,
    },
    );

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to('user', 'MyBlog::Schema::Result::User', 'user_id');

1;
