package CPAN::Testers::Web::Controller::Reports;
our $VERSION = '0.001';
# ABSTRACT: Endpoints for viewing and managing reports

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use CPAN::Testers::Web::Base;
use CPAN::Testers::Web::Controller::Legacy;

=method recent_uploads

List the recent uploads to CPAN and the reports received so far.

=cut

sub recent_uploads( $c ) {
    my $recent_uploads = $c->schema->perl5->resultset('Upload')->recent(20);
    my $rs = $c->schema->perl5->resultset('Release')->search({
            -or => [
                map +{ 'me.dist' => $_->dist, 'me.version' => $_->version }, $recent_uploads->all
            ]
        },
        {
            join => 'upload',
            order_by => { -desc => 'upload.released' },
            group_by => [qw( me.dist me.version )],
            select => [qw( dist version uploadid upload.author upload.released), \('COUNT(*)', 'SUM(pass)', 'SUM(fail)', 'SUM(na)', 'SUM(unknown)') ],
            as => [qw( dist version uploadid author released total pass fail na unknown )],
        }
    );

    $c->render( 'reports/recent_uploads',
        items => [
            map +{
                $_->get_inflated_columns,
                released => $_->upload->released->datetime( ' ' ),
            },
            $rs->all
        ],
    );
}

=method dist_reports

List the reports for a distribution / version.

=cut

sub dist_versions( $c ) {
    my $rows = $c->param('$limit') // 10;
    my $offset = $c->param('$offset') // 0;
    my $dist = $c->stash( 'dist' );
    my $rs = $c->schema->perl5->resultset( 'Release' )->by_dist($dist)
        ->search(
          undef,
          {
             join => 'upload',
                order_by => { -desc => 'upload.released' },
                rows => $rows,
                offset => $offset,
                group_by => [qw( dist version )],
                select => [qw( dist version ), \('SUM(pass)', 'SUM(fail)', 'SUM(na)', 'SUM(unknown)') ],
                as => [qw( dist version pass fail na unknown )],
            }
        );
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    return $c->render( json => [ $rs->all ] );
}

sub dist_reports( $c ) {
    my $dist = $c->stash( 'dist' );
    my $version = $c->stash( 'version' );
    my $is_latest = !$version || $version eq 'latest';

    my $format = $c->stash('format');
    $version =~ s/[.]$format$//;

    # Do filtering and options the same way as Yancy so that
    # moai/table's progressive enhancement works.

    my $rs = $c->schema->perl5->resultset( 'Release' )->by_dist( $dist )
        ->search(
            undef,
            {
                join => 'upload',
                order_by => { -desc => 'upload.released' },
                rows => 10,
                group_by => [qw( me.dist me.version )],
                select => [qw( dist version ), \('SUM(pass)', 'SUM(fail)', 'SUM(na)', 'SUM(unknown)') ],
                as => [qw( dist version pass fail na unknown )],
            }
        );
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my @releases = $rs->all;
    if ( $is_latest ) {
        $version = $releases[0]->{version};
    }

    my $reports = $c->schema->perl5->resultset( 'Stats' )
        ->search(
            {
                dist => $dist,
                version => $version,
            },
            {
                order_by => { -desc => 'fulldate' },
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
                osname => $_->osname,
                osvers => $_->osvers,
                dist => $_->dist,
                version => $_->version,
                report => $_,
                datetime => $_->datetime,
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

=method author

List the author's latest uploads to CPAN for each of their dists and the
reports received so far.

=cut

sub author( $c ) {
    if ( $c->accepts('', 'json', 'rss') ) {
        return $c->CPAN::Testers::Web::Controller::Legacy::author();
    }
    my $author_dists = $c->schema->perl5->resultset('Upload')->by_author($c->stash('author'))->latest_by_dist;
    my @all_dists = $author_dists->all;
    if ( !@all_dists ) {
    }
    my $rs = $c->schema->perl5->resultset('Release')->search({
            -or => [
                map +{ 'me.dist' => $_->dist, 'me.version' => $_->version }, @all_dists
            ]
        },
        {
            join => 'upload',
            order_by => { -desc => 'upload.released' },
            group_by => [qw( me.dist me.version )],
            select => [qw( dist version uploadid upload.author upload.released), \('COUNT(*)', 'SUM(pass)', 'SUM(fail)', 'SUM(na)', 'SUM(unknown)') ],
            as => [qw( dist version uploadid author released total pass fail na unknown )],
        }
    );

    $c->render( 'author',
        items => [
            map +{
                $_->get_inflated_columns,
                released => $_->upload->released->datetime( ' ' ),
            },
            $rs->all
        ],
    );
}

=method author_search

Search for authors.

=cut

sub author_search( $c ) {
    if ( my $search = $c->param('q') ) {
        if ( $search =~ m{\*} ) {
            $search =~ s{\*}{%}g;
        }
        else {
            $search .= '%';
        }

        my $authors = $c->schema->perl5->resultset('Upload')->search(
            {
                author => { -like => $search },
            },
            {
                select => [qw( author )],
                as => [qw( author )],
                distinct => 1,
            },
        );
        $c->stash( items => [ map +{ author => $_ }, $authors->get_column('author')->all ] );
    }
    $c->render( 'author-search' );
}

1;
