#!/bin/env perl
#
# train multiclass perceptron
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use ExampleList;
use ExampleList::Cached;
use MultiClassClassifier::Perceptron;
use MultiClassClassifier::AveragedPerceptron;
use MultiClassClassifier::PassiveAggressive;
use MultiClassClassifier::ConfidenceWeighted;
use MultiClassClassifier::FactoredMatrix;
use NounCategorySpec;
# require 'common.pl';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { debug => 0, verbose => 1, discardAmbiguity => 1, type => 'pa' };
GetOptions ($opt, 'debug', 'verbose=i',
	    'input=s',      # input file
	    'init=s',
	    'iter=i',       # num. of iteration
	    'type=s',
	    'length=i',
	    'compressed',
	    'discardAmbiguity',
	    'output=s',     # output Naive Bayes classifier after training
	    'tmpDataDir=s', # write temp. training data to hard disk
	    'compact',
	    );

unless (defined ($opt->{length})) {
    my $nounCat = NounCategorySpec->new;
    $opt->{length} = $nounCat->LENGTH;
}

my $iterNum = ($opt->{iter})? $opt->{iter} : 100;

my $model;
if ($opt->{init}) {
    $model = retrieve($opt->{init}) or die;
} else {
    if ($opt->{type} eq 'mp') {
	$model = MultiClassClassifier::Perceptron->new ($opt->{length}, { debug => $opt->{debug} });
    } elsif ($opt->{type} eq 'map') {
	$model = MultiClassClassifier::AveragedPerceptron->new ($opt->{length}, { debug => $opt->{debug} });
    } elsif ($opt->{type} eq 'pa') {
	$model = MultiClassClassifier::PassiveAggressive->new ($opt->{length}, { debug => $opt->{debug} });
    } elsif ($opt->{type} eq 'cw') {
	$model = MultiClassClassifier::ConfidenceWeighted->new ($opt->{length}, { debug => $opt->{debug} });
    } elsif ($opt->{type} eq 'fm') {
	$model = MultiClassClassifier::FactoredMatrix->new ($opt->{length}, { k => 100, lambda => 0.01, PC => 0.0001, debug => $opt->{debug} });
    } else {
	die;
    }
}

# $model->train ($exampleList, $iterNum);
for (my $i = 0; $i < $iterNum; $i++) {
    my $filepath = $opt->{input};
    my $input = IO::File->new (($opt->{compressed})? "bzip2 -dc $filepath |" : $filepath) or die;
    # my $input = IO::File->new ($filepath, 'r') or die;
    # $input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
    $input->binmode (':utf8');
    my $exampleList = ExampleList->new ($input);

    my $correct = 0;
    my $total = 0;
    while ((my $example = $exampleList->readNext)) {
	$total++;
	$correct += $model->trainStep ($example);
    }
    $exampleList->readClose;

    if ($opt->{debug}) {
	printf STDERR ("iter %d:\t%f%% (%d / %d)\n", $i, $correct / $total, $correct, $total);
    }
}

if ($opt->{compact}) {
    $model->compact;
}

nstore ($model, $opt->{output}) or die;

1;
