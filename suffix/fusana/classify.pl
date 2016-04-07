#!/bin/env perl
#
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
# use SuffixList;
# my $suffixListPath = '/home/murawaki/research/lebyr/data';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'compressed', 'model=s', 'fDB=s', 'show-all', 'matrix');
my $SIZE = 4;

my $model = retrieve ($opt->{'model'}) or die;
# my $suffixList = SuffixList->new ($suffixListPath);

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);

my $matrix = [];
my $total = 0; my $error = 0;
my $rigid = 0; my $category = 0;
while ((my $example = $exampleList->readNext)) {
    $total++;

    my $idAnswer = $example->{id};
    my $vList = $model->classify ($example);
    my $idResult = $model->getMax ($vList);
    $matrix->[$idResult]->[$idAnswer]++;

    if ($opt->{verbose} >= 1 && ($opt->{'show-all'} || $idAnswer != $idResult)) {
	printf ("%s\t%s\t%s\t%s\n",
		$example->{name},
		$idAnswer, $idResult,
		join (" ", map { sprintf ("%.2f", $_) } (@$vList)));

    }
    if ($idAnswer != $idResult) {
	$error++;
    }
}
$exampleList->readClose;

if ($opt->{verbose} >= 1) {
    printf ("%d / %d (%f)\n", $total - $error, $total, ($total - $error) / $total);
}

if ($opt->{matrix}) {
    foreach my $i (0 .. $SIZE - 1) {
	my $line = '';
	foreach my $j (0 .. $SIZE - 1) {
	    $line .= ($matrix->[$i]->[$j] || 0) . "\t";
	}
	chomp ($line);
	print ("$line\n");
    }
}

1;
