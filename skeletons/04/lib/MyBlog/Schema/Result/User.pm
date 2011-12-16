## Skeleton User.pm code for Chapter 04 - Creating, Reading, Updating and Deleteing

package MyBlog::Schema::Result::User;
use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('users');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    realname => {
      data_type => 'varchar',
      size => 255,
    },
    username => {
      data_type => 'varchar',
      size => 255,
    },
    password => {
      data_type => 'varchar',
      size => 255,
    },
    email => {
      data_type => 'varchar',
      size => 255,
    },
 );

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('username_idx' => ['username']);
__PACKAGE__->has_many('posts', 'MyBlog::Schema::Result::Post', 'user_id');

1;

