#!/bin/env perl
#
# 混ぜて訓練データを作る
# WARNING: HIGHLY MEMORY CONSUMING
#
use strict;
use utf8;

use Getopt::Long;
use Storable qw (retrieve nstore);
# use List::Util qw/shuffle/;
use SuffixList;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $MAX_SUFFIX_LENGTH = 4;
my $suffixListPath = '/home/murawaki/research/lebyr/data';

my $opt = { index => 0, thres => 0 };
my $inputList = [];
GetOptions ($opt, 'input=s{4}' => $inputList, 'debug', 'thres=i');
# index
#   普通名詞: 0
#   サ変名詞: 1
#   ナ形容詞: 2
#   ナノ形容詞: 3

my $suffixList = SuffixList->new ($suffixListPath);

my $fcount = 0;
my $rv = [];
my $index = 0; my $thres = $opt->{thres};
foreach my $input (@$inputList) {
    my $instanceList = retrieve ($input) or die;
    printf STDERR ("loading done\n") if ($opt->{debug});

    my $count = 0;
    while ((my $genkei = each (%$instanceList))) {
	my $list = $instanceList->{$genkei};
	my $sum = 0;
	foreach my $suffix (keys (%$list)) {
	    $sum += $list->{$suffix};
	}
	next unless ($sum > $thres);

	my $fstring = '';
	foreach my $suffix (keys (%$list)) {
	    my $fid = $suffixList->getIDBySuffix ($suffix);
	    unless (defined ($fid)) {
		printf STDERR ("suffix has no id: %s\n", $suffix);
		next;
	    }
	    $fstring .= sprintf ("\t%d:%f", $fid, $list->{$suffix} / $sum);
	}	
	push (@$rv, sprintf ("%s\t%d%s\n", $genkei, $index, $fstring));

	printf STDERR ('.') if ($opt->{debug} && !(++$count % 50));
    }
    printf STDERR ("\n") if ($opt->{debug});
    $index++;
}

# shuffle
printf STDERR ("shuffle\n") if ($opt->{debug});
my $length = scalar (@$rv);
foreach my $i (1..10000000) {
    my $p = int (rand ($length));
    my $q;
    while (($q = int (rand ($length))) == $p) {}
    my $tmp = $rv->[$p];
    $rv->[$p] = $rv->[$q];
    $rv->[$q] = $tmp;

    printf STDERR ('.') if ($opt->{debug} && !($i % 10000));
}

foreach my $v (@$rv) {
    print ($v);
}

1;
