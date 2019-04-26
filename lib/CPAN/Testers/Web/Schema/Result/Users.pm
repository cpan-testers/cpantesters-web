package CPAN::Testers::Web::Schema::Result::Users;
our $VERSION = '0.001';
# ABSTRACT: Website user information

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use CPAN::Testers::Web::Base 'Result';
use Digest::SHA qw( sha1_base64 );
table 'users';

=attr id

The ID of the row. Auto-generated.

=cut

primary_column 'id', {
    data_type         => 'int',
    extra             => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable       => 0,
};

=attr github_login

The Github login of the user.

=cut

column 'github_login', {
    data_type   => 'varchar',
    is_nullable => 0,
};
unique_constraint github_login => [qw( github_login )];

=attr pause_id

The PAUSE ID of the user, whether we've authenticated it or not.
To only get an authenticated PAUSE ID, use L</valid_pause_id>.

=cut

column 'pause_id', {
    data_type   => 'varchar',
    is_nullable => 1,
};

=attr pause_token

The token we sent out to authenticate the user's PAUSE account.  When
they have correctly authenticated, this will be set to C<undef>.  See
L</check_pause_token> to authenticate tokens, and
L</generate_pause_token> to create new tokens..

=cut

column 'pause_token', {
    data_type   => 'varchar',
    is_nullable => 1,
};

=method check_pause_token

    my $success = $row->check_pause_token( $token );

Check if the given token is correct. If it is, clear the token: The user
has now authenticated their PAUSE ID. Returns a boolean indicating if
the authentication succeeded or not.

=cut

sub check_pause_token( $self, $token ) {
    if ( $self->pause_id && $token eq $self->pause_token ) {
        $self->pause_token( undef );
        $self->update;
        return 1;
    }
    return undef;
}

=method generate_pause_token

    my $token = $row->generate_pause_token();

This generates and returns a new token to authenticate the user's PAUSE
ID. If no PAUSE ID exists for this user, will throw an exception.

=cut

sub generate_pause_token( $self, $pause_id=undef ) {
    if ( $pause_id ) {
        $self->pause_id( $pause_id );
    }
    else {
        $pause_id = $self->pause_id
            || die sprintf "No PAUSE ID set for user %s", $self->github_login;
    }
    my $token = sha1_base64( $pause_id . time() . $$ . rand( 1_000_000 ) );
    $self->pause_token( $token );
    $self->update;
    return $token;
}

=method validate_pause_token

    my $success = $row->validate_pause_token( $check_token );

Validate the given token against the record. Returns true if successful.

=cut

sub validate_pause_token( $self, $token ) {
    if ( $self->pause_token eq $token ) {
        $self->update({ pause_token => undef });
        return 1;
    }
    return undef;
}

=method valid_pause_id

    my $pause_id = $row->valid_pause_id;

Get this user's PAUSE ID, but only if they've validated it.

=cut

sub valid_pause_id( $self ) {
    if ( $self->pause_token ) {
        # Pause ID is not authenticated yes
        return undef;
    }
    return $self->pause_id;
}

1;
