#!/usr/bin/env perl

use v5.20;

use strict;
use warnings;

use Mojo::DOM;
use Mojo::File;
use Data::Tabulate;
use Text::CSV_XS;
use Encode;

my $file = Mojo::File->new('./Badge-4er-tmpl.pure.svg');

my @user_pages = _get_gpw_users();

my $page_nr = 0;
for my $page ( @user_pages ) {
    my $dom  = Mojo::DOM->new( $file->slurp );

    $page_nr++;

    for my $i ( 0 .. 3 ) {
        say sprintf "Set name %s...", encode( 'utf-8', $page->[$i]->[0] );

        my $firstname      = $page->[$i]->[1];
        my $firstname_node = $dom->find('#firstname-' . ($i+1) )->first;
        $firstname_node->content( $firstname );

        $dom->find('#lastname-' . ($i+1) )->first->content( $page->[$i]->[2] );

        my $style = $firstname_node->attr('style');

        if ( length $firstname > 15 ) {
            $style =~ s{font-size:\K[0-9\.]+px}{9px};
        }
        elsif ( length $firstname > 13 ) {
            $style =~ s{font-size:\K[0-9\.]+px}{10px};
        }
        elsif ( length $firstname > 11 ) {
            $style =~ s{font-size:\K[0-9\.]+px}{12px};
        }

        $firstname_node->attr( style => $style );
    }

    my $page = Mojo::File->new('./Badges/Badge.page' . $page_nr . '.svg');
    $page->spurt( encode( 'utf-8', "$dom") );

    # convert SVG to PDF
    my $cmd = sprintf "inkscript --export-pdf Badge.%s.pdf %s", $page_nr, $page->to_string;
    qx{$cmd};
}


sub _get_gpw_users {
    my @users;

    if ( open my $fh, '<:encoding(utf-8)', 'users.csv' ) {
        my @temp_users;
        my $csv = Text::CSV_XS->new({ binary => 1 });
        while ( my $row = $csv->getline( $fh ) ) {
            my ($firstname, $lastname, $nick, $pseudo) = @{$row}[4..7];

            next if $firstname eq 'first_name';

            if ( $pseudo ) {
                $firstname = $nick;
                $lastname  = '';
            }

            my $fullname = $pseudo ? $nick : "$firstname $lastname";

            push @temp_users, [
                $fullname,  # fullname
                $firstname, # firstname
                $lastname,  # lastname
            ];
        }

        close $fh;

        my $tabulator = Data::Tabulate->new;
        $tabulator->min_columns(4);
        $tabulator->max_columns(4);
        $tabulator->fill_with( [ '', '', '' ] );

        @users = $tabulator->tabulate( @temp_users );
    }

    return @users;
}
