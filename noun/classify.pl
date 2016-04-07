#!/bin/env perl
#
# classify with a given model
#
use strict;
use warnings;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;
use Statistics::Distributions;

use MultiClassClassifier::Perceptron;
use MultiClassClassifier::AveragedPerceptron;
use MultiClassClassifier::PassiveAggressive;
use MultiClassClassifier::ConfidenceWeighted;
use NounCategorySpec;
use ExampleList;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions($opt, 'debug', 'verbose=i', 'input=s', 'compressed', 'model=s', 'fDB=s',
	   'length=i',
	   'show-all', 'agg', 'matrix');

my $nounCat = NounCategorySpec->new;
$opt->{length} = $nounCat->LENGTH;
my $otherID = 4; # COMMON_OTHER
my $resultCount = 0;
my $answerCount = 0;
my $correctCount = 0;
my $countB = 0;
my $countC = 0;

my $nb = retrieve($opt->{'model'}) or die;
my $fDB = retrieve($opt->{fDB}) or die;
my $id2feature = [];
foreach my $type (keys(%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each(%$p))) {
	$id2feature->[$p->{$key}] = "$type:$key";
    }
}
undef($fDB);

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new($filepath, 'r') or die;
$input->binmode(($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new($input);

my $total = 0; my $error = 0;

my $idAnswerDist = [];
my $results = {}; my $matrix = [];
while ((my $example = $exampleList->readNext)) {
    $total++;

    my $idAnswer = $example->{id};
    $idAnswerDist->[$idAnswer]++;
    # my $idResult = $nb->classifyMax($example);
    my $vList = $nb->classify($example);
    my $idResult = $nb->getMax($vList);
    $results->{$example->{name}}->[$idResult]++;
    $matrix->[$idResult]->[$idAnswer]++;

    $answerCount++ if ($idAnswer != $otherID);
    $resultCount++ if ($idResult != $otherID);
    $correctCount++ if ($idAnswer == $idResult && $idAnswer != $otherID);
    $countB++ if ($idAnswer != $idResult && $idAnswer == $otherID);
    $countC++ if ($idAnswer == $idResult && $idAnswer != $otherID);


    if ($opt->{verbose} >= 1 && ($opt->{'show-all'} || $idAnswer != $idResult)) {
	my ($labelAnswer, $labelResult);
	$labelAnswer = $nounCat->getClassFromID($idAnswer);
	$labelResult = $nounCat->getClassFromID($idResult);

	printf("%s\t%s\t%s\t\t%s\n\n",
	       $example->{name}, $labelAnswer, $labelResult,
	       join("\t", (map { $id2feature->[$_->[0]] } (@{$example->{featureList}}) )) );
	if ($opt->{verbose} >= 2) {
	    printf("%s\n", join(" ", map { sprintf ('%.2f', $_) } (@$vList)));
	    # printf ("%s\n", join (" ", @{&softmax ($vList)}));
	}
    }
    if ($idAnswer != $idResult) {
	$error++;
    }
}
$exampleList->readClose;

my $idAnswerMax = 0; my $idAnswerVal = $idAnswerDist->[0];
for (my $i = 1; $i < scalar(@$idAnswerDist); $i++) {
    if ($idAnswerVal < $idAnswerDist->[$i]) {
	$idAnswerMax = $i;
	$idAnswerVal = $idAnswerDist->[$i];
    }
}

if ($opt->{agg}) {
    while ((my $name = each(%$results))) {
	my @tmp = 0 .. $opt->{length} - 1;
	my $list = $results->{$name};
	my $sum = 0; map { $sum += $_ } (@$list);
	@tmp = sort { ($list->[$b] || 0) <=> ($list->[$a] || 0) } (@tmp);
	printf("%s\t%d\t%s\n", $name, $sum,
	       join("\t", map { if ($list->[$_]) { $nounCat->getClassFromID($_) . ' ' . (sprintf("%4f", $list->[$_] / $sum)) } } (@tmp)));
    }
}

if ($opt->{matrix}) {
    foreach my $i (0 .. $opt->{length} - 1) {
	my $line = '';
	foreach my $j (0 .. $opt->{length} - 1) {
	    $line .= ($matrix->[$i]->[$j] || 0) . "\t";
	}
	chomp($line);
	print("$line\n");
    }
}

if ($opt->{verbose} >= 1) {
    printf("baseline: %d / %d (%f)\n", $idAnswerVal, $total, $idAnswerVal / $total);
    printf("proposed: %d / %d (%f)\n\n", $total - $error, $total, ($total - $error) / $total);
    printf("B: %d, C: %d\n", $countB, $countC);
    my $chis = &Statistics::Distributions::chisqrprob(1, (($countB - $countC) ** 2) / ($countB + $countC));
    printf("McNemar's text: %f\n", $chis);

    printf("precision: %d / %d (%f)\n", $correctCount, $resultCount, $correctCount / $resultCount);
    printf("recall: %d / %d (%f)\n", $correctCount, $answerCount, $correctCount / $answerCount);
    printf("F-score: %f\n", ($correctCount > 0)? (2 / (($resultCount / $correctCount) + ($answerCount / $correctCount))) : -1 );
}

sub softmax {
    my ($xs) = @_;

    my $a = 711.0;
    foreach my $v (@$xs) {
	$a = $v if ($v > $a);
    }
    my $Z = 0;
    my $rv = [];
    foreach my $v (@$xs) {
	my $ev = exp($v - $a);
	push (@$rv, $ev);
	$Z += $ev;
    }
    foreach my $v (@$xs) {
	$v /= $Z;
    }
    return $rv;
}

1;
