#!/bin/env perl
#
# クラス分類の評価
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/nstore/;

use ExampleList;
use NaiveBayes;
use NaiveBayes2D;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i',
	    'gs=s',      # gold standard
	    'learned=s',  # data to be evaluated
	    'compressed',
	    );

# initialize
my $filepath1 = $opt->{learned};
my $input1 = IO::File->new ($filepath1, 'r') or die;
$input1->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList1 = ExampleList->new ($input1);

my $filepath2 = $opt->{gs};
my $input2 = IO::File->new ($filepath2, 'r') or die;
$input2->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList2 = ExampleList->new ($input2);


my $idTable = [];
while ((my $example1 = $exampleList1->readNext)) {
    my $example2 = $exampleList2->readNext;

    ExampleList->randomSelect ($example1);
    ExampleList->randomSelect ($example2);

    $idTable->[$example1->{id}]->[$example2->{id}]++;
}
$exampleList1->readClose;
$exampleList2->readClose;

use Dumpvalue;
Dumpvalue->new->dumpValue ($idTable);

&calcAccuracy ($idTable);
&calcDiagAccuracy ($idTable);


sub calcAccuracy {
    my ($idTable) = @_;

    my $total = 0;
    my $correct = 0;
    foreach my $learned (@$idTable) {
	my $max = 0;
	foreach my $gs (@$learned) {
	    $total += $gs;
	    if ($gs > $max) {
		$max = $gs;
	    }
	}
	$correct += $max;
    }
    printf ("accuracy: %f (%d / %d)\n", $correct / $total, $correct, $total);
}

sub calcDiagAccuracy {
    my ($idTable) = @_;

    my $total = 0;
    my $correct = 0;
    for (my $i = 0, my $li = scalar (@$idTable); $i < $li; $i++) {
	my $learned = $idTable->[$i];
	my $max = 0;
	for (my $j = 0, my $lj = scalar (@$learned); $j < $lj; $j++) {
	    my $gs = $learned->[$j];

	    $total += $gs;
	    $correct += $gs if ($i == $j);
	}

    }
    printf ("diag accuracy: %f (%d / %d)\n", $correct / $total, $correct, $total);
}

1;
