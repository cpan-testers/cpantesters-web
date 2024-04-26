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

=method dist_reports

List the reports for a distribution / version.

=cut

sub dist_reports( $c ) {
    my $dist = $c->stash( 'dist' );
    my $version = $c->stash( 'version' );
    my $is_latest = $version eq 'latest';
    my @releases = $c->schema->perl5->resultset( 'Release' )->by_dist( $dist )
        ->search(
            undef,
            {
                join => 'upload',
                order_by => { -desc => 'upload.released' },
            }
        )
        ->all;
    if ( $version eq 'latest' ) {
        $version = $releases[0]->version;
    }

    my $reports = $c->schema->perl5->resultset( 'Stats' )
        ->search(
            {
                dist => $dist,
                version => $version,
            },
        );

    $c->render(
        'reports/dist_reports',
        version => $version,
        is_latest => $is_latest,
        releases => \@releases,
        reports => [
            map +{
                guid => $_->guid,
                grade => $_->grade,
                lang_version => $_->lang_version,
                platform => $_->platform,
                tester_name => $_->tester_name,
            },
            $reports->all,
        ],
    );
}

=method report

View a single report

=cut

sub report( $c ) {
    my $id = $c->stash( 'guid' );
    if ( my $report = $c->schema->perl5->resultset( 'TestReport' )->find( $id ) ) {
      $c->render(
          'reports/report',
          report => $report,
      );
      return;
    }
    # We didn't find a report, so look for a metabase report?
    $c->redirect_to('/cpan/report/' . $id)
}

1;
