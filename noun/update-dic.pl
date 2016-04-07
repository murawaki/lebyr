#!/bin/env perl
#
# update JUMAN dictionary with aggregation result
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Storable qw/retrieve/;
use Dumpvalue;

use IO::File;
use JumanDictionary;
use NounCategorySpec;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'debug', 'input=s', 'dicdir=s', 'output=s');

my $nouncat = NounCategorySpec->new;
my $workingDictionary = JumanDictionary->new($opt->{dicdir},
					     { writable => 1, doLoad => 1 });
printf STDERR ("dictionary loaded\n");
my $input;
if (defined($opt->{input})) {
    $input = IO::File->new($opt->{input});
    $input->binmode(':utf8');
} else {
    $input = \*STDIN;
}
while ((my $line = $input->getline)) {
    chomp($line);
    my @tmp = split(/\s+/, $line);
    my $midasi = shift(@tmp);
    my $count = shift(@tmp);
    my $labels = [];
    while (1) {
	my $label = shift(@tmp);
	last unless (defined($label));
	my $ratio = shift(@tmp) - 0;
	push(@$labels, [$label, $ratio]);
    }
    &updateEntry($workingDictionary, $midasi, $count, $labels);
}
$input->close;
$workingDictionary->saveAsDictionary($opt->{output});

1;


sub updateEntry {
    my ($workingDictionary, $midasi, $count, $labels) = @_;

    my $midasiList = $workingDictionary->getMorpheme($midasi, { '品詞' => '名詞' });
    if (!defined($midasiList)) {
	printf STDERR ("no midasi found: %s\n", $midasi);
	return;
    } elsif (scalar(@$midasiList) > 1) {
	printf STDERR ("ambiguous midasi: %s\n", $midasi);
	return;
    }
    my $entry = $midasiList->[0];

    my $sig = '';
    foreach my $tmp (@$labels) {
	my ($label, $ratio) = @$tmp;
	last if ($ratio < 0.2);
	$sig .= sprintf("%s:%.3f;", $label, $ratio);
    }
    return if (length($sig) <= 0);
    $sig = substr($sig, 0, length($sig) - 1); # drop trailing semicolon
    $entry->{'意味情報'}->{'意味分類'} = $sig;

    return if ($entry->{'品詞細分類'} eq 'サ変名詞');
    my $majorClass = $labels->[0]->[0];
    if ($nouncat->isProperByClass($majorClass)) {
	$entry->{'品詞細分類'} = ($majorClass eq '固有名詞その他')? '固有名詞' : $majorClass;
    }
}
