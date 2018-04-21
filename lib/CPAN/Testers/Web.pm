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
    $app->log( Mojo::Log->new ); # Log only to STDERR
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

    if ( $app->config->{Minion} ) {
        $app->plugin( 'Minion', $app->config->{Minion} );
        my $under = $app->routes->under('/minion' =>sub {
            my $c = shift;
            return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
            $c->res->headers->www_authenticate('Basic');
            $c->render(text => 'Authentication required!', status => 401);
            return undef;
        });
        $app->plugin('Minion::Admin' => {route => $under});
    }

    # Compile JS and CSS assets
    $app->plugin( 'AssetPack', { pipes => [qw( Css JavaScript )] } );
    $app->asset->store->paths([
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'node_modules' ),
        @{ $app->static->paths },
    ]);

    $app->asset->process(
        'prereq.js' => qw(
            /jquery/dist/jquery.js
            /bootstrap/dist/js/bootstrap.js
        ),
    );

    $app->asset->process(
        'prereq.css' => qw(
            /bootstrap/dist/css/bootstrap.css
            /bootstrap/dist/css/bootstrap-theme.css
            /font-awesome/css/font-awesome.css
            /css/cpantesters.css
        ),
    );

    # Add static paths to find fonts
    push @{ $app->static->paths },
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'node_modules', 'font-awesome' );

    # Set defaults
    $app->defaults(
        layout => 'default',
    );

    # Add routes
    my $r = $app->routes;

    $r->get( '/user/dist/:dist' )
      ->name( 'user.dist-settings' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'user/dist/settings' );
    } );

    $r->get( '/dist/:dist/#version', { version => 'latest' } )
      ->name( 'dist' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'dist' );
    } );

    $r->get( '/dist' )
      ->name( 'dist-search' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'dist-search' );
    } );

    $r->get( '/author/:author' )
      ->name( 'author' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'author' );
    } );

    $r->get( '/author' )
      ->name( 'author-search' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'author-search' );
    } );

    $r->get( '/tester/:tester/:machine' )
      ->name( 'tester-machine' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'tester-machine' );
    } );

    $r->get( '/tester/:tester' )
      ->name( 'tester' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'tester' );
    } );

    $r->get( '/tester' )
      ->name( 'tester-search' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'tester-search' );
    } );

    $r->get( '/report/:guid' )
      ->name( 'report' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'report' );
    } );

    $r->get( '/legacy/cpan/report/:id' )
      ->name( 'legacy-view-report' )
      ->to( 'legacy#view_report' );

    # Add a special route to show the main landing page, which is
    # replaced by a different page in beta mode
    if ( $app->mode eq 'beta' ) {
        $r->get( '/web' )
          ->name( 'web' )
          ->to( cb => sub {
            my ( $c ) = @_;
            $c->render( 'index' );
        } );
    }

    $r->get( '/*tmpl', { tmpl => 'index' } )
      ->name( 'web' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( $c->stash( 'tmpl' ), variant => $app->mode );
    } );

}

1;

