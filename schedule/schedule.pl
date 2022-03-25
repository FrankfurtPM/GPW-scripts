#!/usr/bin/perl

use v5.20;

use strict;
use warnings;

use Data::Printer;
use Data::UUID;
use Encode;
use Mojo::File qw(curfile);
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::Util qw(slugify);
use Text::CSV_XS;

my $schedule_csv = 'export_talks';
my $csv          = Text::CSV_XS->new({ sep_char => ',', binary => 1 });
my $uuid         = Data::UUID->new;
my $base_url     = 'https://act.yapc.eu/gpw2022/';

my %data;
my $line = 0;

open my $fh, '<:encoding(utf-8)', $schedule_csv or die $!;
while ( my $row = $csv->getline( $fh ) ) {
    next if !$line++;
    next if !$row->[11];

    my $time  = $row->[15];
    next if !$time;

    my ($day,$start) = split / /, $time;

    $time =~ s/ /T/;

    my $talk = {
        id        => $row->[4],
        title     => $row->[5],
        abstract  => $row->[6],
        duration  => _calc_duration( $row->[9] ),
        timestamp => $row->[15],
        lang      => $row->[18],
        slug      => slugify( $row->[5] ),
        uuid      => $uuid->create_str,
        url       => $base_url . 'talk/' . $row->[4],
        start     => $start,
    };

    $talk->{persons}  = [ { id => $row->[0], name => join ' ', @{$row}[1,2] } ];

    $data{$day}->{$time} = $talk;
}
close $fh;

my $tmpl_raw = data_section 'main', 'schedule.xml.ep';
my $tmpl     = Mojo::Template->new->vars(1);


my $xml = $tmpl->render( $tmpl_raw, { gpw_data => \%data } );

curfile->sibling('schedule.xml')->spurt( encode_utf8( $xml ) );

sub _calc_duration {
    my ($min) = shift;

    my $hour = int( $min / 60 );
    $min = $min % 60;

    return sprintf "%02d:%02d", $hour, $min;
}

__DATA__
@@ schedule.xml.ep
% use List::Util qw(min max);
<?xml version='1.0' encoding='utf-8' ?>
<schedule>
    <generator name='gpw_schedule.pl' version='1.0'></generator>
    <version>mkdir</version>
    <conference>
        <acronym>gpw2022</acronym>
        <title>German Perl-/Raku-Workshop 2022</title>
        <start>2022-03-30</start>
        <end>2022-04-01</end>
        <days>3</days>
        <timeslot_duration>00:10</timeslot_duration>
        <base_url>https://act.yapc.eu/gpw2022/</base_url>
    </conference>
% for my $day ( sort keys %{ $gpw_data} ) {
    % my $day_data = $gpw_data->{$day};
    % my $start    = (sort { $a cmp $b } keys %{ $day_data })[0];
    % my $end      = (sort { $b cmp $a } keys %{ $day_data })[0];

    <day date='<%= $day %>' end='<%= $end %>' index='1' start='<%= $start %>'>
        <room name='main'>
% for my $talk_key ( sort keys %{ $day_data } ) {
            % my $talk = $day_data->{$talk_key};
            <event guid='<%= $talk->{uuid} %>' id='<%= $talk->{id} %>'>
                <date><%= $talk->{timestamp} %></date>
                <start><%= $talk->{start} %></start>
                <duration><%= $talk->{duration} %></duration>
                <room>main</room>
                <slug><%= $talk->{slug} %></slug>
                <url><%= $talk->{url} %></url>
                <recording>
                    <license></license>
                    <optout>false</optout>
                </recording>
                <title><%== $talk->{title} %></title>
                <subtitle></subtitle>
                <track>GPW2022</track>
                <type>lecture</type>
                <language><%= $talk->{lang} %></language>
                <abstract><%== $talk->{abstract} %></abstract>
                <description></description>
                <logo></logo>
                <persons>
% for my $person ( @{ $talk->{persons} } ) {
                    <person id='<%= $person->{id} %>'><%= $person->{name} %></person>
% }
                </persons>
                <links>
                </links>
                <attachments>
                </attachments>
                <scene>Orga-Screenshare (obs.ninja)</scene>
            </event>
% }
        </room>
    </day>
% }
</schedule>
