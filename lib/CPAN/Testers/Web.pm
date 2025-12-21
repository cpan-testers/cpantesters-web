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
BEGIN { $ENV{IO_ASYNC_LOOP} = "Mojo"; };
use OpenTelemetry::SDK;
use CPAN::Testers::Web::Base;
use File::Share qw( dist_dir dist_file );
use Log::Any::Adapter;
use File::Spec::Functions qw( catdir catfile );
use Log::Any::Adapter 'Multiplex' =>
  # Set up Log::Any to log to OpenTelemetry and Stderr so we can still
  # see the local logs.
  adapters => {
    'OpenTelemetry' => [],
    'Stderr' => [],
  };
use Log::Any qw($LOG);

has tester_schema =>;

=method startup

    # Called automatically by Mojolicious

This method starts up the application, loads any plugins, sets up routes,
and registers helpers.

=cut

sub startup ( $app ) {
    # Remove Mojo::Log from STDERR so that we don't double-log
    $app->log(Mojo::Log->new(handle => undef));
    # Forward Mojo::Log logs to the Log::Any logger, so that from there
    # they will be forwarded to OpenTelemetry.
    # Modules should prefer to log with Log::Any because it supports
    # structured logging.
    $app->log->on( message => sub ( $, $level, @lines ) {
      $LOG->$level(@lines);
    });
    #$app->plugin('OpenTelemetry');

    unshift @{ $app->renderer->paths },
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'templates' );
    unshift @{ $app->static->paths },
        catdir( dist_dir( 'CPAN-Testers-Web' ), 'public' );
    unshift @{ $app->commands->namespaces }, 'CPAN::Testers::Web::Command';

    $app->moniker( 'web' );
    $app->plugin( Config => {
        default => {
            api_host => 'api.cpantesters.org',
        },
    } );

    $app->plugin( 'Moai', [ 'Bootstrap4' ] );

    # XXX We need a better way to handle schema objects for other
    # languages, which will be CPAN::Testers::Schema object connected to
    # different databases
    $app->helper( 'schema.perl5' => sub {
        require CPAN::Testers::Schema;
        state $schema = $app->tester_schema;
        if (!$schema) {
          if (my $connect_args = $app->config->{db}) {
            $schema = CPAN::Testers::Schema->connect( $connect_args->@{qw( dsn username password args )} );
          }
          else {
            $schema = CPAN::Testers::Schema->connect_from_config;
          }
        }
        return $schema;
    } );
    $app->helper( 'schema.web' => sub {
        require CPAN::Testers::Web::Schema;
        state $schema;
        if (!$schema) {
          if (my $connect_args = $app->config->{web_db}) {
            $schema = CPAN::Testers::Web::Schema->connect( $connect_args->@{qw( dsn username password args )} );
          }
          else {
            $schema = CPAN::Testers::Web::Schema->connect_from_config;
          }
        }
        return $schema;
    } );

    if ( $app->config->{Minion} ) {
        $app->plugin( 'Minion', $app->config->{Minion} );
        my $under = $app->routes->under('/minion' =>sub {
            my $c = shift;
            #return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
            $c->res->headers->www_authenticate('Basic');
            $c->render(text => 'Authentication required!', status => 401);
            return undef;
        });
        $app->plugin('Minion::Admin' => {route => $under});
    }

    if ( $app->config->{Yancy} ) {
        my $yancy_auth = $app->routes->under('/yancy' =>sub {
            my $c = shift;
            #return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
            $c->res->headers->www_authenticate('Basic');
            $c->render(text => 'Authentication required!', status => 401);
            return undef;
        });
        $app->plugin( Yancy => {
            %{ $app->config->{Yancy} },
            route => $yancy_auth,
            read_schema => 1,
        });
    }

    $app->plugin( 'OAuth2', {
        github => {
            key => $ENV{OAUTH2_GITHUB_CLIENT} || 'c6ec2955ddc771fd906d',
            secret => $ENV{OAUTH2_GITHUB_SECRET},
        },
    } );
    my $ua = Mojo::UserAgent->new;
    $app->routes->get( "/yancy/auth/oauth2/github" => sub {
        my ( $c ) = @_;
        my $get_token_args = {
            redirect_uri => $c->url_for("yancy.auth.oauth2.github")->userinfo( undef )->to_abs,
        };
        $c->oauth2->get_token_p( github => $get_token_args )->then( sub {
            return unless my $provider_res = shift;
            ; use Data::Dumper;
            ; $c->app->log->info( Dumper $provider_res );
            $c->session( token => $provider_res->{access_token} );
            my $from = delete $c->session->{ 'yancy.auth.from' } || '/';

            # With this token I can get data from the Github API
            my %headers = (
                # Use v3 API explicitly
                Accept => 'application/vnd.github.v3+json',
                Authorization => sprintf( 'token %s', $provider_res->{access_token} ),
            );
            $ua->get_p( 'https://api.github.com/user', \%headers )->then( sub {
                my ( $tx ) = @_;
                my $login = $tx->res->json->{login};
                my $user = $c->schema->web->resultset( 'Users' )->create({
                    github_login => $login,
                });
                $c->session( user_id => $user->id );
                $c->redirect_to( $from );
            } )
            ->catch( sub {
                my $error = shift;
                $c->app->log->error( 'Error getting Github user: ' . $error );
                $c->render( "yancy/auth/oauth2", provider => 'github', error => $error );
            } );
        } )
        ->catch( sub {
            my $error = shift;
            $c->app->log->error( 'Error getting OAuth2 token: ' . $error );
            $c->render( "yancy/auth/oauth2", provider => 'github', error => $error );
        } );
    } )->name( 'yancy.auth.oauth2.github' );

    $app->helper( current_user => sub {
        my ( $c ) = @_;
        my $user_id = $c->session( 'user_id' ) || return;
        my $user = $c->schema->web->resultset( 'Users' )->find( $user_id );
        if ( !$user ) {
            delete $c->session->{ user_id };
            return;
        }
        return $user;
    } );

    my $auth = $app->routes->under( sub {
        my ( $c ) = @_;
        if ( !$c->current_user ) {
            $c->session( 'yancy.auth.from' => $c->url_for() );
            $c->render( 'yancy/auth', status => 401 );
            return undef;
        }
        return 1;
    } );

    $auth->get( '/user/pause' )->to( 'user#pause' )->name( 'user.pause' );
    $auth->post( '/user/pause' )->to( 'user#update_pause' )->name( 'user.update_pause' );
    $auth->any( '/user/pause/token' )->to( 'user#validate_pause' )->name( 'user.validate_pause' );

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

    $r->get( '/dist/:dist/#version', [ format => [qw( html rss )] ], { format => 'html', version => 'latest' } )
      ->name( 'reports.dist' )
      ->to( 'reports#dist_reports' );

    $r->get( '/release/:dist', [ format => [qw( json )] ], { format => 'json' } )
      ->name( 'release.dist' )
      ->to( 'reports#dist_versions' );

    $r->get( '/dist' )
      ->name( 'dist-search' )
      ->to( cb => sub {
        my ( $c ) = @_;
        $c->render( 'dist-search' );
    } );

    $r->get( '/author/:author', [ format => [qw( html rss json)] ] )
      ->name( 'reports.author' )
      ->to( 'reports#author', format => 'html' );

    $r->get( '/author' )
      ->name( 'author-search' )
      ->to( 'reports#author_search' );

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

    $r->get( '/report/:id' )
      # Using the legacy one because it has fallbacks instead of a redirect, which puts more strain on the server. Need to consolidate into one
      # that satisfies all necessary user/API clients.
      ->to( 'legacy#view_report' )
      ->name( 'reports.report' )
      ;

    $r->get( '/cpan/report/:id' )
      ->name( 'legacy-view-report' )
      ->to( 'legacy#view_report' );

    $r->get( '/distro/:letter/:dist', [format => ['json']] )
      ->name( 'legacy-distro-feed' )
      ->to( 'legacy#distro' );

    $r->get( '/author/:letter/:author', [format => ['json']] )
      ->name( 'legacy-author-feed' )
      ->to( 'legacy#author' );

    # TODO:
    # /author/<name>-nopass.rss

    ### These routes are for the CPAN Testers Matrix
    $r->get('/show/:dist', [format => [qw( html json yaml rss )]])
      ->name('show-dist')
      ->to('legacy#show_dist', format => 'html');

    ### This route handles the CPAN::Testers::WWW::Reports::Query::Reports API module
    $r->get('/cgi-bin/reports-metadata.cgi')
      ->name('reports-metadata')
      ->to('legacy#reports_metadata');

    # Add a special route to show the main landing page, which is
    # replaced by a different page in beta mode
    if ( $app->mode eq 'beta' ) {
        $r->get( '/web' )
          ->name( 'reports.recent_uploads' )
          ->to( 'reports#recent_uploads' )
          ;
    }
    else {
        $r->get( '/' )
          ->name( 'reports.recent_uploads' )
          ->to( 'reports#recent_uploads' )
          ;
    }
}

1;

