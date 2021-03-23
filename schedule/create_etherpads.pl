#!/usr/bin/perl

use v5.20;

use strict;
use warnings;

use Encode;
use Etherpad;
use Mojo::File qw(curfile);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::Util qw(slugify);
use Text::CSV_XS;

$ENV{MOJO_MAX_REDIRECTS} = 2;

my $schedule_csv = 'export_talks';
my $csv          = Text::CSV_XS->new({ sep_char => ',', binary => 1 });
my $base_url     = 'http://pad.german-perl-workshop.de/';
my $etherpad     = Etherpad->new(
    url    => $base_url,
    apikey => 'api_key',
);

my %data;
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

    warn $slug;

    my $talk = {
        id    => $row->[4],
        title => $row->[5],
        slug  => $slug,
        url   => $base_url . 'p/' . $slug,
        time  => $time,
    };

    $etherpad->create_pad( $slug );

    $data{$day}->{$time} = $talk;
}
close $fh;

my $tmpl_raw = data_section 'main', 'etherpads.txt.ep';
my $tmpl     = Mojo::Template->new->vars(1);

my $xml = $tmpl->render( $tmpl_raw, { gpw_data => \%data } );

curfile->sibling('etherpads.txt')->spurt( encode_utf8( $xml ) );

__DATA__
@@ etherpads.txt.ep
% for my $day ( sort keys %{ $gpw_data} ) {
    % my $day_data = $gpw_data->{$day};

    % for my $talk_key ( sort keys %{ $day_data } ) {
        % my $talk = $day_data->{$talk_key};
Talk: <%= $talk->{title} %>
Zeit: <%= $talk->{time} %>
Etherpad: <%= $talk->{slug} %>
Etherpad URL: <%= $talk->{url} %>
-------------
    % }
% }
