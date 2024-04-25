package CPAN::Testers::Web::Controller::User;
our $VERSION = '0.001';
# ABSTRACT: Endpoints for users to manage their account and settings

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use CPAN::Testers::Web::Base;
use Email::Stuffer;

=method pause

    $app->routes->get( '/user/pause' )->to( 'user#pause' );

Show the user's PAUSE ID and give them a form to change it.

=cut

sub pause( $c ) {
    $c->render( 'user/pause' );
}

=method update_pause

    $app->routes->post( '/user/pause' )->to( 'user#update_pause' );

Update the user's PAUSE ID and send out a validation e-mail.

=cut

sub update_pause( $c ) {
    # Validate CSRF
    my $v = $c->validation;
    return $c->render(text => 'Bad CSRF token!', status => 403)
        if $v->csrf_protect->has_error('csrf_token');

    $v->required( 'pause_id' )->size(1, undef);
    if ( $v->has_error ) {
        return $c->render( 'user/pause', status => 400 );
    }

    my $token = $c->current_user->generate_pause_token( $v->param( 'pause_id' ) );
    $c->_send_pause_token_email( $c->current_user );

    $c->flash( message => 'Authentication token sent to %s@cpan.org.' );
    return $c->redirect_to( 'user.pause' );
}

sub _send_pause_token_email( $c, $user ) {
    my %stash = (
        pause_id => $user->pause_id,
        pause_token => $user->pause_token,
    );
    my $email = Email::Stuffer->new;
    $email->from( 'admin@cpantesters.org' )
        ->to( sprintf '%s@cpan.org', $user->pause_id )
        ->subject( 'Validate your PAUSE ID on CPAN Testers' )
        ->html_body( $c->render_to_string( 'user/pause_token_mail', %stash ) )
        ->text_body( $c->render_to_string( 'user/pause_token_mail', format => 'txt', %stash ) )
        ->send;
}

=method validate_pause

    $app->routes->any( '/user/pause/token' )->to( 'user#validate_pause' );

Verify the PAUSE validation token. If invalid, will prompt the user
to re-send the token.

=cut

sub validate_pause( $c ) {
    # This endpoint cannot have CSRF protection because we are sending
    # an e-mail with a URL to click. That e-mail cannot have CSRF
    # protection. That and the worst that can happen is someone forges
    # a verification...
    if ( my $token = $c->param( 'pause_token' ) ) {
        if ( $c->current_user->validate_pause_token( $token ) ) {
            $c->flash( message => 'You have been validated' );
        }
        else {
            $c->flash( error => 'This is not the correct token' );
        }
    }
    return $c->redirect_to( 'user.pause' );
}

1;
