#!/bin/env perl
#
# NaiveBayes の実行の差分
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use NaiveBayes;
use NaiveBayes2D;
use NounCategory;
use ExampleList;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'compressed', 'nb1=s', 'nb2=s', 'id2feature=s');

my $nb1;
unless ($opt->{'nb1'} eq 'orig') {
    $nb1 = retrieve ($opt->{'nb1'}) or die;
}
my $nb2 = retrieve ($opt->{'nb2'}) or die;
my $id2feature = retrieve ($opt->{id2feature}) or die;

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);
my $total = 0; my $diff = 0;
while ((my $example = $exampleList->readNext)) {
    $total++;

    my $r1;
    unless ($opt->{'nb1'} eq 'orig') {
	$r1 = $nb1->classifyMax ($example);
    } else {
	$r1 = ExampleList->randomSelect ($example)->{id};
    }
    my $r2 = $nb2->classifyMax ($example);

    if ($r1 != $r2) {
	$diff++;
	printf ("%s\t%s\t%s\t\t%s\n\n",
		$example->{name},
		&NounCategory::getClassNameFromIndex ($r1),
		&NounCategory::getClassNameFromIndex ($r2),
		join ("\t", (map { $id2feature->[(split (/\:/, $_))[0]] } (@{$example->{featureList}}) )) );
    }
}
$exampleList->readClose;

printf ("%d / %d (%f)\n", $diff, $total, $diff / $total);

1;
