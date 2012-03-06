#!/usr/bin/perl

use strict;
use warnings;

use File::Path 'mkpath';
use File::Spec::Functions qw( catfile catdir splitpath );

# my $sections_href = get_section_list();

for my $chapter (get_chapter_list())
{
    my $text = process_chapter( $chapter );
    my $output_file = $chapter;
    ## chapters/XX-blah.md -> build/chapters/chapter_XX.pod
    $output_file =~ s/(\d{2})-.+md$/chapter_$1.pod/;
    $output_file =~ s{^chapters}{build/chapters};
    write_chapter( $output_file, $text );
}

#die( "Scenes missing from chapters:", join "\n\t", '', keys %$sections_href )
#    if keys %$sections_href;

exit;

sub get_chapter_list
{
    my $glob_path = catfile( 'chapters', '*.md' );
    return glob( $glob_path );
}

sub get_section_list
{
    my %sections;
    my $sections_path = catfile( 'sections', '*.pod' );

    for my $section (glob( $sections_path ))
    {
        next if $section =~ /\bchapter_??/;
        my $anchor = get_anchor( $section );
        $sections{ $anchor } = $section;
    }

    return \%sections;
}

sub get_anchor
{
    my $path = shift;

    open my $fh, '<:utf8', $path or die "Can't read '$path': $!\n";
    while (<$fh>) {
        next unless /Z<(\w*)>/;
        return $1;
    }

    die "No anchor for file '$path'\n";
}

sub process_chapter
{
    my ($path) = @_;
    my $pandoc_output = $path;
    $pandoc_output =~ s/(\d{2})-.+md$/chapter_$1.pod/;
    $pandoc_output =~ s{^chapters}{build/pod};

    mkpath('build/pod') unless -e 'build/pod';
    system("pandoc", "$path", "-f", "markdown", "-t", "pseudopod", "-o", $pandoc_output);

    post_process($pandoc_output);

    my $text                 = read_file( $pandoc_output );

#    $text =~ s/^L<(\w+)>/insert_section( $sections_href, $1, $path )/emg;

#    $text =~ s/(=head1 .*)\n\n=head2 \*{3}/$1/g;
    return $text;
}

## shift all =head tags down one (1 = 0, 2 = 1 etc)
## Insert Z<> tags for each head0
sub post_process
{
    my ($path) = @_;

    local $^I = "";
    local @ARGV = ($path);

    my $chapter = ( splitpath $path )[-1];
    $chapter =~ s/\.pod$//;
    while(<>) {
        s/^=head(\d)/'=head' . ($1-1)/e;

        if(/^=head(\d+) (.*)\n/) {
#            print STDERR "Got $_\n";
            my ($level,$name) = ($1,$2);
            my $z = "$chapter-$2";
            $z = lc($z);
            $z =~ s/chapter\s+\d+\s+-\s+//;
            $z =~ s/\W/-/g;
            $z =~ s/-+/-/g;
            $z =~ s/-$//;
            $_ = "=head${level} $name\n\nZ<$z>\n";
        }

        print;
    }
    
}

sub read_file
{
    my $path = shift;
    open my $fh, '<:utf8', $path or die "Can't read '$path': $!\n";
    return scalar do { local $/; <$fh>; };
}

sub insert_section
{
    my ($sections_href, $name, $chapter) = @_;

    die "Unknown section '$name' in '$chapter'\n"
        unless exists $sections_href->{ $1 };

    my $text = read_file( $sections_href->{ $1 } );
    delete $sections_href->{ $1 };
    return $text;
}

sub write_chapter
{
    my ($path, $text) = @_;
    my $name          = ( splitpath $path )[-1];
    my $chapter_dir   = catdir( 'build', 'chapters' );
    my $chapter_path  = catfile( $chapter_dir, $name );

    mkpath( $chapter_dir ) unless -e $chapter_dir;

    open my $fh, '>:utf8', $chapter_path
        or die "Cannot write '$chapter_path': $!\n";

    print {$fh} $text;

    warn "Writing '$chapter_path'\n";
}
