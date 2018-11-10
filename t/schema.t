
=head1 DESCRIPTION

This tests the L<CPAN::Testers::Web::Schema> module and all of its included modules
(the Result and ResultSet classes).

=head1 SEE ALSO

L<DBIx::Class::Schema>, L<DBIx::Class::ResultSet>, L<DBIx::Class::Row>

=cut

use CPAN::Testers::Web::Base 'Test';
use CPAN::Testers::Web::Schema;

my $schema = CPAN::Testers::Web::Schema->connect(
    'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 },
);
$schema->deploy;

subtest 'users' => sub {
    my $rs = $schema->resultset( 'Users' );
    subtest 'required fields' => sub {
        eval { $rs->create({}) };
        ok $@, 'Users->create() dies';
        like $@, qr{github_login}, '... because github_login is not specified';
    };

    my $user = $rs->create({ github_login => 'preaction' });
    ok !$user->pause_id, 'no pause id by default';
    ok !$user->pause_token, 'no pause token by default';

    subtest 'generate_pause_token' => sub {
        eval { $user->generate_pause_token };
        ok $@, 'generate_pause_token dies with no pause ID';
        like $@, qr{No PAUSE ID set.+preaction}, 'error is useful';

        ok !$user->check_pause_token( 'NOT THE TOKEN' ),
            'check_pause_token fails without pause ID';

        my $token = $user->generate_pause_token( 'PREACTION' );
        ok $token, 'token is returned';
        $user->discard_changes;
        is $user->pause_token, $token, 'token stored in database';
        is $user->valid_pause_id, undef,
            'unvalidated PAUSE ID not returned by valid_pause_id';
        is $user->pause_id, 'PREACTION',
            'pause_id is set in database';

        ok !$user->check_pause_token( 'NOT THE TOKEN' ),
            'check_pause_token fails with incorrect token';

        ok $user->check_pause_token( $token ),
            'check_pause_token succeeds with correct token';
        $user->discard_changes;
        ok !$user->pause_token, 'token is cleared after validation';
        is $user->valid_pause_id, 'PREACTION',
            'validated PAUSE ID returned by valid_pause_id';
    };
};

done_testing;
