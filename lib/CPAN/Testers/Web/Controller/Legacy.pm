package CPAN::Testers::Web::Controller::Legacy;
our $VERSION = '0.001';
# ABSTRACT: Replacements for legacy pages and APIs during transition

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use CPAN::Testers::Web::Base;
use JSON::MaybeXS qw( decode_json );
use Mojo::Util qw( html_unescape );

=method view_report

View a single report.

=cut

my %OSNAME = (
    aix => 'AIX',
    bsdos => 'BSD/OS',
    cygwin => "Windows (Cygwin)",
    darwin => "Mac OS X",
    dec_osf => "Tru64",
    dragonfly => "Dragonfly BSD",
    freebsd => "FreeBSD",
    gnu => "GNU Hurd",
    haiku => "Haiku",
    hpux => "HP-UX",
    irix => "IRIX",
    linux => "GNU/Linux",
    macos => "Mac OS classic",
    midnightbsd => "MidnightBSD",
    mirbsd => "MirOS BSD",
    mswin32 => "Windows (Win32)",
    netbsd => "NetBSD",
    openbsd => "OpenBSD",
    os2 => "OS/2",
    os390 => "OS390/zOS",
    gnukfreebsd => "Debian GNU/kFreeBSD",
    sco => "SCO",
    solaris => "SunOS/Solaris",
    vms => "VMS",
    beos => "BeOS",
    interix => "Interix",
    nto => "QNX Neutrino",
    minix => "MINIX",
    bitrig => "BITRIG",
    Mac => "MAC",
);

sub view_report( $c ) {
    my $schema = $c->schema->perl5;
    my $id = $c->stash( 'id' );
    my $report;

    # First try to find it in the new test reports database
    $c->app->log->debug( 'Got ID: ' . $id );
    if ( $id =~ /^\d+$/ ) {
        my $stat = $schema->resultset( 'Stats' )->find( $id );
        if ( !$stat ) {
            $c->app->log->error( 'Stat row not found: ' . $id );
            if ( $c->param( 'json' ) ) {
                return $c->render( json => { success => 0 } );
            }
            return $c->render( 'legacy/report-not-found' );
        }
        $id = $stat->guid;
        $c->app->log->debug( 'Translated to GUID: ' . $id );
    }

    if ( my $row = $schema->resultset( 'TestReport' )->find( $id ) ) {
        $report = $c->_new_report_to_metabase_json( $row );
    }
    elsif (
        $row = $schema->storage->dbh->selectrow_hashref(
            'SELECT * FROM metabase.metabase WHERE guid=?',
            {},
            $id,
        )
    ) {
        # deparse the Metabase row
        $report = $c->_deserialize_metabase_report( $row );
    }

    if ( $c->param( 'json' ) ) {
        return $c->render(
            json => {
                success => $report ? 1 : 0,
                ( $report ? ( result => $report ) : () ),
            },
        );
    }

    if ( !$report ) {
        $c->app->log->error( 'Report not found: ' . $id );
        return $c->render( 'legacy/report-not-found' );
    }

    my $user = $schema->resultset( 'MetabaseUser' )->search(
        { resource => $report->{metadata}{core}{creator} },
    )->first;

    return $c->render( 'legacy/view-report',
        report => $report,
        user => $user,
        osname => \%OSNAME,
    );
}

=method distro

This returns a JSON feed of all the distribution reports to be used by
external services like analysis.cpantesters.org (via
L<CPAN::Testers::ParseReport>).

=cut

sub distro( $c ) {
    my $dist = $c->stash->{dist};
    my $rs = $c->schema->perl5->resultset( 'Stats' )->search({
        dist => $dist,
    });
    return $c->render( json => _rs_to_json($rs) );
}

sub _rs_to_json( $rs ) {
    my @records;
    while ( my $row = $rs->next ) {
        push @records, {
            status => uc $row->state,
            state => $row->state,
            guid => $row->guid,
            dist => $row->dist,
            distribution => $row->dist,
            version => $row->version,
            distversion => join( '-', $row->dist, $row->version ),
            type => $row->type,
            osname => $row->osname,
            osvers => $row->osvers,
            ostext => $OSNAME{ $row->osname },
            perl => $row->perl,
            platform => $row->platform,
            uploadid => $row->uploadid,
            tester => html_unescape( $row->tester ),
            id => $row->id,
            postdate => $row->postdate,
            fulldate => $row->fulldate,
            csspatch => ( $row->perl =~ /\b(RC\d+|patch)\b/ ? 'pat' : 'unp' ),
            cssperl => ( $row->perl =~ /^5.(7|9|[1-9][13579])/ ? 'dev' : 'rel' ),
        };
    }
    return \@records;
}

=method author

This returns a JSON feed of all the reports for the latest version of
all dists from a given author to be used by external services like
analysis.cpantesters.org (via L<CPAN::Testers::ParseReport>).

=cut

sub author( $c ) {
    my $author = $c->stash->{author};
    my $rs = $c->schema->perl5->resultset( 'Upload' )
      ->by_author($author)->latest_by_dist
      ->search_related('report_stats');
    return $c->render( json => _rs_to_json($rs) );
}

sub _deserialize_metabase_report( $c, $row ) {
    use Data::FlexSerializer;
    use CPAN::Testers::Report;
    use Metabase::Fact;
    use Metabase::Resource;
    use Metabase::Resource::cpan::distfile;
    use Metabase::Resource::metabase::user;
    use CPAN::Testers::Fact::LegacyReport;
    use CPAN::Testers::Fact::TestSummary;
    my $report;
    if ( $row->{fact} ) {
        state $sereal_zipper = Data::FlexSerializer->new(
            detect_compression  => 1,
            detect_sereal       => 1,
            detect_json         => 1,
        );
        $row->{ fact } = $sereal_zipper->deserialize( $row->{fact} );
        $report = $row->{fact}->as_struct;
        for my $content ( @{ decode_json delete $report->{content} } ) {
            $content->{content} = decode_json $content->{content};
            push $report->{content}->@*, $content;
        }
    }
    else {
        state $json_zipper = Data::FlexSerializer->new(
            detect_compression  => 1,
            detect_json         => 1,
            detect_sereal       => 1,
        );
        $row->{ report } = $json_zipper->deserialize( $row->{report} );
        $report = $row->{report};
        if ( $report->{content} ) {
            $report->{content} = [ values $report->{content}->%* ];
        }
        else {
            my $src = $report;
            $report = {
                metadata => {
                    core => {
                        guid => $row->{guid},
                        type => 'CPAN-Testers-Report',
                        (
                            map {; $_ => $src->{'CPAN::Testers::Fact::TestSummary'}{metadata}{core}{ $_ } }
                            qw( resource schema_version creation_time valid creator update_time )
                        )
                    },
                },
            };
            for my $content ( values $src->%* ) {
                $content->{content} = decode_json $content->{content};
                push $report->{content}->@*, $content;
            }
        }
    }

    return $report;
}

sub _new_report_to_metabase_json( $c, $row ) {
    my $schema = $c->schema->perl5;
    my $created = $row->created->iso8601 . 'Z';
    my $id = $row->id;
    my $user = $schema->resultset( 'MetabaseUser' )->search({
        email => $row->report->{reporter}{email},
    })->first;
    my $report = $row->report;

    my $distname = $report->{distribution}{name};
    my $distversion = $report->{distribution}{version};
    my $upload_row = $schema->resultset( 'Upload' )->search({
        dist => $distname,
        version => $distversion,
    })->first;
    my $author = $upload_row->author;
    my $distfile = sprintf '%s/%s-%s.tar.gz', $author, $distname, $distversion;

    my $metabase_report = {
        metadata => {
            core => {
                creation_time => $created,
                update_time => $created,
                valid => 1,
                type => "CPAN-Testers-Report",
                resource => $distfile,
                schema_version => 1,
                guid => $id,
                creator => $user->resource,
            },
        },
        content => [
            {
                metadata => {
                    core => {
                        guid => $id,
                        creator => $user->resource,
                        type => "CPAN-Testers-Fact-LegacyReport",
                        valid => 1,
                        schema_version => 1,
                        resource => $distfile,
                        update_time => $created,
                        creation_time => $created,
                    },
                },
                content => {
                    grade => $report->{result}{grade},
                    osname => $report->{environment}{system}{osname},
                    osversion => $report->{environment}{system}{osversion},
                    archname => $report->{environment}{language}{archname},
                    perl_version => $report->{environment}{language}{version},
                    textreport => (
                        $report->{result}{output}{uncategorized} ||
                        join "\n\n", grep defined, $report->{result}{output}->@{qw( configure build test install )},
                    ),
                },
            },
            {
                metadata => {
                    core => {
                        guid => $id,
                        creator => $user->resource,
                        valid => 1,
                        type => "CPAN-Testers-Fact-TestSummary",
                        resource => $distfile,
                        schema_version => 1,
                        update_time => $created,
                        creation_time => $created,
                    },
                },
                content => {
                    grade => $report->{result}{grade},
                    osname => $report->{environment}{system}{osname},
                    osversion => $report->{environment}{system}{osversion},
                    archname => $report->{environment}{language}{archname},
                    perl_version => $report->{environment}{language}{version},
                },
            },
        ],
    };

    return $metabase_report;
}

1;
__END__
{
  "success": "1",
  "result": {
    "metadata": {
      "core": {
        "creation_time": "2018-04-17T04:10:57Z",
        "update_time": "2018-04-17T04:10:57Z",
        "valid": 1,
        "type": "CPAN-Testers-Report",
        "resource": "cpan:///distfile/PREACTION/Yancy-1.004.tar.gz",
        "schema_version": 1,
        "guid": "54acbbe0-41f5-11e8-a7cf-a78da6ade2d7",
        "creator": "metabase:user:9c36dc84-a30f-11e0-a9fc-0a18abbd4f2f"
      }
    },
    "content": [
      {
        "metadata": {
          "core": {
            "guid": "54b1de90-41f5-11e8-a7cf-a78da6ade2d7",
            "creator": "metabase:user:9c36dc84-a30f-11e0-a9fc-0a18abbd4f2f",
            "type": "CPAN-Testers-Fact-LegacyReport",
            "valid": 1,
            "schema_version": 1,
            "resource": "cpan:///distfile/PREACTION/Yancy-1.004.tar.gz",
            "update_time": "2018-04-17T04:10:57Z",
            "creation_time": "2018-04-17T04:10:57Z"
          }
        },
        "content": {
          "grade": "pass",
          "osname": "openbsd",
          "textreport": "This distribution has been tested as part of the CPAN Testers\nproject, supporting the Perl programming language.  See\nhttp://wiki.cpantesters.org/ for more information or email\nquestions to cpan-testers-discuss@perl.org\n\n\n--\nDear Doug Bell,\n\nThis is a computer-generated report for Yancy-1.004\non perl 5.24.3, created by CPAN-Reporter-1.2018.\n\nThank you for uploading your work to CPAN.  Congratulations!\nAll tests were successful.\n\nSections of this report:\n\n    * Tester comments\n    * Program output\n    * Prerequisites\n    * Environment and other context\n\n------------------------------\nTESTER COMMENTS\n------------------------------\n\nAdditional comments from tester:\n\nthis report is from an automated smoke testing program\nand was not reviewed by a human for accuracy\n\n------------------------------\nPROGRAM OUTPUT\n------------------------------\n\nOutput from '/usr/bin/make test':\n\nSkip blib/lib/auto/share/dist/Yancy/run_backend_tests.pl (unchanged)\nSkip blib/lib/auto/share/dist/Yancy/update_resources.sh (unchanged)\nPERL_DL_NONLAZY=1 \"/home/goku/perl5/perlbrew/perls/perl-5.24.3/bin/perl\" \"-MExtUtils::Command::MM\" \"-MTest::Harness\" \"-e\" \"undef *Test::Harness::Switches; test_harness(0, 'blib/lib', 'blib/arch')\" t/*.t t/backend/*.t t/controller/*.t t/examples/*.t t/plugin/auth/*.t\nt/00-compile.t ............... ok\n# \n# Versions for all modules listed in MYMETA.json (including optional ones):\n# \n# === Configure Requires ===\n# \n#     Module                  Want Have\n#     ----------------------- ---- ----\n#     ExtUtils::MakeMaker      any 7.34\n#     File::ShareDir::Install 0.06 0.11\n# \n# === Build Requires ===\n# \n#     Module              Want Have\n#     ------------------- ---- ----\n#     ExtUtils::MakeMaker  any 7.34\n# \n# === Test Requires ===\n# \n#     Module                  Want     Have\n#     ------------------- -------- --------\n#     ExtUtils::MakeMaker      any     7.34\n#     File::Spec               any     3.74\n#     IO::Handle               any     1.35\n#     IPC::Open3               any     1.20\n#     Test::More          1.001005 1.302135\n# \n# === Test Recommends ===\n# \n#     Module         Want     Have\n#     ---------- -------- --------\n#     CPAN::Meta 2.120900 2.150010\n# \n# === Runtime Requires ===\n# \n#     Module                       Want Have\n#     ---------------------------- ---- ----\n#     Digest                        any 1.17\n#     Exporter                      any 5.72\n#     File::Spec::Functions         any 3.74\n#     FindBin                       any 1.51\n#     JSON::Validator              2.05 2.06\n#     Mojolicious                  7.15 7.75\n#     Mojolicious::Plugin::OpenAPI 1.25 1.26\n#     Scalar::Util                  any 1.50\n#     Sys::Hostname                 any 1.20\n#     Text::Balanced                any 2.03\n# \nt/00-report-prereqs.t ........ ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/api.t ...................... ok\nt/backend/dbic.t ............. ok\nt/backend/mysql.t ............ skipped: Mojo::mysql >= 1.0 required for this test\nt/backend/pg.t ............... skipped: Mojo::Pg >= 3.0 required for this test\nt/backend/sqlite.t ........... ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/controller/multi_tenant.t .. ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/controller/yancy.t ......... ok\nt/examples/todo-app.t ........ skipped: Set TEST_YANCY_EXAMPLES to run these tests\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/filter.t ................... ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\n[Tue Apr 17 01:10:42 2018] [error] Error validating item with ID \"1\" in collection \"people\": Missing property. (/name)\n[Tue Apr 17 01:10:42 2018] [error] Error validating new item in collection \"people\": Missing property. (/name)\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/helpers.t .................. ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/plugin/auth/basic.t ........ ok\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nPlaceholder quoting with \"(placeholder)\" is DEPRECATED in favor of \"<placeholder>\" at /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/Mojolicious/Routes/Route.pm line 80.\nt/standalone.t ............... ok\nAll tests successful.\nFiles=14, Tests=48, 19 wallclock secs ( 0.06 usr  0.17 sys + 12.87 cusr  4.07 csys = 17.17 CPU)\nResult: PASS\n\n------------------------------\nPREREQUISITES\n------------------------------\n\nPrerequisite modules loaded:\n\nrequires:\n\n    Module                       Need     Have    \n    ---------------------------- -------- --------\n    Digest                       0        1.17    \n    Exporter                     0        5.72    \n    File::Spec::Functions        0        3.74    \n    FindBin                      0        1.51    \n    JSON::Validator              2.05     2.06    \n    Mojolicious                  7.15     7.75    \n    Mojolicious::Plugin::OpenAPI 1.25     1.26    \n    perl                         5.010    5.024003\n    Scalar::Util                 0        1.50    \n    Sys::Hostname                0        1.20    \n    Text::Balanced               0        2.03    \n\nbuild_requires:\n\n    Module                       Need     Have    \n    ---------------------------- -------- --------\n    ExtUtils::MakeMaker          0        7.34    \n    File::Spec                   0        3.74    \n    IO::Handle                   0        1.35    \n    IPC::Open3                   0        1.20    \n    Test::More                   1.001005 1.302135\n\nconfigure_requires:\n\n    Module                       Need     Have    \n    ---------------------------- -------- --------\n    ExtUtils::MakeMaker          0        7.34    \n    File::ShareDir::Install      0.06     0.11    \n\nopt_build_requires:\n\n    Module                       Need     Have    \n    ---------------------------- -------- --------\n    CPAN::Meta                   2.120900 2.150010\n\n\n------------------------------\nENVIRONMENT AND OTHER CONTEXT\n------------------------------\n\nEnvironment variables:\n\n    AUTOMATED_TESTING = 1\n    DBD_MYSQL_TESTDB = test\n    DBD_MYSQL_TESTHOST = localhost\n    DBD_MYSQL_TESTPASSWORD = \n    DBD_MYSQL_TESTPORT = 3306\n    DBD_MYSQL_TESTUSER = goku\n    EXTENDED_TESTING = 1\n    PATH = /home/goku/perl5/perlbrew/bin:/home/goku/perl5/perlbrew/perls/perl-5.24.3/bin:/home/goku/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin\n    PERL5LIB = \n    PERL5OPT = \n    PERL5_CPANPLUS_IS_RUNNING = 33187\n    PERL5_CPAN_IS_RUNNING = 33187\n    PERL5_CPAN_IS_RUNNING_IN_RECURSION = 13046,33187\n    PERLBREW_HOME = /home/goku/.perlbrew\n    PERLBREW_MANPATH = /home/goku/perl5/perlbrew/perls/perl-5.24.3/man\n    PERLBREW_PATH = /home/goku/perl5/perlbrew/bin:/home/goku/perl5/perlbrew/perls/perl-5.24.3/bin\n    PERLBREW_PERL = perl-5.24.3\n    PERLBREW_ROOT = /home/goku/perl5/perlbrew\n    PERLBREW_SHELLRC_VERSION = 0.82\n    PERLBREW_VERSION = 0.82\n    PERL_CR_SMOKER_CURRENT = Yancy-1.004\n    PERL_EXTUTILS_AUTOINSTALL = --defaultdeps\n    PERL_MM_USE_DEFAULT = 1\n    PERL_USE_UNSAFE_INC = 1\n    SHELL = /usr/local/bin/bash\n    TERM = xterm\n\nPerl special variables (and OS-specific diagnostics, for MSWin32):\n\n    $^X = /home/goku/perl5/perlbrew/perls/perl-5.24.3/bin/perl\n    $UID/$EUID = 1001 / 1001\n    $GID = 998 998 1001\n    $EGID = 998 998 1001\n\nPerl module toolchain versions installed:\n\n    Module              Have    \n    ------------------- --------\n    CPAN                2.20    \n    CPAN::Meta          2.150010\n    Cwd                 3.74    \n    ExtUtils::CBuilder  0.280230\n    ExtUtils::Command   7.34    \n    ExtUtils::Install   2.14    \n    ExtUtils::MakeMaker 7.34    \n    ExtUtils::Manifest  1.70    \n    ExtUtils::ParseXS   3.35    \n    File::Spec          3.74    \n    JSON                2.97001 \n    JSON::PP            2.97001 \n    Module::Build       0.4224  \n    Module::Signature   n/a     \n    Parse::CPAN::Meta   2.150010\n    Test::Harness       3.43_01 \n    Test::More          1.302135\n    YAML                1.24    \n    YAML::Syck          1.30    \n    version             0.9918  \n\n\n--\n\nSummary of my perl5 (revision 5 version 24 subversion 3) configuration:\n   \n  Platform:\n    osname=openbsd, osvers=6.2, archname=OpenBSD.amd64-openbsd-thread-multi-ld\n    uname='openbsd cpan-smoker-openbsd 6.2 generic.mp#134 amd64 '\n    config_args='-de -Dprefix=/home/goku/perl5/perlbrew/perls/perl-5.24.3 -Dman1dir=none -Dman3dir=none -Dusemultiplicity -Duselongdouble -Dusethreads -Duse64bitall -Duse64bitint -Aeval:scriptdir=/home/goku/perl5/perlbrew/perls/perl-5.24.3/bin'\n    hint=recommended, useposix=true, d_sigaction=define\n    useithreads=define, usemultiplicity=define\n    use64bitint=define, use64bitall=define, uselongdouble=define\n    usemymalloc=n, bincompat5005=undef\n  Compiler:\n    cc='cc', ccflags ='-pthread -fno-strict-aliasing -pipe -fstack-protector-strong -I/usr/local/include -D_FORTIFY_SOURCE=2',\n    optimize='-O2',\n    cppflags='-pthread -fno-strict-aliasing -pipe -fstack-protector-strong -I/usr/local/include'\n    ccversion='', gccversion='4.2.1 Compatible OpenBSD Clang 4.0.0 (tags/RELEASE_400/final)', gccosandvers=''\n    intsize=4, longsize=8, ptrsize=8, doublesize=8, byteorder=12345678, doublekind=3\n    d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=16, longdblkind=3\n    ivtype='long', ivsize=8, nvtype='long double', nvsize=16, Off_t='off_t', lseeksize=8\n    alignbytes=16, prototype=define\n  Linker and Libraries:\n    ld='cc', ldflags ='-pthread -Wl,-E  -fstack-protector-strong -L/usr/local/lib'\n    libpth=/usr/lib /usr/local/lib\n    libs=-lpthread -lm -lutil -lc\n    perllibs=-lpthread -lm -lutil -lc\n    libc=/usr/lib/libc.so.90.0, so=so, useshrplib=false, libperl=libperl.a\n    gnulibc_version=''\n  Dynamic Linking:\n    dlsrc=dl_dlopen.xs, dlext=so, d_dlsymun=undef, ccdlflags=' '\n    cccdlflags='-DPIC -fPIC ', lddlflags='-shared -fPIC  -L/usr/local/lib -fstack-protector-strong'\n\n\nCharacteristics of this binary (from libperl): \n  Compile-time options: HAS_TIMES MULTIPLICITY PERLIO_LAYERS\n                        PERL_COPY_ON_WRITE PERL_DONT_CREATE_GVSV\n                        PERL_HASH_FUNC_ONE_AT_A_TIME_HARD\n                        PERL_IMPLICIT_CONTEXT PERL_MALLOC_WRAP\n                        PERL_PRESERVE_IVUV USE_64_BIT_ALL USE_64_BIT_INT\n                        USE_ITHREADS USE_LARGE_FILES USE_LOCALE\n                        USE_LOCALE_COLLATE USE_LOCALE_CTYPE\n                        USE_LOCALE_NUMERIC USE_LOCALE_TIME USE_LONG_DOUBLE\n                        USE_PERLIO USE_PERL_ATOF USE_REENTRANT_API\n  Locally applied patches:\n\tDevel::PatchPerl 1.48\n  Built under openbsd\n  Compiled at Mar  6 2018 14:59:03\n  %ENV:\n    PERL5LIB=\"\"\n    PERL5OPT=\"\"\n    PERL5_CPANPLUS_IS_RUNNING=\"33187\"\n    PERL5_CPAN_IS_RUNNING=\"33187\"\n    PERL5_CPAN_IS_RUNNING_IN_RECURSION=\"13046,33187\"\n    PERLBREW_HOME=\"/home/goku/.perlbrew\"\n    PERLBREW_MANPATH=\"/home/goku/perl5/perlbrew/perls/perl-5.24.3/man\"\n    PERLBREW_PATH=\"/home/goku/perl5/perlbrew/bin:/home/goku/perl5/perlbrew/perls/perl-5.24.3/bin\"\n    PERLBREW_PERL=\"perl-5.24.3\"\n    PERLBREW_ROOT=\"/home/goku/perl5/perlbrew\"\n    PERLBREW_SHELLRC_VERSION=\"0.82\"\n    PERLBREW_VERSION=\"0.82\"\n    PERL_CR_SMOKER_CURRENT=\"Yancy-1.004\"\n    PERL_EXTUTILS_AUTOINSTALL=\"--defaultdeps\"\n    PERL_MM_USE_DEFAULT=\"1\"\n    PERL_USE_UNSAFE_INC=\"1\"\n  @INC:\n    /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3/OpenBSD.amd64-openbsd-thread-multi-ld\n    /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/site_perl/5.24.3\n    /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/5.24.3/OpenBSD.amd64-openbsd-thread-multi-ld\n    /home/goku/perl5/perlbrew/perls/perl-5.24.3/lib/5.24.3\n    .",
          "archname": "OpenBSD.amd64-openbsd-thread-multi-ld",
          "perl_version": "5.24.3",
          "osversion": "6.2"
        }
      },
      {
        "metadata": {
          "core": {
            "guid": "54b1e6a6-41f5-11e8-a7cf-a78da6ade2d7",
            "creator": "metabase:user:9c36dc84-a30f-11e0-a9fc-0a18abbd4f2f",
            "valid": 1,
            "type": "CPAN-Testers-Fact-TestSummary",
            "resource": "cpan:///distfile/PREACTION/Yancy-1.004.tar.gz",
            "schema_version": 1,
            "update_time": "2018-04-17T04:10:57Z",
            "creation_time": "2018-04-17T04:10:57Z"
          }
        },
        "content": {
          "grade": "pass",
          "osname": "openbsd",
          "archname": "OpenBSD.amd64-openbsd-thread-multi-ld",
          "osversion": "6.2",
          "perl_version": "5.24.3"
        }
      }
    ]
  }
}
