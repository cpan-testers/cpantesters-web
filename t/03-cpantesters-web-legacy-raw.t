use warnings;
use strict;
use Test::More tests => 14;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../bin/cpantesters-web-legacy";

my $URL = '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a528974d?raw=1';
my $t   = Test::Mojo->new();
$t->get_ok($URL)->status_is(200);
$t->element_exists_not( 'html body h1[class=pagetitle]', 'has not a H1 title' );
$t->element_exists_not(
    'html body div[class=orange_buttons]',
    'has not the "Raw" and "Back" buttons'
);
$t->text_is(
    'html head title' => 'CPAN Testers Reports: Report for Statocles-0.083' );
$t->element_exists_not('html body div.footer p:nth-child(3)');
$t->element_exists('html head meta[name=title][content=CPAN Testers Reports]');
$t->element_exists( 'html body pre');
note('Testing the report values now');
$t->content_like( qr/From:\s<strong>Dan\sCollins\sDCOLLINS<\/strong>/,
    'get the right From content' );
$t->content_like(
    qr/Subject:\s<strong>PASS\sStatocles-0.083\sv5.26.0\sGNU\/Linux<\/strong>/,
    'Get the right Subject content'
);
$t->content_like( qr/Date:\s<strong>2017-04-08T00:36:45Z<\/strong>/,
    'Get the right Date content' );
$t->content_like( qr/Result:\sPASS/, 'get the expected test result' );
$t->content_like(
qr/Files=71,\sTests=360,\s61\swallclock\ssecs\s\(\s0\.98\susr\s{2}0\.11\ssys\s\+\s167\.42\scusr\s{2}8\.69\scsys\s=\s177\.20\sCPU\)/,
    'Get the report tests details'
);
$t->content_like( qr/osvers=3.16.0-4-amd64/,
    'get the OS version where the test was executed' );

# vim: filetype=perl
