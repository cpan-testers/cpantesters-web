use warnings;
use strict;
use Test::More tests => 4;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../bin/cpantesters-web-legacy";

my $URL = '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a5289FOOBAR';
my $t   = Test::Mojo->new();
note('Accepting redirection is required for this test');
$t->ua->max_redirects(1);
$t->get_ok($URL)->status_is(200);
$t->text_is( 'html head title' => 'CPAN Testers Reports: report not found' );
$t->text_is( 'body p:nth-child(1)' =>
"Sorry, but that report isn't currently stored locally. If this is a very recently submitted report, please note that replication between the metabase server and the cpantesters server can take several minutes. Please try again in 10-15 minutes. Alternatively this page will refresh every 5 minutes until the report is available."
);

# vim: filetype=perl
