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
print $q->start_html ( -encoding => "UTF-8" );

# パラメータの読み込み
my $diffNum;
my $pageID;
my $result = [];
my $status = 1;
foreach my $name ($q->param) {
    my $val = $q->param ($name);
    if ($name eq 'pageID') {
	if ($val =~ /^[A-Za-z0-9]+$/) {
	    $pageID = $val;
	} else {
	    printf ("bad pageID: %s = %s<br/>\n", $name, $val);
	    $status = 0;
	}
    } elsif ($name eq 'diffNum') {
	$diffNum = int ($val);
    } elsif ($name =~ /^(seg|tag)diff([0-9]+)$/) {
	my $type = $1;
	my $index = $2;
	$val = int ($val);
	if ($val >=0 && $val <= 3) {
	    $result->[$index]->{$type} = $val;
	} else {
	    printf ("parameter out of range: %s = %s<br/>\n", $name, $val);
	    $status = 0;
	}
    } else {
	printf ("unknown parameter: %s = %s<br/>\n", $name, $val);
    }
}


# パラメータの検査
unless ($status) {
    &errorHTML ("FAILED.<br/>")
}
unless (defined ($pageID)) {
    &errorHTML ("pageID was not specified<br/>");
}
unless (defined ($diffNum)) {
    &errorHTML ("diffNum was not specified<br/>");
}
for (my $i = 0; $i < $diffNum; $i++) {
    unless (defined ($result->[$i])) {
	&errorHTML ("$i was not specified<br/>");
    }
    unless (defined ($result->[$i]->{seg})) {
	&errorHTML ("${i}->seg was not specified<br/>");
    }
    unless (defined ($result->[$i]->{tag})) {
	&errorHTML ("${i}->tag was not specified<br/>");
    }
    # segmentation が間違っていれば tag は自動的に誤り
    if (($result->[$i]->{seg} == 2 || $result->[$i]->{seg} == 3) &&
	($result->[$i]->{tag} == 0 || $result->[$i]->{tag} == 1)) {
	&errorHTML ("$i: bad seg-tag agreement.<br/>");
    }
    if (($result->[$i]->{seg} == 1 || $result->[$i]->{seg} == 3) &&
	($result->[$i]->{tag} == 0 || $result->[$i]->{tag} == 2)) {
	&errorHTML ("$i: bad seg-tag agreement.<br/>");
    }
}
unless (scalar (@$result) == $diffNum) {
    &errorHTML ("out of range???<br/>");
}


use Dumpvalue;
print "<pre>\n";
Dumpvalue->new->dumpValue ($result);
print "</pre>\n";

use Storable qw/nstore/;
my $struct = {
    pageID => $pageID,
    result => $result
};
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $path = sprintf ("%s_%04d%02d%02d%02d%02d.storable", $pageID, $year + 1900, $mon + 1, $mday + 1, $hour, $min);
nstore ($struct, $path);

print $q->end_html;

sub errorHTML {
    print ($_[0]);
    print $q->end_html;
    exit;
}
