use strict;
use warnings;
package Dist::Zilla::Role::RepoFileInjector;
# ABSTRACT: Create files outside the build directory
# KEYWORDS: plugin distribution generate create file repository
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '0.001';

use Moose::Role;

use MooseX::Types qw(enum role_type);
use MooseX::Types::Moose qw(ArrayRef Str Bool);
use Path::Tiny;
use Cwd ();

has repo_root => (
    is => 'ro', isa => Str,
    lazy => 1,
    default => sub { Cwd::getcwd() },
);

has allow_overwrite => (
    is => 'ro', isa => Bool,
    default => 0,
);

has _repo_files => (
    isa => ArrayRef[role_type('Dist::Zilla::Role::File')],
    lazy => 1,
    default => sub { [] },
    traits => ['Array'],
    handles => {
        __push_repo_file => 'push',
        _repo_files => 'elements',
    },
);

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        version => $VERSION,
    };
    return $config;
};

sub add_repo_file
{
    my ($self, $file) = @_;

    my ($pkg, undef, $line) = caller;
    $file->_set_added_by(sprintf("%s (%s line %s)", $self->plugin_name, $pkg, $line));

    $self->log_debug([ 'adding file %s', $file->name ]);

    $self->__push_repo_file($file);
}

sub write_repo_files
{
    my $self = shift;

    foreach my $file ($self->_repo_files)
    {
        my $filename = path($file->name);
        my $abs_filename = $filename->is_relative
            ? path($self->repo_root)->child($file->name)
            : $file->name;

        unlink $abs_filename if -e $abs_filename and $self->allow_overwrite;
        $self->log_fatal([ '%s already exists (allow_overwrite = 0)', $abs_filename ]) if -e $abs_filename;

        # sadly, _write_out_file does $build_root->subdir without casting first
        my $root = Path::Class::dir($filename->is_relative ? $self->repo_root : '');

        $self->log_debug([ 'writing out %s', $file->name ]);
        $self->zilla->_write_out_file($file, $root);
    }
}

1;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

=head1 DESCRIPTION

This role is to be consumed by any plugin that plans to create files outside
the distribution.

=method add_repo_file

    $plugin->add_repo_file($dzil_file);

Registers a file object to be written to disk during the C<AfterBuild> phase.
If the path is not absolute, it is treated as relative to C<repo_root>.
The file should consume the L<Dist::Zilla::Role::File> role.

=method _repo_files

Returns the list of files added via C<add_repo_file>.

=attr repo_root

A L<Path::Tiny> directory indicating the base directory where the file(s) are
written, when relative paths are provided. Defaults to the current working directory.

=attr allow_overwrite

A boolean indicating whether it is permissible for the file to already exist
(whereupon it is overwritten).  When false, a fatal exception is thrown when
the file already exists.

Defaults to false.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Role::FileInjector>

=cut
