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

	$c->render('dist-search', {
			
	});
}

=method recent_uploads

List the recent uploads to CPAN and the reports received so far.

=cut

sub recent_uploads( $c ) {
    # XXX: Disabling for now as too slow
    # my $recent_uploads = $c->schema->perl5->resultset('Upload')->recent(20);
    # my $rs = $c->schema->perl5->resultset('Release')->search({
    #         -or => [
    #             map +{ 'me.dist' => $_->dist, 'me.version' => $_->version }, $recent_uploads->all
    #         ]
    #     },
    #     {
    #         join => 'upload',
    #         order_by => { -desc => 'upload.released' },
    #         group_by => [qw( me.dist me.version )],
    #         select => [qw( dist version uploadid upload.author upload.released), \('COUNT(*)', 'SUM(pass)', 'SUM(fail)', 'SUM(na)', 'SUM(unknown)') ],
    #         as => [qw( dist version uploadid author released total pass fail na unknown )],
    #     }
    # );

    $c->render( 'reports/recent_uploads',
        items => []
        # items => [
        #     map +{
        #         $_->get_inflated_columns,
        #         released => $_->upload->released->datetime( ' ' ),
        #     },
        #     $rs->all
        # ],
    );
}


1;
