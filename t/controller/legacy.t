
=head1 DESCRIPTION

This test ensures that the legacy APIs maintain their backwards-compatibility
via the L<CPAN::Testers::Web::Controller::Legacy> controller.

=cut

use CPAN::Testers::Web::Base 'Test';
use CPAN::Testers::Schema;
use CPAN::Testers::Web;
use JSON::MaybeXS qw( decode_json encode_json );
use DateTime;

# Schema
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$schema->deploy;

# Metabase
my $dbh = $schema->storage->dbh;
$dbh->do(<<ENDSQL);
    ATTACH DATABASE ':memory:' AS metabase
ENDSQL
$dbh->do(<<ENDSQL);
    CREATE TABLE `metabase`.`metabase` (
        `guid` CHAR(36) NOT NULL PRIMARY KEY,
        `id` INT(10) NOT NULL,
        `updated` VARCHAR(32) DEFAULT NULL,
        `report` BINARY NOT NULL,
        `fact` BINARY DEFAULT NULL
    )
ENDSQL

# Test data
my $upload = $schema->resultset( 'Upload' )->create({
    uploadid => 169497,
    type => 'cpan',
    author => 'YUKI',
    dist => 'Sorauta-SVN-AutoCommit',
    version => 0.02,
    filename => 'Sorauta-SVN-AutoCommit-0.02.tar.gz',
    released => 1327657454,
});
my $upload2 = $schema->resultset( 'Upload' )->create({
    uploadid => 169496,
    type => 'cpan',
    author => 'YUKI',
    dist => 'Sorauta-SVN-AutoCommit',
    version => 0.01,
    filename => 'Sorauta-SVN-AutoCommit-0.01.tar.gz',
    released => 1327657453,
});
my $metabase_user = $schema->resultset( 'MetabaseUser' )->create({
    resource => 'metabase:user:11111111-1111-1111-1111-111111111111',
    email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
    fullname => 'Andreas Koenig',
});
my $other_metabase_user = $schema->resultset( 'MetabaseUser' )->create({
    resource => 'metabase:user:322078bc-2aae-11df-837a-5e0a49663a4f',
    email => 'bingos@example.com',
    fullname => 'Chris Williams',
});

my @reports;
push @reports,
    $schema->resultset('TestReport')->create({
      id => 'd0ab4d36-3343-11e7-b830-917e22bfee97',
      created => DateTime->new(
          year => 2020, month => 1, day => 1,
          hour => 0, minute => 0, second => 0,
      ),
      report => {
          id => 'd0ab4d36-3343-11e7-b830-917e22bfee97',
          reporter => {
              name  => 'Andreas J. Koenig',
              email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
          },
          environment => {
              system => {
                  osname => 'linux',
                  osversion => '4.8.0-2-amd64',
              },
              language => {
                  name => 'Perl 5',
                  version => '5.22.2',
                  archname => 'x86_64-linux',
              },
          },
          distribution => {
              name => 'Sorauta-SVN-AutoCommit',
              version => '0.02',
          },
          result => {
              grade => 'FAIL',
              output => {
                  uncategorized => 'Test report',
              },
          },
      },
  }),
  $schema->resultset('TestReport')->create({
      id => 'a1e92b97-da53-473e-bf2d-0866b4c2c20c',
      created => DateTime->new(
          year => 2020, month => 1, day => 2,
          hour => 0, minute => 0, second => 0,
      ),
      report => {
          id => 'a1e92b97-da53-473e-bf2d-0866b4c2c20c',
          reporter => {
              name  => 'Andreas J. Koenig',
              email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
          },
          environment => {
              system => {
                  osname => 'linux',
                  osversion => '4.8.0-2-amd64',
              },
              language => {
                  name => 'Perl 5',
                  version => '5.22.2',
                  archname => 'x86_64-linux',
              },
          },
          distribution => {
              name => 'Sorauta-SVN-AutoCommit',
              version => '0.01',
          },
          result => {
              grade => 'PASS',
              output => {
                  uncategorized => 'Test report',
              },
          },
      },
  }),
  ;

my @stats;
push @stats, $schema->resultset( 'Stats' )->insert_test_report( $_ ) for @reports;

# Metabase Fact
my $metabase_report = {
    id => 'cfa81824-3343-11e7-b830-917e22bfee97',
    reporter => {
        name  => 'Andreas J. Koenig',
        email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
    },
    environment => {
        system => {
            osname => 'linux',
            osversion => '4.8.0-2-amd64',
        },
        language => {
            name => 'Perl 5',
            version => '5.20.1',
            archname => 'x86_64-linux-thread-multi',
        },
    },
    distribution => {
        name => 'Sorauta-SVN-AutoCommit',
        version => '0.02',
        author => 'YUKI',
    },
    result => {
        grade => 'FAIL',
        output => {
            uncategorized => 'Test report',
        },
    },
};
my $metabase_row = _build_metabase_fact( $metabase_report );
$schema->storage->dbh->do(
    'REPLACE INTO metabase (guid,id,updated,report,fact) VALUES (?,?,?,?,?)',
    {},
    $metabase_row->@{qw< guid id updated report fact >},
);

# Older Metabase row
my $older_metabase_report = {
    guid => '21652418-8a32-11e3-8f3c-fc23d5af1b80',
    id => 123123,
    updated => '2014-01-31T04:42:46Z',
    report => encode_json( {
          "CPAN::Testers::Fact::LegacyReport" => {
            "content" => encode_json( {
                "osversion" => "8.1-1-686",
                "textreport" => "This distribution has been tested as part of the CPAN Testers\nproject, supporting the Perl programming language.  See\nhttp://wiki.cpantesters.org/ for more information or email\nquestions to cpan-testers-discuss\@perl.org\n\n\n--\n\nDear MIKER,\n\nThis is a computer-generated error report created automatically by\nCPANPLUS, version 0.9144. Testers personal comments may appear\nat the end of this report.\n\n\nThank you for uploading your work to CPAN.  Congratulations!\nAll tests were successful.\n\nTEST RESULTS:\n\nBelow is the error stack from stage 'make test':\n\nPERL_DL_NONLAZY=1 /home/cpan/pit/thr/perl-5.18.2/bin/perl \"-MExtUtils::Command::MM\" \"-MTest::Harness\" \"-e\" \"undef *Test::Harness::Switches; test_harness(0, 'blib/lib', 'blib/arch')\" t/*.t\nt/password.t .. ok\nt/pw_get.t .... ok\nAll tests successful.\nFiles=2, Tests=31,  1 wallclock secs ( 0.00 usr +  0.02 sys =  0.02 CPU)\nResult: PASS\n\n\nPREREQUISITES:\n\nHere is a list of prerequisites you specified and versions we\nmanaged to load:\n\n\t  Module Name                        Have     Want\n\t  ExtUtils::MakeMaker                6.86        0\n\nPerl module toolchain versions installed:\n\tModule Name                        Have\n\tCPANPLUS                         0.9144\n\tCPANPLUS::Dist::Build              0.76\n\tCwd                                3.40\n\tExtUtils::CBuilder             0.280212\n\tExtUtils::Command                  1.17\n\tExtUtils::Install                  1.59\n\tExtUtils::MakeMaker                6.86\n\tExtUtils::Manifest                 1.63\n\tExtUtils::ParseXS                  3.22\n\tFile::Spec                         3.40\n\tModule::Build                    0.4204\n\tPod::Parser                        1.60\n\tPod::Simple                        3.28\n\tTest::Harness                      3.30\n\tTest::More                     1.001002\n\tversion                          0.9907\n\n******************************** NOTE ********************************\nThe comments above are created mechanically, possibly without manual\nchecking by the sender.  As there are many people performing automatic\ntests on each upload to CPAN, it is likely that you will receive\nidentical messages about the same problem.\n\nIf you believe that the message is mistaken, please reply to the first\none with correction and/or additional informations, and do not take\nit personally.  We appreciate your patience. :)\n**********************************************************************\n\nAdditional comments:\n\n\nThis report was machine-generated by CPANPLUS::Dist::YACSmoke 0.90.\nPowered by minismokebox version 0.58\n\n------------------------------\nENVIRONMENT AND OTHER CONTEXT\n------------------------------\n\nEnvironment variables:\n\n    AUTOMATED_TESTING = 1\n    LANG = en_GB.UTF-8\n    LANGUAGE = en_GB:en\n    NONINTERACTIVE_TESTING = 1\n    PATH = /usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games\n    PERL5LIB = :/home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/lib:/home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/arch\n    PERL5_CPANPLUS_IS_RUNNING = 50369\n    PERL5_CPANPLUS_IS_VERSION = 0.9144\n    PERL5_MINISMOKEBOX = 0.58\n    PERL5_YACSMOKE_BASE = /home/cpan/pit/thr/conf/perl-5.18.2\n    PERL_EXTUTILS_AUTOINSTALL = --defaultdeps\n    PERL_MM_USE_DEFAULT = 1\n    SHELL = /bin/bash\n    TERM = screen\n\nPerl special variables (and OS-specific diagnostics, for MSWin32):\n\n    Perl: $^X = /home/cpan/pit/thr/perl-5.18.2/bin/perl\n    UID:  $<  = 1001\n    EUID: $>  = 1001\n    GID:  $(  = 1001 1001\n    EGID: $)  = 1001 1001\n\n\n-------------------------------\n\n\n--\n\nSummary of my perl5 (revision 5 version 18 subversion 2) configuration:\n   \n  Platform:\n    osname=gnukfreebsd, osvers=8.1-1-686, archname=i686-gnukfreebsd\n    uname='gnukfreebsd kaiser 8.1-1-686 #0 sun feb 17 17:09:24 utc 2013 i686 i386 intel(r) pentium(r) cpu g840 @ 2.80ghz gnukfreebsd '\n    config_args='-des -Dprefix=/home/cpan/pit/thr/perl-5.18.2'\n    hint=recommended, useposix=true, d_sigaction=define\n    useithreads=undef, usemultiplicity=undef\n    useperlio=define, d_sfio=undef, uselargefiles=define, usesocks=undef\n    use64bitint=undef, use64bitall=undef, uselongdouble=undef\n    usemymalloc=n, bincompat5005=undef\n  Compiler:\n    cc='cc', ccflags ='-fno-strict-aliasing -pipe -fstack-protector -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64',\n    optimize='-O2',\n    cppflags='-fno-strict-aliasing -pipe -fstack-protector -I/usr/local/include'\n    ccversion='', gccversion='4.4.5', gccosandvers=''\n    intsize=4, longsize=4, ptrsize=4, doublesize=8, byteorder=1234\n    d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=12\n    ivtype='long', ivsize=4, nvtype='double', nvsize=8, Off_t='off_t', lseeksize=8\n    alignbytes=4, prototype=define\n  Linker and Libraries:\n    ld='cc', ldflags =' -fstack-protector -L/usr/local/lib'\n    libpth=/usr/local/lib /lib /usr/lib\n    libs=-lnsl -lgdbm -ldb -ldl -lm -lcrypt -lutil -lc -lgdbm_compat\n    perllibs=-lnsl -ldl -lm -lcrypt -lutil -lc\n    libc=, so=so, useshrplib=false, libperl=libperl.a\n    gnulibc_version='2.11.3'\n  Dynamic Linking:\n    dlsrc=dl_dlopen.xs, dlext=so, d_dlsymun=undef, ccdlflags='-Wl,-E'\n    cccdlflags='-fpic', lddlflags='-shared -O2 -L/usr/local/lib -fstack-protector'\n\n\nCharacteristics of this binary (from libperl): \n  Compile-time options: HAS_TIMES PERLIO_LAYERS PERL_DONT_CREATE_GVSV\n                        PERL_HASH_FUNC_ONE_AT_A_TIME_HARD PERL_MALLOC_WRAP\n                        PERL_PRESERVE_IVUV PERL_SAWAMPERSAND USE_LARGE_FILES\n                        USE_LOCALE USE_LOCALE_COLLATE USE_LOCALE_CTYPE\n                        USE_LOCALE_NUMERIC USE_PERLIO USE_PERL_ATOF\n  Built under gnukfreebsd\n  Compiled at Jan 29 2014 11:54:02\n  %ENV:\n    PERL5LIB=\":/home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/lib:/home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/arch\"\n    PERL5_CPANPLUS_IS_RUNNING=\"50369\"\n    PERL5_CPANPLUS_IS_VERSION=\"0.9144\"\n    PERL5_MINISMOKEBOX=\"0.58\"\n    PERL5_YACSMOKE_BASE=\"/home/cpan/pit/thr/conf/perl-5.18.2\"\n    PERL_EXTUTILS_AUTOINSTALL=\"--defaultdeps\"\n    PERL_MM_USE_DEFAULT=\"1\"\n  @INC:\n    /home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/lib\n    /home/cpan/pit/thr/conf/perl-5.18.2/.cpanplus/5.18.2/build/Data-Password-Manager-0.05/blib/arch\n    /home/cpan/pit/thr/perl-5.18.2/lib/site_perl/5.18.2/i686-gnukfreebsd\n    /home/cpan/pit/thr/perl-5.18.2/lib/site_perl/5.18.2\n    /home/cpan/pit/thr/perl-5.18.2/lib/5.18.2/i686-gnukfreebsd\n    /home/cpan/pit/thr/perl-5.18.2/lib/5.18.2\n    .",
                "archname" => "i686-gnukfreebsd",
                "perl_version" => "v5.18.2",
                "osname" => "gnukfreebsd",
                "grade" => "pass",
            } ),
            "metadata" => {
              "core" => {
                "update_time" => "2014-01-31T04:42:46Z",
                "creator" => "metabase:user:322078bc-2aae-11df-837a-5e0a49663a4f",
                "valid" => 1,
                "resource" => "cpan:///distfile/MIKER/Data-Password-Manager-0.05.tar.gz",
                "guid" => "21653494-8a32-11e3-8f3c-fc23d5af1b80",
                "creation_time" => "2014-01-31T04:42:46Z",
                "type" => "CPAN-Testers-Fact-LegacyReport",
                "schema_version" => 1
              }
            }
          },
          "CPAN::Testers::Fact::TestSummary" => {
            "content" => encode_json( {
                "osversion" => "8.1-1-686",
                "archname" => "i686-gnukfreebsd",
                "perl_version" => "v5.18.2",
                "osname" => "gnukfreebsd",
                "grade" => "pass"
            } ),
            "metadata" => {
              "core" => {
                "update_time" => "2014-01-31T04:42:46Z",
                "creator" => "metabase:user:322078bc-2aae-11df-837a-5e0a49663a4f",
                "valid" => 1,
                "resource" => "cpan:///distfile/MIKER/Data-Password-Manager-0.05.tar.gz",
                "guid" => "21653e44-8a32-11e3-8f3c-fc23d5af1b80",
                "creation_time" => "2014-01-31T04:42:46Z",
                "type" => "CPAN-Testers-Fact-TestSummary",
                "schema_version" => 1
              }
            }
          }
        }
    ),
};
$schema->storage->dbh->do(
    'REPLACE INTO metabase (guid,id,updated,report,fact) VALUES (?,?,?,?,NULL)',
    {},
    $older_metabase_report->@{qw< guid id updated report >},
);

my $t = Test::Mojo->new(
    CPAN::Testers::Web->new(
        tester_schema => $schema,
    )
);

subtest 'view-report.cgi' => sub {
    subtest 'json report' => sub {
        $t->get_ok( '/legacy/cpan/report/d0ab4d36-3343-11e7-b830-917e22bfee97' )
            ->status_is( 200 )
            ->content_like( qr{Test report}, 'content contains full text of report' )
            ->element_exists(
                'a[href=http://metacpan.org/release/YUKI/Sorauta-SVN-AutoCommit-0.02]',
                'dist link to metacpan is correct',
            )
            ->or( sub { diag shift->tx->res->dom->at( 'h1 a' ) } )
            ;

        subtest '... as json' => sub {
            $t->get_ok( '/legacy/cpan/report/d0ab4d36-3343-11e7-b830-917e22bfee97?json=1' )
                ->status_is( 200 )
                ->json_is( '/success', 1 )
                ;
            my $json = $t->tx->res->json;
            my ( $report ) =
                map { $_->{content} }
                grep { $_->{metadata}{core}{type} eq 'CPAN-Testers-Fact-LegacyReport' }
                $json->{result}{content}->@*;
            is $report->{textreport}, 'Test report', 'text content is correct';
        };
    };

    subtest 'metabase report' => sub {
        subtest 'report with fact' => sub {
            $t->get_ok( '/legacy/cpan/report/cfa81824-3343-11e7-b830-917e22bfee97' )
                ->status_is( 200 )
                ->content_like( qr{Test report}, 'content contains full text of report' )
                ->element_exists(
                    'a[href=http://metacpan.org/release/YUKI/Sorauta-SVN-AutoCommit-0.02]',
                    'dist link to metacpan is correct',
                )
                ;
            subtest '... as json' => sub {
                $t->get_ok( '/legacy/cpan/report/cfa81824-3343-11e7-b830-917e22bfee97?json=1' )
                    ->status_is( 200 )
                    ->json_is( '/success', 1 )
                    ;
                my $json = $t->tx->res->json;
                my ( $report ) =
                    map { $_->{content} }
                    grep { $_->{metadata}{core}{type} eq 'CPAN-Testers-Fact-LegacyReport' }
                    $json->{result}{content}->@*;
                is $report->{textreport}, 'Test report', 'text content is correct';
            };
        };

        subtest 'report with report' => sub {
            $dbh->do(
                'UPDATE `metabase`.`metabase` SET fact=NULL where id=?',
                {},
                'cfa81824-3343-11e7-b830-917e22bfee97',
            );
            $t->get_ok( '/legacy/cpan/report/cfa81824-3343-11e7-b830-917e22bfee97' )
                ->status_is( 200 )
                ->content_like( qr{Test report}, 'content contains full text of report' )
                ->element_exists(
                    'a[href=http://metacpan.org/release/YUKI/Sorauta-SVN-AutoCommit-0.02]',
                    'dist link to metacpan is correct',
                )
                ;
            subtest '... as json' => sub {
                $t->get_ok( '/legacy/cpan/report/cfa81824-3343-11e7-b830-917e22bfee97?json=1' )
                    ->status_is( 200 )
                    ->json_is( '/success', 1 )
                    ;
                my $json = $t->tx->res->json;
                my ( $report ) =
                    map { $_->{content} }
                    grep { $_->{metadata}{core}{type} eq 'CPAN-Testers-Fact-LegacyReport' }
                    $json->{result}{content}->@*;
                is $report->{textreport}, 'Test report', 'text content is correct';
            };
        };

        subtest 'report with report (json)' => sub {
            $t->get_ok( '/legacy/cpan/report/21652418-8a32-11e3-8f3c-fc23d5af1b80' )
                ->status_is( 200 )
                ;
            subtest '... as json' => sub {
                $t->get_ok( '/legacy/cpan/report/21652418-8a32-11e3-8f3c-fc23d5af1b80?json=1' )
                    ->status_is( 200 )
                    ;
            };
        };

        subtest 'report not found (guid)' => sub {
            $t->get_ok( '/legacy/cpan/report/99999999-8a32-11e3-8f3c-fc23d5af1b80' )
                ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                ->text_is( h1 => 'Report not found' )
                ;
            $t->get_ok( '/legacy/cpan/report/99999999-8a32-11e3-8f3c-fc23d5af1b80?raw=1' )
                ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                ->element_exists_not( 'h1' )
                ->text_is( p => 'Sorry, but that report does not exist.' )
                ;
            subtest '... as json' => sub {
                $t->get_ok( '/legacy/cpan/report/99999999-8a32-11e3-8f3c-fc23d5af1b80?json=1' )
                    ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                    ->json_is( { success => 0 } )
                    ;
            };
        };


        subtest 'report not found (stat ID)' => sub {
            $t->get_ok( '/legacy/cpan/report/23872349' )
                ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                ->text_is( h1 => 'Report not found' )
                ;
            $t->get_ok( '/legacy/cpan/report/23872349?raw=1' )
                ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                ->element_exists_not( 'h1' )
                ->text_is( p => 'Sorry, but that report does not exist.' )
                ;
            subtest '... as json' => sub {
                $t->get_ok( '/legacy/cpan/report/23872349?json=1' )
                    ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                    ->json_is( { success => 0 } )
                    ;
            };
        };

        subtest 'by stats ID' => sub {
            $t->get_ok( '/legacy/cpan/report/' . $stats[0]->id . '?json=1' )
                ->status_is( 200 ) # CPAN::Testers::WWW::Reports::Query::Report expects 200 OK
                ->json_is( '/success', 1 )
                ->json_is( '/result/metadata/core/guid', $stats[0]->guid )
                ->or( sub { diag shift->tx->res->body } )
                ;
        };
    };

    subtest 'backcompat' => sub {
        subtest 'CPAN::Testers::WWW::Reports::Query::Report' => sub {
            pass q{No test because I can't test the Mojolicious app with WWW::Mechanize};
            return;
            # use CPAN::Testers::WWW::Reports::Query::Report;
            # my $api = CPAN::Testers::WWW::Reports::Query::Report->new(
            #     host => $t->ua->server->url . '/legacy',
            # );
            # my $report = $api->report( report => 'cfa81824-3343-11e7-b830-917e22bfee97' );
            # isa_ok $report, 'CPAN::Testers::Report', 'report is parsed correctly';
        };
    };
};

subtest 'distro feed' => sub {
    $t->get_ok( '/legacy/distro/S/Sorauta-SVN-AutoCommit.json' )->status_is( 200 )
      ->json_is( '/0/status', 'FAIL' )
      ->json_is( '/0/state', 'fail' )
      ->json_is( '/0/guid', 'd0ab4d36-3343-11e7-b830-917e22bfee97' )
      ->json_is( '/0/dist', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/0/distribution', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/0/version', '0.02' )
      ->json_is( '/0/distversion', 'Sorauta-SVN-AutoCommit-0.02' )
      ->json_is( '/0/type', 2 )
      ->json_is( '/0/osname', 'linux' )
      ->json_is( '/0/ostext', 'GNU/Linux' ) # %OSNAME map
      ->json_is( '/0/osvers', '4.8.0-2-amd64' )
      ->json_is( '/0/perl', '5.22.2' )
      ->json_is( '/0/platform', 'x86_64-linux' )
      ->json_is( '/0/csspatch', 'unp' )
      ->json_is( '/0/cssperl', 'rel' ) # or 'dev'
      ->json_is( '/0/postdate', '202001' )
      ->json_is( '/0/fulldate', '202001010000' )
      ->json_is( '/0/uploadid', '169497' )
      ->json_is( '/0/tester', '"Andreas J. Koenig" <andreas.koenig.gmwojprw@franz.ak.mind.de>' )
      ->json_is( '/0/id', $stats[0]->id )
      ->json_is( '/1/status', 'PASS' )
      ->json_is( '/1/state', 'pass' )
      ->json_is( '/1/guid', 'a1e92b97-da53-473e-bf2d-0866b4c2c20c' )
      ->json_is( '/1/dist', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/1/distribution', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/1/version', '0.01' )
      ->json_is( '/1/distversion', 'Sorauta-SVN-AutoCommit-0.01' )
      ->json_is( '/1/id', $stats[1]->id )
      ;
};

subtest 'author feed' => sub {
    $t->get_ok( '/legacy/author/Y/YUKI.json' )->status_is( 200 )
      ->json_is( '/0/status', 'FAIL' )
      ->json_is( '/0/state', 'fail' )
      ->json_is( '/0/guid', 'd0ab4d36-3343-11e7-b830-917e22bfee97' )
      ->json_is( '/0/dist', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/0/distribution', 'Sorauta-SVN-AutoCommit' )
      ->json_is( '/0/version', '0.02' )
      ->json_is( '/0/distversion', 'Sorauta-SVN-AutoCommit-0.02' )
      ->json_is( '/0/type', 2 )
      ->json_is( '/0/osname', 'linux' )
      ->json_is( '/0/ostext', 'GNU/Linux' ) # %OSNAME map
      ->json_is( '/0/osvers', '4.8.0-2-amd64' )
      ->json_is( '/0/perl', '5.22.2' )
      ->json_is( '/0/platform', 'x86_64-linux' )
      ->json_is( '/0/csspatch', 'unp' )
      ->json_is( '/0/cssperl', 'rel' ) # or 'dev'
      ->json_is( '/0/postdate', '202001' )
      ->json_is( '/0/fulldate', '202001010000' )
      ->json_is( '/0/uploadid', '169497' )
      ->json_is( '/0/tester', '"Andreas J. Koenig" <andreas.koenig.gmwojprw@franz.ak.mind.de>' )
      ->json_is( '/0/id', $stats[0]->id )
      ->json_hasnt( '/1', 'only latest dist version is returned' )
      ;
};

done_testing;

# Code copied from CPAN::Testers::Backend::ProcessReports
sub _build_metabase_fact( $report ) {
    my $distname = $report->{distribution}{name};
    my $distversion = $report->{distribution}{version};

    my $distfile = sprintf '%s/%s-%s.tar.gz', $report->{distribution}{author}, $distname, $distversion;

    my %report = (
        grade => $report->{result}{grade},
        osname => $report->{environment}{system}{osname},
        osversion => $report->{environment}{system}{osversion},
        archname => $report->{environment}{language}{archname},
        perl_version => $report->{environment}{language}{version},
        textreport => (
            $report->{result}{output}{uncategorized} ||
            join "\n\n", grep defined, $report->{result}{output}->@{qw( configure build test install )},
        ),
    );

    # These imports are here so they can be easily removed later
    use Metabase::User::Profile;
    my %creator = (
        full_name => $report->{reporter}{name},
        email_address => $report->{reporter}{email},
    );

    use CPAN::Testers::Report;
    my $metabase_report = CPAN::Testers::Report->open(
        resource => 'cpan:///distfile/' . $distfile,
        creator => 'metabase:user:11111111-1111-1111-1111-111111111111',
    );
    $metabase_report->add( 'CPAN::Testers::Fact::LegacyReport' => \%report);
    $metabase_report->add( 'CPAN::Testers::Fact::TestSummary' =>
        [$metabase_report->facts]->[0]->content_metadata()
    );
    $metabase_report->close();

    # Encode it to JSON
    my %facts;
    for my $fact ( $metabase_report->facts ) {
        my $name = ref $fact;
        $facts{ $name } = $fact->as_struct;
        $facts{ $name }{ content } = decode_json( $facts{ $name }{ content } );
    }

    # Serialize it to compress it using Data::FlexSerializer
    # "report" gets serialized with JSON
    use Data::FlexSerializer;
    my $json_zipper = Data::FlexSerializer->new(
        detect_compression  => 1,
        detect_json         => 1,
        output_format       => 'json'
    );
    my $report_zip = $json_zipper->serialize( \%facts );

    # "fact" gets serialized with Sereal
    my $sereal_zipper = Data::FlexSerializer->new(
        detect_compression  => 1,
        detect_sereal       => 1,
        output_format       => 'sereal'
    );
    my $fact_zip = $sereal_zipper->serialize( $metabase_report );

    return {
        guid => $report->{id},
        id => 1,
        updated => 1,
        report => $report_zip,
        fact => $fact_zip,
    };
}

