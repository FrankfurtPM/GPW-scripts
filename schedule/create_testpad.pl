#!/usr/bin/perl

use v5.20;

use strict;
use warnings;

use Etherpad;

$ENV{MOJO_MAX_REDIRECTS} = 2;

my $base_url     = 'http://pad.german-perl-workshop.de/';
my $etherpad     = Etherpad->new(
    url    => $base_url,
    apikey => '<api_key>',
);

$etherpad->create_pad( 'question-bot-test-2' );
