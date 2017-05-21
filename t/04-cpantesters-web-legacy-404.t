use warnings;
use strict;
use Test::More;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../bin/cpantesters-web-legacy";

my @URLS = (
    '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a5289FOOBAR',
    '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a5289FOOBAR?raw=1',
    '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a5289FOOBAR?json=1',
);

for my $URL (@URLS) {
    my $t = Test::Mojo->new();
    # Accepting redirection is a requirement for this test
    $t->ua->max_redirects(1);
    note("Validating $URL");
    $t->get_ok($URL)->status_is(200);
    $t->text_is(
        'html head title' => 'CPAN Testers Reports: report not found' );
    $t->text_is( 'body p:nth-child(1)' =>
"Sorry, but that report isn't currently stored locally. If this is a very recently submitted report, please note that replication between the metabase server and the cpantesters server can take several minutes. Please try again in 10-15 minutes. Alternatively this page will refresh every 5 minutes until the report is available."
    );
}

done_testing;

# vim: filetype=perl
