
=head1 DESCRIPTION

This tests the user account actions like validating a PAUSE ID.

=head1 SEE ALSO

L<CPAN::Testers::Web::Controller::User>

=cut

use CPAN::Testers::Web::Base 'Test';
use CPAN::Testers::Web::Schema;
use CPAN::Testers::Web;
use Mojo::Util qw( url_escape );

# Schema
my $schema = CPAN::Testers::Web::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$schema->deploy;

# Test data
my $user = $schema->resultset( 'Users' )->create({
    github_login => 'preaction',
});

my $t = Test::Mojo->new( 'CPAN::Testers::Web' );
$t->app->routes->post( '/TEST/login' => sub( $c ) {
    $c->session( user_id => $user->id );
    $c->rendered( 204 );
} );
$t->app->helper( 'schema.web' => sub { $schema } );

subtest 'unauthorized errors' => sub {
    $t->get_ok( '/user/pause' )->status_is( 401 );
    $t->post_ok( '/user/pause' )->status_is( 401 );
    $t->get_ok( '/user/pause/token' )->status_is( 401 );
    $t->post_ok( '/user/pause/token' )->status_is( 401 );
};

$t->post_ok( '/TEST/login' );

my %csrf;
subtest 'see PAUSE form' => sub {
    $t->get_ok( '/user/pause' )->status_is( 200 );
    $csrf{ csrf_token } = $t->tx->res->dom->at( 'input[name=csrf_token]' )->attr( 'value' );
};

subtest 'update PAUSE ID' => sub {

    subtest 'CSRF protection' => sub {
        $t->post_ok( '/user/pause', form => { csrf_token => 'FAKE TOKEN' } )
          ->status_is( 403 )
          ->content_like( qr{Bad CSRF token}, 'error message on page' )
          ;
    };

    subtest 'must pass in some value' => sub {
        $t->post_ok( '/user/pause', form => { %csrf, pause_id => '' } )->status_is( 400 )
          ->content_like( qr{You must give a PAUSE ID}, 'error message on page' )
          ->element_exists( 'form input[name=pause_id]', 'form is shown' )
          ->element_exists(
              'form input[name=pause_id].field-with-error', 'field has error class'
          )
          ;
    };

    my %form = (
        %csrf,
        pause_id => 'PREACTION',
    );
    $t->post_ok( '/user/pause', { Host => 'cpantesters.org' }, form => \%form )
      ->status_is( 302 );
    $t->get_ok( $t->tx->res->headers->location, { Host => 'cpantesters.org' }, 'follow redirect' )
      ->status_is( 200 );

    $user->discard_changes;
    my $pause_token = $user->pause_token;

    subtest 'redirect to form to input token' => sub {
        $t->element_exists( 'form input[name=pause_token]', 'token input exists' );
    };

    subtest 'e-mail was sent' => sub {
        my @deliveries = Email::Sender::Simple->default_transport->deliveries;
        is scalar @deliveries, 1, 'one email was sent';

        my $envelope = $deliveries[0]{envelope};
        is $envelope->{from}, 'admin@cpantesters.org', 'from address correct';
        is_deeply $envelope->{to}, [ 'PREACTION@cpan.org' ], 'to addresses correct';

        my $email = $deliveries[0]{email};
        my @parts = $email->object->subparts;
        #diag explain \@parts;

        # Text part
        my ( $text_part ) = grep { $_->content_type =~ qr{^text/plain} } @parts;
        like $text_part->body, qr{PREACTION}, 'pause ID is in text part';
        like $text_part->body, qr{\Q$pause_token}, 'pause token is in text part';
        like $text_part->body, qr{http://(?:\w+[.])?cpantesters\.org/user/pause},
            'url to enter pause token is in text part';

        # HTML part
        my ( $html_part ) = grep { $_->content_type =~ qr{^text/html} } @parts;
        my $dom = Mojo::DOM->new( $html_part->body );
        like $dom->all_text, qr{PREACTION}, 'pause ID is in text of html part';
        like $dom->all_text, qr{\Q$pause_token}, 'pause token is in text of html part';
        ok $dom->at( 'a[href$=/user/pause]' ),
            'url to enter pause token is in html part'
                or diag explain [ $dom->find( 'a' )->map( 'to_string' ) ];
        ok $dom->at( sprintf qq{a[href\$="/user/pause/token?pause_token=%s"]}, url_escape( $pause_token ) ),
            'url to click to verify pause token is in html part'
                or diag explain [ $dom->find( 'a' )->map( 'to_string' ) ];
    };

    subtest 'verify token' => sub {
        subtest '... by GET' => sub {
            $user->update({
                pause_token => $pause_token,
            });
            $t->get_ok( '/user/pause/token?pause_token=' . url_escape( $pause_token ) )
              ->status_is( 302 )
              ->header_is( Location => '/user/pause', 'redirect is correct' );
            $user->discard_changes;
            ok $user->valid_pause_id, 'user was validated';
            ok !$user->pause_token, 'token was removed';
        };
        subtest '... by POST' => sub {
            $user->update({
                pause_token => $pause_token,
            });
            $t->post_ok( '/user/pause/token', form => { pause_token => $pause_token } )
              ->status_is( 302 )
              ->header_is( Location => '/user/pause', 'redirect is correct' );
            $user->discard_changes;
            ok $user->valid_pause_id, 'user was validated';
            ok !$user->pause_token, 'token was removed';
        };
    };

    subtest 'updating PAUSE ID without verifying changes ID and token' => sub {
        $user->update({
            pause_token => $pause_token,
        });
        my %form = (
            %csrf,
            pause_id => 'ANDK',
        );
        $t->post_ok( '/user/pause', { Host => 'cpantesters.org' }, form => \%form )
          ->status_is( 302 );

        $user->discard_changes;
        isnt $user->pause_token, $pause_token, 'token was changed';

        my @deliveries = Email::Sender::Simple->default_transport->deliveries;
        is scalar @deliveries, 2, 'another email was sent';
    };
};

done_testing;
