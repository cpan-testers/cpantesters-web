package CPAN::Testers::Web::Schema;
our $VERSION = '0.001';
# ABSTRACT: Schema for website user accounts and supporting data

=head1 SYNOPSIS

    my $schema = CPAN::Testers::Web::Schema->connect_from_config;

=head1 DESCRIPTION

This schema contains data for the website's users and other global data.

=head1 SEE ALSO

L<DBIx::Class::Schema>

=cut

use CPAN::Testers::Web::Base;
use File::Spec::Functions qw( catdir );
use File::Share qw( dist_dir );
use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;
__PACKAGE__->load_components(qw/Schema::Versioned/);
__PACKAGE__->upgrade_directory( catdir( dist_dir( 'CPAN-Testers-Web' ), 'schema' ) );

=method connect_from_config

    my $schema = CPAN::Testers::Web::Schema->connect_from_config( %extra_conf );

Connect to the MySQL database using a local MySQL configuration file
in C<$HOME/.cpanstats.cnf>. This configuration file should look like:

    [client]
    host     = ""
    user     = my_usr
    password = my_pwd

The C<dbname> will be set to C<cpan_testers_web>.

See L<DBD::mysql/mysql_read_default_file>.

C<%extra_conf> will be added to the L<DBIx::Class::Schema/connect>
method in the C<%dbi_attributes> hashref (see
L<DBIx::Class::Storage::DBI/connect_info>).

=cut

# Convenience connect method
sub connect_from_config ( $class, %config ) {
    my $schema = $class->connect(
        "DBI:mysql:dbname=cpan_testers_web;mysql_read_default_file=$ENV{HOME}/.cpanstats.cnf;".
        "mysql_read_default_group=application;mysql_enable_utf8=1",
        undef,  # user
        undef,  # pass
        {
            AutoCommit => 1,
            RaiseError => 1,
            mysql_enable_utf8 => 1,
            quote_char => '`',
            name_sep   => '.',
            %config,
        },
    );
    return $schema;
}

1;
