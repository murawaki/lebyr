#!/bin/env perl
#
# 素性データを表示
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use MultiClassClassifier::Perceptron;
use MultiClassClassifier::PassiveAggressive;
use SuffixList;

my $suffixListPath = '/home/murawaki/research/lebyr/data';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $CF_LENGTH = 10;
my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'model=s', 'normal');
my $SIZE = 4;
my $suffixList = SuffixList->new ($suffixListPath);

my $size = $suffixList->getTotal;
my $mp = retrieve ($opt->{model}) or die;
my $weightList = $mp->{weightList};
for (my $i = 0; $i < $size; $i++) {
    my $str = $suffixList->getSuffixByID ($i);
    my $length;
    {
	use bytes;
	use Encode qw/encode/;
	$length = length (encode ('euc-jp', $str));
    };
    for (my $j = $length; $j < $CF_LENGTH; $j++) {
	$str .= ' ';
    }
    if ($opt->{normal}) {
	my $sum = 0;
	my $flag = 0;
	for (my $j = 0; $j < $SIZE; $j++) {
	    $sum += $weightList->[$j]->[$i] || 0;
	    $flag = 1 if (defined ($weightList->[$j]->[$i]));
	}
	next unless ($flag);
	my $offset = $sum / $SIZE;
	for (my $j = 0; $j < $SIZE; $j++) {
	    $str .= (sprintf ("% 6f", ($weightList->[$j]->[$i] || 0) - $offset)) . "\t";
	}
    } else {
	my $flag = 0;
	for (my $j = 0; $j < $SIZE; $j++) {
	    $str .= (sprintf ("% 6f", $weightList->[$j]->[$i] || 0)) . "\t";
	    $flag = 1 if (defined ($weightList->[$j]->[$i]));
	}
	next unless ($flag);
    }
    print ("$str\n");
}

1;
