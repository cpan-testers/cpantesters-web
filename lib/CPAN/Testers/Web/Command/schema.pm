package CPAN::Testers::Web::Command::schema;
our $VERSION = '0.001';
# ABSTRACT: Work with the DBIx::Class schema for this site

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use CPAN::Testers::Web::Base;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw( getopt );
use Mojo::File qw( path );
use File::Share qw( dist_dir );

sub run {
    my ( $self, @args ) = @_;

    my %opt;
    getopt \@args, \%opt,
        'p|preversion:s',
        ;
    my $task = shift @args;

    my %tasks = (
        prepare => \&prepare,
        install => \&install,
        upgrade => \&upgrade,
        check => \&check,
    );

    $tasks{ $task }->( $self, \@args, \%opt );
}

sub prepare {
    my ( $self, $args, $opt ) = @_;
    my $schema = $self->app->schema->web;
    my $sql_dir = path( dist_dir( 'CPAN-Testers-Web' ), 'schema' );
    my $version = $schema->schema_version();
    $schema->create_ddl_dir( 'MySQL', $version, $sql_dir, $opt->{preversion} );

    # Create the SQLite schema directory for testing purposes
    $schema = CPAN::Testers::Web::Schema->connect( 'dbi:SQLite::memory:' );
    $schema->create_ddl_dir( 'SQLite', $version, $sql_dir, $opt->{preversion} );
}

sub check {
    my ( $self, $args, $opt ) = @_;
    my $schema = $self->app->schema->web;
    say "  Current: " . $schema->get_db_version;
    say "Available: " . join ", ", $schema->ordered_schema_versions;
}

sub install {
    my ( $self, $args, $opt ) = @_;
    my $schema = $self->app->schema->web;
    $schema->install;
}

sub upgrade {
    my ( $self, $args, $opt ) = @_;
    my $schema = $self->app->schema->web;
    $schema->upgrade;
}

1;
