
=head1 DESCRIPTION

This test ensures that when the web application is run in C<beta> mode,
that it shows the appropriate main page content which introduces the
beta site and the projects inside which are pre-release for the main
site.

=head1 SEE ALSO

L<Mojolicious template variants|http://mojolicious.org/perldoc/Mojolicious/Guides/Rendering#Template-variants>

=cut

use Mojo::Base '-strict';
use Test::More;
use Test::Mojo;
use CPAN::Testers::Web::Schema;
use CPAN::Testers::Schema;

local $ENV{MOJO_MODE} = "beta";
my $t = Test::Mojo->new( 'CPAN::Testers::Web' );

# Fake Schemas
my $web_schema = CPAN::Testers::Web::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$web_schema->deploy;
my $perl_schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$perl_schema->deploy;
$t->app->helper( 'schema.web' => sub { $web_schema } );
$t->app->helper( 'schema.perl5' => sub { $perl_schema } );

subtest 'main landing page in beta is correct' => sub {
    $t->get_ok( '/' )
      ->status_is( 200 )
      ->text_is( 'h1' => 'CPAN Testers Beta', 'beta landing h1 is correct' )
      ->text_is( 'h2' => 'Active Projects', 'beta landing h2 is correct' )
      ->text_is( '.navbar-brand a *' => 'CPAN Testers Beta', 'layout is correct' );
};

subtest 'main webapp landing page is moved' => sub {

    $t->get_ok( '/web' )
      ->status_is( 200 )
      ->text_is( 'title', 'Recent - CPAN Testers', 'main webapp title is correct' );

    subtest 'links to main webapp landing page work' => sub {
        $t->get_ok( '/web' );
        is $t->tx->res->dom->at( '.navbar-brand a' )->attr( 'href' ), '/web',
            'URL for beta web app is correct on main page';
        $t->get_ok( '/author/PREACTION' );
        is $t->tx->res->dom->at( '.navbar-brand a' )->attr( 'href' ), '/web',
            'URL for beta web app is correct on Author page';
    };
};

done_testing;
