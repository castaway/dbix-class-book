use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MyBlog::Schema',
    AUTHOR              => q{Jess Robinson <castaway@desert-island.me.uk>},
    VERSION_FROM        => 'lib/MyBlog/Schema.pm',
    ABSTRACT_FROM       => 'lib/MyBlog/Schema.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'DBIx::Class' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MyBlog-Schema-*' },
);
