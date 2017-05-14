package CPAN::Testers::Web::Legacy;
use warnings;
use strict;
use Exporter 'import';
use Data::FlexSerializer 1.10;
our $VERSION = '0.001';

=pod

=head1 NAME

CPAN::Testers::Web::Legacy - base module for cpantesters-web-legacy application

=head1 DESCRIPTION

This module doesn't do much, except for serving as reference to locate the templates and static files
for the C<cpantesters-web-legacy> application.

=head1 EXPORTS

This module exports a single function described below.

=head2 params_to_string

Converts the HTTP request parameters and generates a string of it. Useful for debugging.

Receives as parameter the request parameters (as defined by L<Mojo::Message::Request> C<query_params>, which returns a L<Mojolicious::Params> instance invoking C<to_hash> ) received.

Returns a string of it.

=cut

our @EXPORT_OK = qw(params_to_string);

sub params_to_string {
    my $params_ref = shift;
    my @text;

    foreach my $name ( keys( %{$params_ref} ) ) {
        push( @text, $name . ' = ' . $params_ref->{$name} );
    }

    return join( "\n", @text );
}

=pod

=head1 SEE ALSO

=over

=item *

L<Mojo::Message::Request>

=item *

L<Mojolicious::Controller>

=item *

L<Mojolicious::Message::Request>

=item *

L<Mojolicious::Params>

=item *

L<File::Share>

=back

=cut

1;

# vim: filetype=perl
