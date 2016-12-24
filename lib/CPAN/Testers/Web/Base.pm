use utf8;
package CPAN::Testers::Web::Base;
our $VERSION = '0.001';
# ABSTRACT: Base module for importing standard modules, features, and subs

=head1 SYNOPSIS

    # lib/CPAN/Testers/Web/MyModule.pm
    package CPAN::Testers::Web::MyModule;
    use CPAN::Testers::Web::Base;

    # t/mytest.t
    use CPAN::Testers::Web::Base 'Test';

=head1 DESCRIPTION

This module collectively imports all the required features and modules
into your module. This module should be used by all modules in the
L<CPAN::Testers::Web> distribution. This module should not be used by
modules in other distributions.

This module imports L<strict>, L<warnings>, and L<the sub signatures
feature|perlsub/Signatures>.

=head1 SEE ALSO

=over

=item L<Import::Base>

=back

=cut

use strict;
use warnings;
use base 'Import::Base';

our @IMPORT_MODULES = (
    'strict', 'warnings',
    feature => [qw( :5.24 signatures refaliasing )],
    '-warnings' => [qw( experimental::signatures experimental::refaliasing )],
);

our %IMPORT_BUNDLES = (
    Test => [
        'Test::More', 'Test::Lib', 'Test::Mojo',
    ],
);

1;
