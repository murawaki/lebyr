#!/bin/env perl
#
# 精度と頻度の関係を調査
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
use MultiClassClassifier::ConfidenceWeighted;
use ExampleList;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1, thres => 100 };
my $inputList = [];
GetOptions ($opt, 'input=s{4}' => $inputList, 'debug', 'verbose=i', 'data=s', 'compressed', 'model=s');
# index
#   普通名詞: 0
#   サ変名詞: 1
#   ナ形容詞: 2
#   ナノ形容詞: 3
my $SIZE = 4;
my $thres = $opt->{thres};

print STDERR ("loading raw data") if ($opt->{debug});
my $dataList = [];
my $LOG10 = log (10);
my $index = 0;
foreach my $input (@$inputList) {
    my $instanceList = retrieve ($input) or die;
    print STDERR (".") if ($opt->{debug});
    my $posList = $dataList->[$index++] = {};

    my $count = 0;
    while ((my $genkei = each (%$instanceList))) {
	my $list = $instanceList->{$genkei};
	my $sum = 0;
	foreach my $suffix (keys (%$list)) {
	    $sum += $list->{$suffix};
	}
	next unless ($sum > $thres);
	$posList->{$genkei} = int (log ($sum) / $LOG10); # WARNING: inaccurate
    }
}
print STDERR ("done\n") if ($opt->{debug});

my $model = retrieve ($opt->{'model'}) or die;

# initialize
my $filepath = $opt->{data};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);

my $accGroup = [];
while ((my $example = $exampleList->readNext)) {
    my $idAnswer = $example->{id};
    my $vList = $model->classify ($example);
    my $idResult = $model->getMax ($vList);

    my $group = $dataList->[$idAnswer]->{$example->{name}};
    $accGroup->[$group]->[($idAnswer == $idResult)? 1 : 0 ]++;
}
$exampleList->readClose;

# use Dumpvalue;
# Dumpvalue->new->dumpValue ($accGroup);
foreach my $f (@$accGroup) {
    my $d = $accGroup->[$f];
    next unless ($d);
    printf ("%d\t%f\t#\t%d\t%d\n", 10 ** int ($f), $d->[1] / ($d->[0] + $d->[1]), $d->[0], $d->[1]);
}

1;
