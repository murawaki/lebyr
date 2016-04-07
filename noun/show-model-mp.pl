#!/bin/env perl
#
# 素性データを表示
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use Storable qw/retrieve nstore/;

use MultiClassClassifier::Perceptron;
use MultiClassClassifier::AveragedPerceptron;
use MultiClassClassifier::PassiveAggressive;
use MultiClassClassifier::ConfidenceWeighted;
use NounCategorySpec;
require 'common.pl';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $ABS_SUM_THRES = 0.00001;
my $CF_LENGTH = 50;
my $opt = { verbose => 1, scale => 1.0 };
GetOptions ($opt, 'debug', 'verbose=i', 'model=s', 'fDB=s', 'normal', 'length=i', 'scale=f', 'compact');

unless ($opt->{length}) {
    my $nounCat = NounCategorySpec->new;
    $opt->{length} = $nounCat->LENGTH;
}

my $fDB = retrieve ($opt->{fDB}) or die;
my $id2feature = [];
foreach my $type (keys (%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each (%$p))) {
	$id2feature->[$p->{$key}] = "$type:$key";
    }
}
undef ($fDB);

my $scale = $opt->{scale};
my $size = scalar (@$id2feature);
my $model = retrieve ($opt->{model}) or die;
my $weightList = $model->{weightList};
for (my $i = 0; $i < $size; $i++) {
    my $str = $id2feature->[$i] . ' ';
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
	my $absSum = 0;
	my $sum = 0;
	for (my $j = 0; $j < $opt->{length}; $j++) {
	    my $v = $weightList->[$j]->[$i] || 0;
	    $sum += $v;
	    $absSum = abs($v);
	}
	next if ($opt->{compact} && $absSum < $ABS_SUM_THRES);
	my $offset = $sum / $opt->{length};
	for (my $j = 0; $j < $opt->{length}; $j++) {
	    $str .= (sprintf ("%.2f", $scale * ($weightList->[$j]->[$i] || 0) - $offset)) . "\t";
	}
    } else {
	for (my $j = 0; $j < $opt->{length}; $j++) {
	    $str .= (sprintf ("%.2f", $scale * $weightList->[$j]->[$i] || 0)) . "\t";
	}
    }
    print ("$str\n");
}

1;
