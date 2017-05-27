package Test::CPAN::Testers::Web::Legacy::Fixtures;

use warnings;
use strict;

sub gen_dbs {

    my $sqlite = DBI->connect( 'dbi:SQLite:dbname=:memory:', '', '',
        { RaiseError => 1, AutoCommit => 1 } );
    attach($sqlite);
    $sqlite->do(
q{CREATE TABLE metabase.metabase (GUID text primary key, id integer unique, updated text, report blob not null, fact bloc)}
    );
    $sqlite->do(
q{CREATE TABLE metabase.testers_email (id int primary key, resource text not null, fullname text not null, email text)}
    );
    $sqlite->do(
q{create table cpanstats.osname (id int primary key, osname text, ostitle text)}
    );
    $sqlite->do(
q{create table testers.address (addressid int primary key, testerid int unique not null, address text not null, email text)}
    );
    $sqlite->do(
q{create table testers.profile (testerid int primary key, name text, pause text, contact text)}
    );

    my @tables = (
        {
            csv => '',
            insert =>
q{insert into metabase.metabase(guid, id, updated, report, fact) values (?, ?, ?, ?, ?)}
        },
        {
            csv => '',
            insert =>
q{insert into metabase.testers_email(id, resource, fullname, email) values (?, ?, ?, ?)},
        },
        {
            csv => '',
            insert =>
q{insert into testers.address(addressid, testerid, address, email) values (?, ?, ?, ?)},
        },
        {
            csv => '',
            insert =>
q{insert into testers.profile(testerid, name, pause, contact) values (?, ?, ?, ?)}
        },
        {
            csv => '',
            insert =>
q{insert into cpanstats.osname(id, osname, ostitle) values (?, ?, ?)},
        }
    );

}

sub populate_table {
    my ( $sqlite, $csv, $insert, $JSON ) = @_;
    my $insert_h = $sqlite->prepare($insert);
    my $query_h  = $mysql->prepare($query);
    $query_h->execute;
    my $inserted = 0;

    while ( my $row = $query_h->fetchrow_arrayref ) {
        for ( my $i = 0 ; $i < scalar( @{$row} ) ; $i++ ) {
            $insert_h->bind_param( ( $i + 1 ), $row->[$i] );
        }

        try {
            $insert_h->execute();
            $inserted += $insert_h->rows;
        }
        catch {
            warn "Failed to insert: $_";
            warn Dumper($row);
            die "Cannot continue";
        };

    }

    print 'Fetched ', $query_h->rows, " for [$query]\n";
    print 'Inserted ', $inserted, " for [$insert]\n";
    die "There is some problem with $query or $insert"
      unless ( ( $query_h->rows > 0 )
        and ( $query_h->rows == $inserted ) );
}

sub attach {
    my ($dbh) = @_;

    for my $db (qw(metabase cpanstats testers)) {
        $dbh->do("attach database '$db' as $db");
    }

}

# vim: filetype=perl
