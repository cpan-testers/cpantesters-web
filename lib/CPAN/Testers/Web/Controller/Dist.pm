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
        dist => $c->req->json->{dist}
    });

    $c->render( json => {
        ok => $rs->count()
    } );
}

1;
