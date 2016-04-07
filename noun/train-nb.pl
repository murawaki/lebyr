#!/bin/env perl
#
# train naive bayes
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

my $opt = { type => 'em', verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i',
	    'type=s',       # training type: gibbs or em
	    'input=s',      # input file
	    'iter=i',       # num. of iteration
	    'rigid',        # common vs. proper noun
	    'category',     # 4 categories
	    '2d',           # two-way classification
	    'compressed',
	    'output=s',     # output Naive Bayes classifier after training
	    'outputInit=s', # output Naive Bayes classifier before training
	    'trainedData=s',# output training data after training
	    'tmpDataDir=s', # write temp. training data to hard disk
	    'randomInit',   # randomly initialize example id
	    'distlog=s',    # output id distribution log
	    );

my $iterNum = ($opt->{iter})? $opt->{iter} : 100;

# globalvars
my $list = []; my $listCounter = 0; # example list
my ($readTmpPath, $writeTmpPath);
my $nb = &initNB;

my $distlog;
if ($opt->{distlog}) {
    $distlog = IO::File->new ($opt->{distlog}, 'w') or die;
}


# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);
my $idDist = [];
my $total;
&iterInit (-1);
while ((my $example = $exampleList->readNext)) {
    if ($opt->{randomInit}) {
	&randomInit ($example);
    } else {
	ExampleList->randomSelect ($example);
	if ($opt->{rigid}) {
	    $example->{id} = (split (/\:/, &NounCategory::index2classID ($example->{id})))[0];
	} elsif ($opt->{category}) {
	    $example->{id} = (split (/\:/, &NounCategory::index2classID ($example->{id})))[1];
	}
    }
    $idDist->[$example->{id}]++;

    $total++;
    &addExample ($example);
    $nb->addExample ($example);
}
&flushIDDist ($idDist) if ($opt->{distlog});
$exampleList->readClose;

if ($opt->{outputInit}) {
    nstore ($nb, $opt->{outputInit}) or die;
}


my $count = 0;

$|++;
for (my $i = 0; $i < $iterNum; $i++) {
    $count = 0;
    $idDist = [];

    &iterInit ($i);
    my $nb2 = &initNB if ($opt->{type} eq 'em');
    while ((my $example = &iterNext)) {
	my $oldId = $example->{id};

	if ($opt->{type} eq 'em') {
	    $nb->updateByEM ($example, $nb2);
	} else {
	    $nb->updateBySampling ($example);
	}
	my $newId = $example->{id};
	$count++ if ($oldId ne $newId);

	$idDist->[$example->{id}]++;
	if ($opt->{debug} && $oldId ne $newId) {
	    printf ("%d\tchange %s: %s -> %s\n", $i, $example->{name}, $oldId, $newId);
	}
	&iterChange ($example);
    }
    $nb = $nb2 if ($opt->{type} eq 'em');

    &iterReset;
    &flushIDDist ($idDist) if ($opt->{distlog});
    printf ("%f\n", $count / $total);
    # print (".") unless ($i % 10);
}
print ("\n");

nstore ($nb, $opt->{output}) or die;

if ($opt->{trainedData}) {
    if ($opt->{tmpDataDir}) {
	`mv $writeTmpPath $opt->{trainedData}`;
    } else {
	my $filepath = $opt->{trainedData};
	my $trainedData = IO::File->new ($filepath, 'w') or die;
	$trainedData->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
	$exampleList->setOStream ($trainedData);
	foreach my $example (@$list) {
	    $exampleList->writeNext ($example);
	}
	$exampleList->writeClose;
    }
}
if ($opt->{tmpDataDir}) {
    unlink ($writeTmpPath);
}

# print ("second\n");
# &classifyList ($list);


# $exampleList->writeClose;
undef ($exampleList);
if ($opt->{distlog}) {
    $distlog->close;
}


# my $output = IO::File->new ($filepath . "output", 'w') or die;
# $output->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
# $exampleList->setOStream ($output);
# classify

sub initNB {
    if ($opt->{'2d'}) {
	return NaiveBayes2D->new ({ classSize => 8 });
    } else {
	my $nbOpt = { classSize => 8 };
	if ($opt->{rigid}) {
	    $nbOpt->{classSize} = 2;
	} elsif ($opt->{category}) {
	    $nbOpt->{classSize} = 4;
	}
	return NaiveBayes->new ($nbOpt);
    }
}

sub randomInit {
    my ($example) = @_;

    $example->{id} = int (rand ($nb->{opt}->{classSize}));
}

sub flushIDDist {
    my ($idDist) = @_;

    my $sum = 0;
    foreach my $v (@$idDist) { $sum += ($v || 0); }

    my $v = 0;
    my $msg = '';
    for (my $i = 0; $i < $nb->{opt}->{classSize} - 1; $i++) {
	$v += ($idDist->[$i] || 0) / $sum;
	$msg .= sprintf ("%f\t", $v);
    }
    chomp ($msg);
    $distlog->print ("$msg\n");
    $distlog->flush;
}

sub addExample {
    my ($example) = @_;

    return unless ($iterNum > 1);
    if ($opt->{tmpDataDir}) {
	$exampleList->writeNext ($example);
    } else {
	push (@$list, $example);
    }
}

sub iterInit {
    my ($iterCount) = @_;
    if ($opt->{tmpDataDir}) {
	if ($readTmpPath) {
	    unlink ($readTmpPath);
	}
	if ($writeTmpPath) {
	    $readTmpPath = $writeTmpPath;
	    my $readTmp = IO::File->new ($readTmpPath, 'r') or die;
	    $readTmp->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
	    $exampleList->setIStream ($readTmp);
	}

	$writeTmpPath = $opt->{tmpDataDir} . "/$$.$iterCount";
	my $writeTmp = IO::File->new ($writeTmpPath, 'w') or die;
	$writeTmp->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
	$exampleList->setOStream ($writeTmp);
    } else {
	$listCounter = 0;
    }
}

sub iterNext {
    if ($opt->{tmpDataDir}) {
	return $exampleList->readNext;
    } else {
	my $example = $list->[$listCounter++];
    }
}

sub iterChange {
    my ($example) = @_;
    if ($opt->{tmpDataDir}) {
	my ($example) = @_;
	$exampleList->writeNext ($example);
    }
}

sub iterReset {
    if ($opt->{tmpDataDir}) {
	$exampleList->readClose if ($readTmpPath);
	$exampleList->writeClose;
    }
}

1;
