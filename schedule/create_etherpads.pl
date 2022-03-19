#!/usr/bin/perl

use v5.20;

use strict;
use warnings;

use DateTime;
use DateTime::TimeZone;
use Encode;
use Etherpad;
use Mojo::File qw(curfile);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::Util qw(slugify);
use Text::CSV_XS;
use Time::Piece;
use YAML::Tiny;

$ENV{MOJO_MAX_REDIRECTS} = 2;

my $schedule_csv = $ARGV[0] || 'export_talks';
my $csv          = Text::CSV_XS->new({ sep_char => ',', binary => 1 });
my $base_url     = 'http://pad.german-perl-workshop.de/';
my $etherpad     = Etherpad->new(
    url    => $base_url,
    apikey => 'api_key',
);

my %talks;
my $line = 0;

open my $fh, '<:encoding(utf-8)', $schedule_csv or die $!;
while ( my $row = $csv->getline( $fh ) ) {
    next if !$line++;
    next if !$row->[11];

    my $time  = $row->[15];
    next if !$time;

    my ($day,$start) = split / /, $time;
    my $slug = slugify( $row->[5] );

    if ( length $slug > 45 ) {
        $slug = substr $slug, 0, 45;
    }

    state $tz = do {
        my $dttz  = DateTime::TimeZone->new( name => 'Europe/Berlin' );
        my $epoch = Time::Piece->strptime( $day . ' 09:00:00', '%Y-%m-%d %H:%M:%S' )->epoch;
        my $dt    = DateTime->from_epoch( epoch =>  $epoch );
        my $z     = $dttz->offset_for_datetime( $dt );
        $z + 5;
    };

    warn $tz;

    warn $slug;

    my $talk = {
        id    => $row->[4],
        title => $row->[5],
        slug  => $slug,
        url   => $base_url . 'p/' . $slug,
        time  => $time,
    };

    $etherpad->create_pad( $slug );
    warn $time . ' ' . $tz;

    my $timestamp_start_minus_5_mins = Time::Piece->strptime( $time, '%Y-%m-%d %H:%M:%S' )->epoch - $tz;

    $talks{$timestamp_start_minus_5_mins} = $talk;
}
close $fh;

curfile->sibling('etherpads.yml')->spurt( encode_utf8( YAML::Tiny->new( \%talks )->write_string ) );

