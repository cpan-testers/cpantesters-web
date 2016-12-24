package CPAN::Testers::Web;
our $VERSION = '0.001';
# ABSTRACT: Write a sentence about what it does

=head1 SYNOPSIS

    $ cpantesters-web daemon
    Listening on http://*:5000

=head1 DESCRIPTION

This is the main L<CPAN Testers|http://cpantesters.org> web application.
This application is the main platform for exploring, searching, and
interacting with CPAN Testers data.

=head1 SEE ALSO

L<Mojolicious>,
L<CPAN::Testers::Schema>,
L<http://github.com/cpan-testers/cpantesters-project>,
L<http://www.cpantesters.org>

=cut

use Mojo::Base 'Mojolicious';
use CPAN::Testers::Web::Base;
use File::Share qw( dist_dir dist_file );
use Log::Any::Adapter;
use File::Spec::Functions qw( catdir catfile );

=method schema

    my $schema = $c->schema;

Get the schema, a L<CPAN::Testers::Schema> object. By default, the
schema is connected from the local user's config. See
L<CPAN::Testers::Schema/connect_from_config> for details.

=cut

has schema => sub {
    require CPAN::Testers::Schema;
    return CPAN::Testers::Schema->connect_from_config;
};

=method startup

    # Called automatically by Mojolicious

This method starts up the application, loads any plugins, sets up routes,
and registers helpers.

=cut

sub startup ( $app ) {
    unshift @{ $app->renderer->paths },
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'templates' );
    unshift @{ $app->static->paths },
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'public' );

    $app->moniker( 'web' );
    # This application has no configuration yet
    $app->plugin( Config => {
        default => { }, # Allow living without config file
    } );

    $app->helper( schema => sub { shift->app->schema } );
    Log::Any::Adapter->set( 'MojoLog', logger => $app->log );
}

1;

