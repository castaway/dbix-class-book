## Skeleton User.pm code for Chapter 03 - Describing your database

package MyBlog::Schema::Result::User;
use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw(InflateColumn::Authen::Passphrase));
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
      inflate_passphrase => 'rfc2307',
    },
    email => {
      data_type => 'varchar',
      size => 255,
    },
 );

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('username_idx' => ['username']);
# __PACKAGE__->has_many('posts', 'MyBlog::Schema::Result::Post', 'user_id');

1;

