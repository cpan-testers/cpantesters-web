package CPAN::Testers::Web::Legacy::Model;
use warnings;
use strict;
use Carp;
use Try::Tiny 0.27;
use JSON 2.90;
use Metabase::Resource 0.025;
use CPAN::Testers::Report 1.999003;
use Metabase::Resource::cpan::distfile 0.025;
use Metabase::Resource::metabase::user 0.025;
use CPAN::Testers::Web::Legacy 'copyright';

=pod

=head1 NAME

CPAN::Testers::Web::Legacy::Model - a model for cpantesters-web-legacy

=head1 DESCRIPTION

This class implements a model for C<cpantesters-web-legacy>, but probably not what you would expect
for a MVC application as Mojolicious.

This model represents the logic behind the legacy C<view-report.cgi> related to retrieve and manipulating data, 
but does not breaks down each model mapping to a DB entity.

=head1 CAVEAT

This class probably should be reviewed and/or replaced in the future.

=head1 METHODS

=head2 new

Expects a single parameter: a instance of L<DBIx::Connector>.

Returns a new instance of this class.

=cut

sub new {
    my ( $class, $conn ) = @_;
    my $self = {
        conn        => $conn,
        report_data => undef,
    };
    bless $self, $class;
    return $self;
}

=head2 get_report

Recovers a report, based on the parameter given. Right now, only GUID based reports are recovered.

Returns a hash reference containing all the data from a report.

=cut

sub get_report {
    my ( $self, $guid ) = @_;
    $self->{report_data} = $self->{conn}->run(
        sub {
            my $sth = $_->prepare(
                q{SELECT fact, report FROM metabase.metabase WHERE guid = ?});
            $sth->bind_param( 1, $guid );
            $sth->execute();
            return $sth->fetchrow_arrayref;
        }
    );

# :TODO:08/05/2017 19:26:47:ARFREITAS: $data is intermediate data, it can be moved to upper to other subs and maintained in
# memory for a shorter period of time
    my ( $report, $data );

    if (    ( defined( $self->{report_data} ) )
        and ( scalar( @{ $self->{report_data} } ) > 0 ) )
    {

        # has the fact
        if ( defined( $self->{report_data}->[0] ) ) {
            $report = $self->_get_serial_data(0);
            $data   = $self->_dereference_report($report);
        }
        else {
            $data   = $self->_get_serial_data(1);
            $report = {
                metadata => {
                    core => { guid => $guid, type => 'CPAN-Testers-Report' }
                }
            };

            foreach my $name ( keys( %{$data} ) ) {
                push @{ $report->{content} }, $data->{$name};
            }

        }

        my $fact;

        if (
            ref( $data->{'CPAN::Testers::Fact::LegacyReport'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::LegacyReport' );
        }
        elsif (
            ref( $data->{'CPAN::Testers::Fact::TestSummary'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::TestSummary' );
        }
        else {
            die
'Cannot process data, neither CPAN::Testers::Fact::LegacyReport or CPAN::Testers::Fact::TestSummary';
        }

        my %template;
        $template{article}->{article} = $fact->{content}->{textreport};
        $template{article}->{guid}    = $guid;

# :TODO:08/05/2017 20:46:19:ARFREITAS: this seems to be ilogical... if
# $fact is not recovered from the database, it will be created based on $data anyway
# it should be same same thing using one or another
        if ( defined( $self->{report_data}->[0] ) ) {
            $self->_map_attribs( $report, $fact );
        }
        else {
            $self->_map_attribs( $report, $data );
        }

        $template{article}->{platform} = $fact->{content}->{archname};
        $template{article}->{osvers}   = $fact->{content}->{osversion};
        $template{article}->{created} =
          $fact->{metadata}->{core}->{creation_time};
        my $dist =
          Metabase::Resource->new( $fact->{metadata}->{core}->{resource} );
        $template{article}->{htmltitle} =
            'Report for '
          . $dist->metadata->{dist_name} . '-'
          . $dist->metadata->{dist_version};
        $template{article}->{dist_name}    = $dist->metadata->{dist_name};
        $template{article}->{dist_version} = $dist->metadata->{dist_version};
        $template{copyright}               = copyright();
        $template{article}->{dist_path} =
          substr( $dist->metadata->{dist_name}, 0, 1 );
        ( $template{article}->{author}, $template{article}->{from} ) =
          $self->_get_tester( $fact->creator );
        $template{article}->{subject} = $self->_get_subject( $fact, $dist );
        $template{article}->{article} = $fact->{content}->{textreport};
        $self->{report_data}          = undef;
        return \%template;
    }
    else {
        return undef;
    }

}

sub get_json_report {
    my ( $self, $guid ) = @_;
    $self->{report_data} = $self->{conn}->run(
        sub {
            my $sth = $_->prepare(
                q{SELECT fact, report FROM metabase.metabase WHERE guid = ?});
            $sth->bind_param( 1, $guid );
            $sth->execute();
            return $sth->fetchrow_arrayref;
        }
    );

# :TODO:08/05/2017 19:26:47:ARFREITAS: $data is intermediate data, it can be moved to upper to other subs and maintained in
# memory for a shorter period of time
    my ( $report, $data );

    if (    ( defined( $self->{report_data} ) )
        and ( scalar( @{ $self->{report_data} } ) > 0 ) )
    {

        # has the fact
        if ( defined( $self->{report_data}->[0] ) ) {
            $report = $self->_get_serial_data(0);
            $data   = $self->_dereference_report($report);
        }
        else {
            $data   = $self->_get_serial_data(1);
            $report = {
                metadata => {
                    core => { guid => $guid, type => 'CPAN-Testers-Report' }
                }
            };

            foreach my $name ( keys( %{$data} ) ) {
                push @{ $report->{content} }, $data->{$name};
            }

        }

        my $fact;

        if (
            ref( $data->{'CPAN::Testers::Fact::LegacyReport'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::LegacyReport' );
        }
        elsif (
            ref( $data->{'CPAN::Testers::Fact::TestSummary'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::TestSummary' );
        }
        else {
            die
'Cannot process data, neither CPAN::Testers::Fact::LegacyReport or CPAN::Testers::Fact::TestSummary';
        }

        my %json;

# :TODO:08/05/2017 20:46:19:ARFREITAS: this seems to be ilogical... if
# $fact is not recovered from the database, it will be created based on $data anyway
# it should be same same thing using one or another
        if ( defined( $self->{report_data}->[0] ) ) {
            $self->_map_attribs( $report, $fact );
        }
        else {
            $self->_map_attribs( $report, $data );
        }

        $json{result} = $self->_decode_report($report);

        if ( defined( $json{result} )
            and ( $json{result} ne '""' ) )
        {
            $json{success} = JSON::true;
        }
        else {
            $json{success} = JSON::false;
        }

        $self->{report_data} = undef;

        # the controller should be responsible to generate JSON as output
        return \%json;
    }
    else {
        return undef;
    }

}

sub _get_subject {
    my ( $self, $fact, $dist ) = @_;
    return sprintf "%s %s-%s %s %s", uc( $fact->{content}->{grade} ),
      $dist->metadata->{dist_name},
      $dist->metadata->{dist_version}, $fact->{content}->{perl_version},
      $self->_get_osname( $fact->{content}->{osname} );
}

sub get_raw_report {
    my ( $self, $guid ) = @_;
    $self->{report_data} = $self->{conn}->run(
        sub {
            my $sth = $_->prepare(
                q{SELECT fact, report FROM metabase.metabase WHERE guid = ?});
            $sth->bind_param( 1, $guid );
            $sth->execute();
            return $sth->fetchrow_arrayref;
        }
    );

# :TODO:08/05/2017 19:26:47:ARFREITAS: $data is intermediate data, it can be moved to upper to other subs and maintained in
# memory for a shorter period of time
    my ( $report, $data );

    if (    ( defined( $self->{report_data} ) )
        and ( scalar( @{ $self->{report_data} } ) > 0 ) )
    {

        # has the fact
        if ( defined( $self->{report_data}->[0] ) ) {
            $report = $self->_get_serial_data(0);
            $data   = $self->_dereference_report($report);
        }
        else {
            $data   = $self->_get_serial_data(1);
            $report = {
                metadata => {
                    core => { guid => $guid, type => 'CPAN-Testers-Report' }
                }
            };

            foreach my $name ( keys( %{$data} ) ) {
                push @{ $report->{content} }, $data->{$name};
            }

        }

        my $fact;

        if (
            ref( $data->{'CPAN::Testers::Fact::LegacyReport'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::LegacyReport' );
        }
        elsif (
            ref( $data->{'CPAN::Testers::Fact::TestSummary'}->{content} ) eq
            'HASH' )
        {
            $fact =
              $self->_gen_fact( $data, 'CPAN::Testers::Fact::TestSummary' );
        }
        else {
            die
'Cannot process data, neither CPAN::Testers::Fact::LegacyReport or CPAN::Testers::Fact::TestSummary';
        }

        my %template;
        $template{article}->{article} = $fact->{content}->{textreport};
        $template{article}->{guid}    = $guid;

# :TODO:08/05/2017 20:46:19:ARFREITAS: this seems to be ilogical... if
# $fact is not recovered from the database, it will be created based on $data anyway
# it should be same same thing using one or another
        if ( defined( $self->{report_data}->[0] ) ) {
            $self->_map_attribs( $report, $fact );
        }
        else {
            $self->_map_attribs( $report, $data );
        }

        $template{article}->{created} =
          $fact->{metadata}->{core}->{creation_time};
        my $dist =
          Metabase::Resource->new( $fact->{metadata}->{core}->{resource} );
        $template{article}->{htmltitle} =
            'Report for '
          . $dist->metadata->{dist_name} . '-'
          . $dist->metadata->{dist_version};
        $template{copyright} = copyright();
        $template{article}->{author} = $self->_get_tester( $fact->creator );
        $template{article}->{subject} = $self->_get_subject( $fact, $dist );
        $template{raw_report}         = $fact->{content}->{textreport};
        $template{is_raw}             = 1;
        $self->{report_data}          = undef;
        return \%template;
    }
    else {
        return undef;
    }

}

sub _gen_fact {
    my ( $self, $data_ref, $fact_name ) = @_;

    try {
        $data_ref->{$fact_name}->{content} =
          encode_json( $data_ref->{$fact_name}->{content} );
        return CPAN::Testers::Fact::TestSummary->from_struct(
            $data_ref->{$fact_name} );
    }
    catch {
        die "Failed to encode $fact_name as JSON: $_";
    }

}

sub _decode_report {
    my ( $self, $report ) = @_;
    my $final_report;

    # do we have an encoded report object?
    if ( ref($report) eq 'CPAN::Testers::Report' ) {
        $final_report = $report->as_struct;
        $final_report->{content} = decode_json( $final_report->{content} );

        foreach my $content ( @{ $final_report->{content} } ) {
            $content->{content} = decode_json( $content->{content} );
        }

    }
    else {
        # we have a manufactured hash, with a collection of fact objects

        try {

            foreach my $fact ( @{ $report->{content} } ) {
                $fact->{content} = decode_json( $fact->{content} );
            }

            $final_report = $report;
        }
        catch {
            confess $_;
        };

    }

    # manually fixing booleans

    for my $index ( 0 .. 1 ) {

        if (
            exists(
                $final_report->{content}->[$index]->{metadata}->{core}->{valid}
            )
          )
        {

            $final_report->{content}->[$index]->{metadata}->{core}->{valid} =
              ( $final_report->{content}->[$index]->{metadata}->{core}->{valid}
              )
              ? JSON::true
              : JSON::false;

        }

    }

    if ( exists( $final_report->{metadata}->{core}->{valid} ) ) {
        $final_report->{metadata}->{core}->{valid} =
          ( $final_report->{metadata}->{core}->{valid} )
          ? JSON::true
          : JSON::false;
    }

    return $final_report;
}

sub _dereference_report {
    my ( $self, $report ) = @_;
    my %facts;
    my @facts = $report->facts();

    foreach my $fact (@facts) {
        my $name = ref($fact);
        $facts{$name} = $fact->as_struct;
        $facts{$name}{content} = decode_json( $facts{$name}{content} );
    }

    return \%facts;
}

# changes report in place
sub _map_attribs {
    my ( $self, $report, $source ) = @_;
    my @attribs =
      qw(resource schema_version creation_time valid creator update_time);
    my $source_path;

    if ( $source->isa('CPAN::Testers::Fact::LegacyReport') ) {
        $source_path = $source->{metadata}->{core};
    }
    else {
        $source_path =
          $source->{'CPAN::Testers::Fact::TestSummary'}->{metadata}->{core};
    }

    foreach my $attrib (@attribs) {
        $report->{metadata}->{core}->{$attrib} = $source_path->{$attrib};
    }
}

# :TODO:08/05/2017 21:04:10:ARFREITAS: this can be easily cached from the DB
sub _get_osname {
    my ( $self, $os_name ) = @_;
    return 'UNKNOWN' unless ( defined($os_name) ) and ( $os_name ne '' );
    my $preferred_name = $self->{conn}->run(
        sub {
            my $sth = $_->prepare(
                q{SELECT ostitle FROM cpanstats.osname where osname = ?});
            my $code = lc($os_name);
            $code =~ s/[^\w]+//g;
            $sth->bind_param( 1, $code );
            $sth->execute();
            return $sth->fetchrow_arrayref()->[0];
        }
    );

    if ( defined($preferred_name) ) {
        return $preferred_name;
    }
    else {
        return uc($os_name);
    }
}

sub _get_tester {
    my ( $self, $creator ) = @_;
    my $row_ref = $self->{conn}->run(
        sub {
# :WORKAROUND:19/05/2017 22:13:15:ARFREITAS: used lower() function to make it able to use data from both
# Mysql and SQLite3, since the testers.address table on Mysql is using UTF8 case insensitive collation
            my $query =
              q{SELECT mte.fullname, tp.name, tp.pause, tp.contact, mte.email
FROM metabase.testers_email mte 
LEFT JOIN testers.address ta ON lower(ta.email)=lower(mte.email)
LEFT JOIN testers.profile tp ON tp.testerid=ta.testerid 
WHERE mte.resource=?
ORDER BY tp.testerid DESC
limit 1};
            my $sth = $_->prepare($query);
            $sth->bind_param( 1, $creator );
            $sth->execute();
            return $sth->fetchrow_arrayref;
        }
    );
    unless ( scalar( @{$row_ref} ) > 0 ) {
        return wantarray ? ( $creator, $creator ) : $creator;
    }
    else {
        my $name = $row_ref->[0];
        $name = join( ' ', $row_ref->[1], $row_ref->[2] )
          if ( defined( $row_ref->[1] ) );
        my $email = $row_ref->[3] || $row_ref->[4] || $creator;
        $email =~ s/\'/''/g if ($email);
        $name =~ s/\@/ [at] /g;
        $email =~ s/\@/ [at] /g;
        $email =~ s/\./ [dot] /g;
        wantarray ? ( $name, $email ) : $name;
    }

}

# passing an index to get advantage of the array reference
sub _get_serial_data {
    my ( $self, $index ) = @_;
    my $serializer = Data::FlexSerializer->new(
        detect_compression => 1,
        detect_sereal      => 1,
        detect_json        => 1,
    );
    return $serializer->deserialize( $self->{report_data}->[$index] );
}

1;
