#!/bin/env perl
#
# 用言ごとの格フレームを SVM の素性列に変換
#
use strict;
use utf8;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1, thres => 5, freq => 0, type => 'one-versus-rest' };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'dir=s', 'compressed', 'thres=i', 'freq!', 'type=s', 'typeId=s', 'dry-run');

my $repnameDB = {};
my $repnameCounter = 0;
my $rv = [];
my $id2type = [];
my $id2repname = [];

my $typeListList =
    [{ '人名' => 1, '人' => -1 },
     { '地名' => 1, '場所-施設' => -1, '場所-自然' => -1 },
     { '組織名' => 1, '組織・団体' => -1 },
     ];

# 正例と負例の選択
my $typeList;
if ($opt->{type} eq 'one-versus-rest') {
    my ($type1, $val1) = split (/\:/, $opt->{typeId});
    $typeList = { 'その他' => ($opt->{typeId} eq '-1')? 1: -1 };

    for (my $i = 0, my $l = scalar (@$typeListList); $i < $l; $i++) {
	my $typeListTmp = $typeListList->[$i];
	foreach my $type (keys (%$typeListTmp)) {
	    if ($i == $type1 && $typeListTmp->{$type} == $val1) {
		$typeList->{$type} = 1;
	    } else {
		$typeList->{$type} = -1;
	    }
	}
    }
} elsif ($opt->{type} eq 'one-versus-rest-groupedA') {
    $typeList = { 'その他' => -1 };
    for (my $i = 0, my $l = scalar (@$typeListList); $i < $l; $i++) {
	my $typeListTmp = $typeListList->[$i];
	foreach my $type (keys (%$typeListTmp)) {
	    if ($i == $opt->{typeId}) {
		$typeList->{$type} = 1;
	    } else {
		$typeList->{$type} = -1;
	    }
	}
    }
} elsif ($opt->{type} eq 'singleA') {
    $typeList = $typeListList->[$opt->{typeId}] or die "specify typeId";
} elsif ($opt->{type} eq 'one-versus-rest-groupedB') {
    $typeList = { 'その他' => -1 };
    for (my $i = 0, my $l = scalar (@$typeListList); $i < $l; $i++) {
	my $typeListTmp = $typeListList->[$i];
	foreach my $type (keys (%$typeListTmp)) {
	    if ($typeListTmp->{$type} == $opt->{typeId}) {
		$typeList->{$type} = 1;
	    } else {
		$typeList->{$type} = -1;
	    }
	}
    }
} elsif ($opt->{type} eq 'singleB') {
    my ($type1, $val1) = split (/\:/, $opt->{typeId});
    $typeList = {};
    for (my $i = 0, my $l = scalar (@$typeListList); $i < $l; $i++) {
	my $typeListTmp = $typeListList->[$i];
	foreach my $type (keys (%$typeListTmp)) {
	    if ($typeListTmp->{$type} == $val1) {
		$typeList->{$type} = ($i == $type1)? 1 : -1;
	    }
	}
    }
} else {
    # TODO: implement pairwise?
    die;
}

if ($opt->{'dry-run'}) {
    use Dumpvalue;
    Dumpvalue->new->dumpValue ($typeList);
    exit;
}

my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
while ((my $line = $input->getline)) {
    chomp;
    my @tmp = split (/\s/, $line);

    my $type = shift (@tmp);
    my $repname = shift (@tmp);

    next unless (scalar (@tmp) >= $opt->{thres});

    my $class = $typeList->{$type};
    next unless defined ($class);
    print (($class == 1)? '+1' : '-1');

    if ($opt->{freq}) {
	my $sum = 0;
	foreach my $tmp (@tmp) {
	    my ($k, $v) = split (/\:/, $tmp);
	    $sum += $v;
	}
	foreach my $tmp (@tmp) {
	    my ($k, $v) = split (/\:/, $tmp);
	    printf (" $k:%f", $v / $sum);
	}	
    } else {
	foreach my $tmp (@tmp) {
	    my ($k, $v) = split (/\:/, $tmp);
	    print (" $k:1");
	}
    }
    print ("\n");
}

1;
