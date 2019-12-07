package CPAN::Testers::Web::Controller::Reports;
our $VERSION = '0.001';
# ABSTRACT: Endpoints for viewing and managing reports

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use CPAN::Testers::Web::Base;

=method recent_uploads

List the recent uploads to CPAN and the reports received so far.

=cut

sub recent_uploads( $c ) {
    my $rs = $c->schema->perl5->resultset( "Release" )
        ->total_by_release
        # XXX: The rest of this statement would be better as
        # a "recent()" method on the Release ResultSet class
        ->as_subselect_rs
        ->related_resultset( 'upload' )->recent( 20 )
        ->search( undef, {
            # Add these back as they get lost by the ->related_resultset
            '+select' => [qw( me.pass me.fail me.na me.unknown me.total )],
            '+as' => [qw( pass fail na unknown total )],
        } );

    $c->render( 'reports/recent_uploads',
        items => [
            map +{
                $_->get_inflated_columns,
                released => $_->released->datetime( ' ' ),
            },
            $rs->all
        ],
    );
}

1;
