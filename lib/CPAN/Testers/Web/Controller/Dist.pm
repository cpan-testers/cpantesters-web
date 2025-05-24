package CPAN::Testers::Web::Controller::Dist;
our $VERSION = '0.001';
# ABSTRACT: Endpoints for viewing and managing distributions

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use CPAN::Testers::Web::Base;
use CPAN::Testers::Web::Controller::Legacy;

=method search

Landing page for /dist

Lists modules configured in the config

=cut

sub search ( $c ) {
	$c->render('dist/search',
		dists => $c->config->{dist_modules}
	);
}

=method view

Render Dist view

=cut

sub view ( $c ) {
    my $version = $c->param('version') || 'latest';
    $version =~ s/\.(html|rss)$//;
    $c->render('dist/view',
        dist => $c->param('dist'),
        version => $version
    );
}

=method recent

Expects a list of dists and will return the most recent for each.

=cut

sub recent ( $c ) {
    my $join = $c->schema->perl5->resultset('Release')->search({
        dist => { -in => $c->req->json->{dists} }
    }, {
        group_by => [qw( me.dist )],
        select => [qw/dist/, \('MAX(version)')],
        as => [qw/dist version/]
    });

    if (!$join->count) {
        return $c->render( json => { dists => [] } );
    }

    my $rs = $c->schema->perl5->resultset('Release')->search({
        -or => [
                map +{ 'me.dist' => $_->dist, 'me.version' => $_->version }, $join->all()
        ],
    }, {
        join => 'upload'
    });

    $c->render( json => {
        dists => [
            map +{
                $_->get_inflated_columns,
                released => $_->upload->released->datetime( ' ' ),
            },
            $rs->all
        ]

    } );
}

=method valid

validate that a dist exists

=cut

sub valid ( $c ) {
    my $rs = $c->schema->perl5->resultset('Release')->search({
        dist =>  { like => $c->req->json->{dist} . '%' }
    }, {
        distinct => 1,
        select => ['dist'],
        as => ['dist'],
        rows => 50
    });

    $c->render( json => {
        dists => [
            map { $_->dist }
            $rs->all
        ]
    } );
}

=method releases

Returns all releases for the dist

=cut

sub releases ( $c ) {
    my $rs = $c->schema->perl5->resultset('Release')->search({
        'me.dist' => $c->param('dist')
    }, {
        join => 'upload',
        order_by => 'upload.released'
    });

    $c->render( json => {
        dists => [
            map +{
                $_->get_inflated_columns,
                released => $_->upload->released->datetime( ' ' ),
            },
            $rs->all
        ]
    } );
}

=method reports

Returns all reports for the specific dist version

=cut

sub reports ( $c ) {
    my $rs = $c->schema->perl5->resultset('Stats')->search({
        'me.dist' => $c->param('dist'),
        'me.version' => $c->param('version'),
    }, {
        order_by => { -desc => 'fulldate' }
    });

    $c->render( json => {
        reports => [
            map +{
                $_->get_inflated_columns,
            },
            $rs->all
        ]
    } );
}

1;
