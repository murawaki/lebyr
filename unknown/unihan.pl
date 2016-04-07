#!/bin/env perl
#
# Unihan Database から異体字チェック用のデータベースを作成
#
use strict;
use utf8;

use Encode;
use Storable qw /nstore/;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'output=s', 'debug');

my $unihanDB = "/home/murawaki/download/Unihan.txt";
my $outputPath = "/home/murawaki/research/lebyr/data/unihan.storable";
if ($opt->{output}) {
    $outputPath = $opt->{output};
}

my $db1 = {};
my $struct;
my $pC = '';
open (my $file, "<:utf8", $unihanDB);
while (<$file>) {
    next if ($_ =~ /^\#/);

    chomp;
    next unless ($_ =~ /^U\+(\w{4,5})\t(\w+?)\t(.*)/);
    my ($point, $name, $val) = ($1, $2, $3);
    my $c = chr (hex ($point));

    # flush
    if ($pC ne $c) {
	# JIS の文字だけを対象にする
	if ($struct->{kJis0} || $struct->{kJis1}) {
	    $db1->{$pC} = $struct;
	}

	$struct = {};
	$pC = $c;
    }
    $struct->{$name} = $val;
}
close ($file);


my $db = {};
my $c;
while (($c = each (%$db1))) {
    my $struct = $db1->{$c};

    if ($struct->{kTraditionalVariant}) {
	my $list = [];
	foreach my $tmp (split (/ /, $struct->{kTraditionalVariant})) {
	    my $c2 = substr ($tmp, 2);
	    $c2 = chr (hex ($c2));
	    if (defined ($db1->{$c2})) {
		$db->{$c}->{$c2} = 'T';
	    }
	}
    }
    if ($struct->{kSimplifiedVariant}) {
	my $list = [];
	foreach my $tmp (split (/ /, $struct->{kSimplifiedVariant})) {
	    my $c2 = substr ($tmp, 2);
	    $c2 = chr (hex ($c2));

	    if (defined ($db1->{$c2})) {
		$db->{$c}->{$c2} = 'S';
	    }
	}
    }
    if ($struct->{kZVariant}) {
	my $list = [];
	foreach my $tmp (split (/ /, $struct->{kZVariant})) {
	    my $c2 = substr ($tmp, 2);
	    $c2 = chr (hex ($c2));

	    if (defined ($db1->{$c2})) {
		$db->{$c}->{$c2} = 'Z';
	    }
	}
    }
}
# 反対側も整備
while (($c = each (%$db))) {
    foreach my $c2 (keys (%{$db->{$c}})) {
	unless (defined ($db->{$c2}) && defined ($db->{$c2}->{$c})) {
	    $db->{$c2}->{$c} = ($db->{$c}->{$c2} eq 'Z')? 'Z2' : (($db->{$c}->{$c2} eq 'T')? 'S2' : 'T2');
	}
    }
}

nstore ($db, $outputPath) or die;


1;
