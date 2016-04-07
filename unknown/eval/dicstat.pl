#!/bin/env perl
#
# JUMAN の辞書に関する統計情報を出す
#
use strict;
use utf8;

use Encode;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $file = $ARGV[0];
$file = "$file/output.dic" if ( -d $file );
die unless ( -f $file );

open (my $fh, "<:encoding(euc-jp)", $file) or die;

my $countStartList = [];
my $midasiCount = 0;
my $katakanaCount = 0;
my $nounCount = 0;
while ((my $line = <$fh>)) {
    if ($line =~ /^; countStart/) {
	push (@$countStartList, (split (/\s+/, $line))[2]);
    }
    next if ($line =~ /^\;/);

    if ($line =~ /\(見出し語 ([^\)]*)\)/) {
	my $midasi = $1;
	$midasiCount++;
	if ($midasi =~ /^(\p{Katakana}|ー)*$/) {
	    $katakanaCount++;
	}
	if ($line =~ /^\(名詞/) {
	    $nounCount++;
	}
    }
}
close ($fh);

my @sorted = sort { $a <=> $b } (@$countStartList);
my $medianCountStart = $sorted[int ($#sorted / 2)];

printf ("total\t\t\t%d\n", $midasiCount);
printf ("countStart (median)\t%d\n", $medianCountStart);
printf ("katakana\t\t%d / %d\t%f\n", $katakanaCount, $midasiCount, $katakanaCount * 100 / $midasiCount);
printf ("noun\t\t\t%d / %d\t%f\n", $nounCount, $midasiCount, $nounCount * 100 / $midasiCount);

1;
