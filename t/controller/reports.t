
=head1 DESCRIPTION

This tests the report viewing actions

=head1 SEE ALSO

L<CPAN::Testers::Web::Controller::Reports>

=cut

use CPAN::Testers::Web::Base 'Test';
use CPAN::Testers::Web::Schema;
use CPAN::Testers::Schema;
use CPAN::Testers::Web;

# Schema
my $web_schema = CPAN::Testers::Web::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$web_schema->deploy;

my $perl_schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$perl_schema->deploy;

# Test data
populate_schema( $perl_schema );

my $t = Test::Mojo->new( 'CPAN::Testers::Web' );
$t->app->helper( 'schema.web' => sub { $web_schema } );
$t->app->helper( 'schema.perl5' => sub { $perl_schema } );

$t->get_ok( '/' )->status_is( 200 )
  ->element_exists( '#recent-uploads', 'recent uploads table exists' )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(1) a',
      qr{^\s*My-Other\s*$},
      'latest dist is correct',
  )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(2) a',
      qr{^\s*PREACTION\s*$},
      'dist author is correct',
  )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(3)',
      qr{^\s*2016-11-19 03:08:20\s*$},
      'released is correct',
  )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(4)',
      qr{^\s*1\s*$},
      'total is correct',
  )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(5)',
      qr{^\s*1\s*$},
      'pass is correct',
  )
  ->text_like(
      '#recent-uploads tbody tr:first-child td:nth-child(6)',
      qr{^\s*0\s*$},
      'fail is correct',
  )
  ;

done_testing;

sub populate_schema( $schema ) {
    my %default = (
        oncpan => 1,
        perlmat => 1,
        patched => 1,
    );

    my %stats_default = (
        tester => 'doug@example.com (Doug Bell)',
        platform => 'darwin-2level',
        perl => '5.22.0',
        osname => 'darwin',
        osvers => '10.8.0',
        type => 2,
    );

    my %data = (
        PerlVersion => [
            {
                version => '5.22.0',
            },
        ],

        Upload => [
            {
                uploadid => 1,
                type => 'cpan',
                author => 'PREACTION',
                dist => 'My-Dist',
                version => '1.001',
                filename => 'My-Dist-1.001.tar.gz',
                released => 1479524600,
            },
            {
                uploadid => 2,
                type => 'cpan',
                author => 'POSTACTION',
                dist => 'My-Dist',
                version => '1.002',
                filename => 'My-Dist-1.002.tar.gz',
                released => 1479524700,
            },
            {
                uploadid => 3,
                type => 'cpan',
                author => 'PREACTION',
                dist => 'My-Other',
                version => '1.000',
                filename => 'My-Other-1.000.tar.gz',
                released => 1479524800,
            },
            {
                uploadid => 4,
                type => 'cpan',
                author => 'PREACTION',
                dist => 'My-Other',
                version => '1.001',
                filename => 'My-Other-1.001.tar.gz',
                released => 1479524900,
            },
        ],

        Stats => [
            {
                %stats_default,
                # Upload info
                dist => 'My-Dist',
                version => '1.001',
                uploadid => 1,
                # Stats info
                id => 1,
                guid => '00000000-0000-0000-0000-000000000001',
                state => 'pass',
                postdate => '201608',
                fulldate => '201608120401',
            },
            {
                %stats_default,
                # Upload info
                dist => 'My-Dist',
                version => '1.001',
                uploadid => 1,
                # Stats info
                id => 2,
                guid => '00000000-0000-0000-0000-000000000002',
                state => 'fail',
                postdate => '201608',
                fulldate => '201608120000',
            },
            {
                %stats_default,
                # Upload info
                dist => 'My-Dist',
                version => '1.002',
                uploadid => 2,
                # Stats info
                id => 3,
                guid => '00000000-0000-0000-0000-000000000003',
                state => 'fail',
                postdate => '201608',
                fulldate => '201608200000',
            },
            {
                %stats_default,
                # Upload info
                dist => 'My-Other',
                version => '1.000',
                uploadid => 3,
                # Stats info
                id => 4,
                guid => '00000000-0000-0000-0000-000000000004',
                state => 'pass',
                postdate => '201609',
                fulldate => '201609180000',
            },
            {
                %stats_default,
                # Upload info
                dist => 'My-Other',
                version => '1.001',
                uploadid => 4,
                # Stats info
                id => 5,
                guid => '00000000-0000-0000-0000-000000000005',
                state => 'pass',
                postdate => '201609',
                fulldate => '201609180100',
            },
        ],

        Release => [
            {
                %default,
                distmat => 1,
                # Upload info
                dist => 'My-Dist',
                version => '1.001',
                uploadid => 1,
                # Stats
                id => 2,
                guid => '00000000-0000-0000-0000-000000000002',
                # Release summary
                pass => 1,
                fail => 1,
                na => 0,
                unknown => 0,
            },
            {
                %default,
                distmat => 1,
                # Upload info
                dist => 'My-Dist',
                version => '1.002',
                uploadid => 2,
                # Stats
                id => 3,
                guid => '00000000-0000-0000-0000-000000000003',
                # Release summary
                pass => 1,
                fail => 0,
                na => 0,
                unknown => 0,
            },
            {
                %default,
                distmat => 1,
                # Upload info
                dist => 'My-Other',
                version => '1.000',
                uploadid => 3,
                # Stats
                id => 4,
                guid => '00000000-0000-0000-0000-000000000004',
                # Release summary
                pass => 1,
                fail => 0,
                na => 0,
                unknown => 0,
            },
            {
                %default,
                distmat => 2,
                # Upload info
                dist => 'My-Other',
                version => '1.001',
                uploadid => 4,
                # Stats
                id => 5,
                guid => '00000000-0000-0000-0000-000000000005',
                # Release summary
                pass => 1,
                fail => 0,
                na => 0,
                unknown => 0,
            },
            {
                %default,
                distmat => 1,
                perlmat => 2,
                # Upload info
                dist => 'My-Dist',
                version => '1.001',
                uploadid => 1,
                # Stats
                id => 2,
                guid => '00000000-0000-0000-0000-000000000002',
                # Release summary
                pass => 0,
                fail => 0,
                na => 0,
                unknown => 1,
            },
        ],
    );
    $schema->populate( $_, $data{ $_ } ) for qw( PerlVersion Upload Stats Release );
}


