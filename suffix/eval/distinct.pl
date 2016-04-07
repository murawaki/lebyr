#!/bin/env perl
#
# 品詞の識別に利用できるサフィックスを探す
#

use strict;
use utf8;

# use Encode;
use Getopt::Long;
# use KNP::Result; # Storable のために自分で load
# use KNP::Morpheme;
use Juman::Morpheme;
use Storable qw (retrieve nstore);
use MorphemeGrammar qw ($posList);

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug', 'input=s');

my $suffixListFile = "/home/murawaki/research/lebyr/data/suffixThres";
my $distributionFile = "/home/murawaki/research/lebyr/data/distribution.storable";
my $distinctFile = "/home/murawaki/research/lebyr/data/distinct.storable";
my $distinctRateFile = "/home/murawaki/research/lebyr/data/distinctRate.storable";


my $distribution = retrieve ($distributionFile) or die;
my ($distributionRatio, $distributionTotal) = &initDistribution ($distribution);

my $minimumRate = 1e-5;

use Dumpvalue;
# die unless ( -f $opt{input} );
# my $undefFile = $opt{input};

warn ("now loading suffix data...\n") if (defined ($opt{debug}));
my ($suffixMap, $sortedSuffixList) = &init ($suffixListFile);
warn ("done\n") if (defined ($opt{debug}));


my @posSNameList = keys (%$posList);

my $distinctSuffixList = {};
# &getDistinctSuffixes ('普通名詞', 'ナ形容詞');
# &getDistinctSuffixes ('普通名詞', 'サ変名詞');
# &getDistinctSuffixes ('ナ形容詞', 'サ変名詞');
# &getDistinctSuffixes ('子音動詞ワ行', '母音動詞');
# &getDistinctSuffixes ('子音動詞ラ行', '母音動詞');
# exit;

# foreach (my $i = 0; $i < scalar (@posSNameList) - 1; $i++) {
#     foreach (my $j = $i + 1; $j < scalar (@posSNameList); $j++) {
# 	warn ("\n\n########################################\n\n");
# 	warn ("$posSNameList[$i] vs. $posSNameList[$j]\n");

# 	&getDistinctSuffixes ($distinctSuffixList, $posSNameList[$i], $posSNameList[$j]);
#     }
# }

&makeDistinctSuffixes ($distinctSuffixList);
print STDERR ("\n");
# use Dumpvalue;
# print Dumpvalue->new->dumpValue ($distinctSuffixList), "\n";
nstore ($distinctSuffixList, $distinctFile) or die;

my $rate = &calcDistinctRate ($distinctSuffixList);
nstore ($rate, $distinctRateFile) or die;


sub makeDistinctSuffixes {
    # my ($distinctSuffixList, $posS1, $posS2) = @_;
    my ($distinctSuffixList) = @_;

    for (my $i = 0; $i < scalar (@$sortedSuffixList); $i++) {

	unless ($i % 100) {
	    print STDERR ("#");
	    # flush STDERR;
	}

	my $suffix = $sortedSuffixList->[$i];

	my $posSList = {};
	my $countAll = 0;
	foreach my $tmp (@{$suffixMap->{$suffix}}) {
	    my ($posS, $katuyou2, $count) = @$tmp;
	    $posSList->{$posS} = [$katuyou2, $count];
	    $countAll += $count;
	}

	next if ($countAll < 100);

	foreach my $posS1 (keys (%$posSList)) {
	    next unless ($posSList->{$posS1}->[1] > $distributionTotal->{$posS1} * $minimumRate);

	    foreach (my $j = 0; $j < scalar (@posSNameList); $j++) {
		my $posS2 = $posSNameList[$j];
		next if ($posS1 eq $posS2);
		next if (defined ($posSList->{$posS2}));

		$distinctSuffixList->{$posS1}->{$posS2}->{$suffix} = $posSList->{$posS1}->[1] / $distributionTotal->{$posS1};
	    }
	}

# 	if (defined ($posSList->{$posS1}) && !defined ($posSList->{$posS2})) {
# 	    # printf ("%s\t%s\t%d\n", $posS1, $suffix, $posSList->{$posS1}->[1])
# 	    if ($posSList->{$posS1}->[1] > $distributionTotal->{$posS1} * $minimumRate) {
# 		$distinctSuffixList->{$posS1}->{$posS2}->{$suffix} = $posSList->{$posS1}->[1] / $distributionTotal->{$posS1};
# 	    }
# 	} elsif (!defined ($posSList->{$posS1}) && defined ($posSList->{$posS2})) {
# 	    # printf ("%s\t%s\t%d\n", $posS2, $suffix, $posSList->{$posS2}->[1])
# 	    if ($posSList->{$posS2}->[1] > $distributionTotal->{$posS2} * $minimumRate) {
# 		$distinctSuffixList->{$posS2}->{$posS1}->{$suffix} = $posSList->{$posS2}->[1] / $distributionTotal->{$posS2};
# 	    }
# 	}
    }
}

sub calcDistinctRate {
    my ($distinctSuffixList) = @_;

    my @rateArray = ();

#     foreach my $posS1 (keys (%$distinctSuffixList)) {
# 	foreach my $posS2 (keys (%{$distinctSuffixList->{$posS1}})) {
    foreach (my $i = 0; $i < scalar (@posSNameList); $i++) {
	my $posS1 = $posSNameList[$i];
	foreach (my $j = 0; $j < scalar (@posSNameList); $j++) {
	    next if ($i == $j);
	    my $posS2 = $posSNameList[$j];

	    unless (defined ($distinctSuffixList->{$posS1}->{$posS2})) {
		$distinctSuffixList->{$posS1}->{$posS2} = 0;

		push (@rateArray, [$posS1, $posS2, 0]);
		next;
	    }

	    my $sum = 0;
	    my $suffix;
	    while (($suffix = each (%{$distinctSuffixList->{$posS1}->{$posS2}}))) {
		$sum += $distinctSuffixList->{$posS1}->{$posS2}->{$suffix};
	    }

	    # printf ("%s -> %s:\t%f\n", $posS1, $posS2, $sum);
	    push (@rateArray, [$posS1, $posS2, $sum]);
	}
    }

    my @sortedRateArray = sort { $a->[2] <=> $b->[2] } (@rateArray);
    my $rv = {};
    foreach my $tmp (@sortedRateArray) {
	my ($posS1, $posS2, $sum) = @$tmp;
	$rv->{$posS1}->{$posS2} = $sum;

	printf ("%s -> %s:\t%f\n", $posS1, $posS2, $sum);
    }
    return $rv;
}



# suffix のデータベースを作る
sub init {
    my ($suffixListFile) = @_;

    my $totalCount = 0;

    my $suffixMap = {};
    my $sortedSuffixList = [];

    my $suffix;
    my $struct;
    open (my $file, "<:utf8", $suffixListFile) or die;
    while (<$file>) {
	chomp;

	if ($_ =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);
	    push (@{$struct->{$posS}}, [$katuyou2, $count]);

	    $totalCount += $count;
	} else {
	    if (defined ($suffix)) {
		&flushOldSuffix ($suffixMap, $suffix, $struct);
	    }
	    $suffix = $_;
	    $struct = {};
	    push (@$sortedSuffixList, $suffix);
	}
    }
    close ($file);
    &flushOldSuffix ($suffixMap, $suffix, $struct);

    print ("totalCount: $totalCount\n");

    return ($suffixMap, $sortedSuffixList);
}


sub flushOldSuffix {
    my ($suffixMap, $suffix, $struct) = @_;

    foreach my $posS (keys (%$struct)) {
	my $maxI = 0;
	if (scalar (@{$struct->{$posS}}) > 1) {
	    # 一番出現回数の多い活用形に決める
	    my $max = 0;
	    for (my $i = 0; $i < scalar (@{$struct->{$posS}}); $i++) {
		if ($struct->{$posS}->[$i]->[1] > $max) {
		    $max = $struct->{$posS}->[$i]->[1];
		    $maxI = $i;
		}
	    }
	}
	my ($katuyou2, $count) = @{$struct->{$posS}->[$maxI]};
	push (@{$suffixMap->{$suffix}}, [$posS, $katuyou2, $count]);
    }
}

sub initDistribution {
    my ($distribution) = @_;

    my $distributionRatio = {};
    my $distributionTotal = {};

    foreach my $posS (keys (%$distribution)) {
	my $sum = 0;
	foreach my $katuyou2 (keys (%{$distribution->{$posS}})) {
	    $sum += $distribution->{$posS}->{$katuyou2};
	}
	foreach my $katuyou2 (keys (%{$distribution->{$posS}})) {
	    $distributionRatio->{$posS}->{$katuyou2} = $distribution->{$posS}->{$katuyou2} / $sum;
	}

	print ("total number: $posS:\t$sum\n");
	$distributionTotal->{$posS} = $sum;
    }
    return ($distributionRatio, $distributionTotal);
}


1;
