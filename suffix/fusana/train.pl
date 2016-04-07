#!/bin/env perl
#
# 名詞、ナ形容詞の分類
#
use strict;
use warnings;
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

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { debug => 0, verbose => 1, iter => 10, type => 'pa' };
GetOptions($opt, 'debug', 'verbose=i',
	   'type=s',   # perceptron or pa
	   'input=s',  # input file
	   'output=s', # output file
	   'iter=i',   # num. of iteration
	   'compact',  # rebless
    );
my $SIZE = 4; # 普通名詞, サ変名詞, ナ形容詞, ナノ形容詞

# initialize
my $input = IO::File->new($opt->{input}, 'r') or die;
$input->binmode(($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new($input);

my $model;
if ($opt->{type} eq 'perceptron') {
    $model = MultiClassClassifier::Perceptron->new($SIZE, { debug => $opt->{debug} });
} elsif ($opt->{type} eq 'cw') {
    $model = MultiClassClassifier::ConfidenceWeighted->new($SIZE, { debug => $opt->{debug} });
} else {
    $model = MultiClassClassifier::PassiveAggressive->new($SIZE, { debug => $opt->{debug} });
}
$model->train($exampleList, $opt->{iter});
$exampleList->readClose;
if ($opt->{compact}) {
    if ($model->isa('MultiClassClassifier::ConfidenceWeighted')) {
	delete($model->{covList});
    }
    bless($model, 'MultiClassClassifier');
}
nstore($model, $opt->{output}) or die;

1;
