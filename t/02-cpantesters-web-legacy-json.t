use warnings;
use strict;
use Test::More;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../bin/cpantesters-web-legacy";

my $URL = '/cpan/report/7185287a-1bf3-11e7-8a18-c6c6a528974d?json=1';
my $t   = Test::Mojo->new();
$t->get_ok($URL)->status_is(200);
my @members = (
    '/success',
    '/result/content/0/content/grade',
    '/result/content/0/content/archname',
    '/result/content/0/content/osname',
    '/result/content/0/content/osversion',
    '/result/content/0/content/perl_version',
    '/result/content/0/content/textreport',
    '/result/content/0/metadata/core/guid',
    '/result/content/0/metadata/core/type',
    '/result/content/0/metadata/core/creation_time',
    '/result/content/0/metadata/core/update_time',
    '/result/content/0/metadata/core/schema_version',
    '/result/content/0/metadata/core/creator',
    '/result/content/0/metadata/core/valid',
    '/result/content/0/metadata/core/resource',
    '/result/content/1/content/perl_version',
    '/result/content/1/content/osversion',
    '/result/content/1/content/osname',
    '/result/content/1/content/archname',
    '/result/content/1/content/grade',
    '/result/content/1/metadata/core/valid',
    '/result/content/1/metadata/core/resource',
    '/result/content/1/metadata/core/creator',
    '/result/content/1/metadata/core/creation_time',
    '/result/content/1/metadata/core/update_time',
    '/result/content/1/metadata/core/schema_version',
    '/result/content/1/metadata/core/guid',
    '/result/content/1/metadata/core/type',
    '/result/metadata/core/resource',
    '/result/metadata/core/valid',
    '/result/metadata/core/creator',
    '/result/metadata/core/creation_time',
    '/result/metadata/core/update_time',
    '/result/metadata/core/schema_version',
    '/result/metadata/core/guid',
    '/result/metadata/core/type'
);

for my $member (@members) {
    $t->json_has($member);
}

done_testing;
