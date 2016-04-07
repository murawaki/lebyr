#!/bin/env perl
#
# make ablation data
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2; # buggy
use Storable qw/retrieve nstore/;

use ExampleList;
use NounCategorySpec;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'debug', 'input=s', 'fDB=s', 'compressed', 'compress', 'outputdir=s');

my $fDB = retrieve($opt->{fDB}) or die;
my $id2featureType = [];
foreach my $type (keys(%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each(%$p))) {
	$id2featureType->[$p->{$key}] = $type;
    }
}
# undef ($fDB);

my $outputList = {};
foreach my $type (keys(%$fDB)) {
    my $opath = sprintf("%s/%s%s", $opt->{outputdir}, $type, ($opt->{compress}? '.bz2' : ''));
    my $f;
    if ($opt->{compress}) {
	$f = IO::File->new("| bzip2 -c > $opath") or die;
    } else {
	$f = IO::File->new($opath, 'w') or die;
    }
    $f->binmode (':utf8');
    $outputList->{$type} = $f;
}

# initialize
my $filepath = $opt->{input};
# my $input = IO::File->new ($filepath, 'r') or die;
# $input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $input;
if ($opt->{compressed}) {
    open($input, '-|', "bzcat $filepath");
    binmode($input, ':utf8');
} else {
    open($input, "<:utf8", $filepath) or die;
}
my $typeCount = {};
my $exampleList = ExampleList->new($input);
while ((my $example = $exampleList->readNext)) {
    my $featureString = {};
    foreach my $f (@{$example->{featureList}}) {
	my $type = $id2featureType->[$f->[0]];
	{
	    no warnings qw/uninitialized/;
	    $typeCount->{$type}++;
	};
	foreach my $type2 (keys (%$fDB)) {
	    unless ($type eq $type2) {
		$featureString->{$type2} .= "\t" . $f->[0] . ':' . $f->[1];
	    }
	}
    }
    foreach my $type (keys(%$fDB)) {
	next unless (defined ($featureString->{$type}));
	$outputList->{$type}->printf("%s\t%s\t%s%s\n", $example->{name}, $example->{id}, $example->{from}, $featureString->{$type})
    }
}

if ($opt->{debug}) {
    foreach my $type (sort { $a cmp $b } keys(%$typeCount)) {
	printf STDERR ("%s\t%d\n", $type, $typeCount->{$type});
    }
}

foreach my $type (keys(%$fDB)) {
    $outputList->{$type}->close;
}

1;
