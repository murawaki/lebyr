#!/bin/env perl
#
# merge multiclass perceptrons for parallel processing
#   see Distributed Training Strategies for the Structured Perceptron by Ryan McDonald+
#   use the uniform mixture for simplicity
#
use strict;
use warnings;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use IO::Dir;
# use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use MultiClassClassifier::Perceptron;
use MultiClassClassifier::AveragedPerceptron;
use NounCategorySpec;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { debug => 0, verbose => 1, type => 'map' };
GetOptions($opt, 'debug', 'verbose=i',
	   'dir=s', # store temporary model files
	   'prefix=s',
	   'type=s',
	   'length=i',
	   'output=s',
	   'compact',
    );

unless (defined($opt->{length})) {
    my $nounCat = NounCategorySpec->new;
    $opt->{length} = $nounCat->LENGTH;
}

my $d = IO::Dir->new($opt->{dir}) or die;
my $modelPathList = [];
foreach my $ftmp (sort {$a cmp $b} ($d->read)) {
    if ($ftmp =~ /^(.*)\.(mp|map)$/) {
	if (!$opt->{prefix} || $ftmp =~ /^\Q$opt->{prefix}\E/) {
	    push(@$modelPathList, $opt->{dir} . '/' .$ftmp);
	}
    }
}
$d->close;
my $modelCount = scalar(@$modelPathList);

my $model;
if ($opt->{type} eq 'mp') {
    $model = MultiClassClassifier::Perceptron->new($opt->{length}, { debug => $opt->{debug} });
} elsif ($opt->{type} eq 'map') {
    $model = MultiClassClassifier::AveragedPerceptron->new($opt->{length}, { debug => $opt->{debug} });
}
foreach my $modelPath (@$modelPathList) {
    my $model2 = retrieve($modelPath) or die;
    for (my $y = 0; $y < $opt->{length}; $y++) {
	my $weightList = $model->{weightList}->[$y];
	my $weightList2 = $model2->{weightList}->[$y];
	my $size = $model->{size};
	for (my $i = 0, my $l = scalar(@$weightList2); $i < $l; $i++) {
	    no warnings qw/uninitialized/;

	    $weightList->[$i] += ($weightList2->[$i] || 0) / $modelCount;
	}
    }
    printf STDERR ("%s merged\n", $modelPath) if ($opt->{debug});
}


if ($opt->{compact}) {
    $model->compact;
}

nstore($model, $opt->{output}) or die;

1;
