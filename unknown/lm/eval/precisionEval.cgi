#!/bin/env perl
# -*- Mode: perl; tab-width: 4; indent-tabs-mode: nil; -*-
#
# jumanDiffSeq の結果をうけて評価する
#
use strict;
use utf8;

use CGI;

my $q = new CGI;
print $q->header('text/html');
print "\n\n";
print $q->start_html ( -encoding => "UTF-8" );

# パラメータの読み込み
my $pageID;
my $result = [];
my $status = 1;
foreach my $name ($q->param) {
    my $val = $q->param ($name);

    if ($name eq 'pageID') {
        $pageID = $val;
    } elsif ($name =~ /^sec([0-9]+)$/) {
        my $index = $1;
        $val = int ($val);
        if ($val ==0 || $val == 1) {
            push (@$result, [$index, $val]);
        } else {
            printf ("parameter out of range: %s = %s<br/>\n", $name, $val);
            $status = 0;
        }
    } else {
        printf ("unknown parameter: %s = %s<br/>\n", $name, $val);
    }
}

if (!$status) {
    print ("erorr\n");
    print $q->end_html;
    exit 0;
}

print "<br />\n";

my $total = scalar (@$result);
printf ("total: %d<br />\n", $total);
my $correct = 0;
foreach my $tmp (@$result) {
    my ($index, $val) = @$tmp;
    $correct++ if ($val == 1);
}
printf ("accuracy: %d / %d (%f)<br />\n", $correct, $total, $correct / $total);

use Storable qw/nstore/;
my $struct = {
    pageID => $pageID,
    result => $result
};
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $path = sprintf ("%s_%04d%02d%02d%02d%02d.storable", $pageID, $year + 1900, $mon + 1, $mday + 1, $hour, $min);
nstore ($struct, $path) or print "store failed\n";;

print ("save the data: $path\n");

print $q->end_html;

