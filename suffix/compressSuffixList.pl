#!/bin/env perl
#
# compress suffix list using TX
#
# usage: perl compressSuffixList.pl --input /home/murawaki/research/lebyr/data/suffixThres --outputdir /home/murawaki/research/lebyr/data --debug
#
use strict;
use utf8;

use Encode qw /encode decode/;
use Storable qw /nstore/;
use Getopt::Long;
use Text::Trie::Tx;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'input=s', 'debug', 'outputdir=s');

die unless ( -f $opt{input} );
die unless ( -d $opt{outputdir} );

my $tmpFile = "/tmp/suffix.$$";
my $idxFile = $opt{outputdir} . "/suffix.tx";
my $dbFile = $opt{outputdir} . "/suffix.storable";

print ("loading suffixThres...") if ($opt{debug});
my ($suffixMap, $sortedSuffixList) = &load ($opt{input});
print ("done\n") if ($opt{debug});

&makeRawSuffixList ($tmpFile, $sortedSuffixList);
my ($posS2id, $id2posS, $katuyou22id, $id2katuyou2) = &makeIDDB ($suffixMap);

# build db
`txbuild $tmpFile $idxFile >/dev/null`; # too talkative
`rm -f $tmpFile`;
my $tx = Text::Trie::Tx->open ($idxFile) or die;
my ($suffix2id, $id2suffix) = &makeSuffixID ($tx);

print ("making db...") if ($opt{debug});
my $db = &makeDB ($suffixMap, $posS2id, $id2posS, $katuyou22id, $id2katuyou2, $suffix2id, $id2suffix);
print ("done\n") if ($opt{debug});

nstore ($db, $dbFile) or die;


sub load {
    my ($filename) = @_;

    my $suffixMap = {};
    my $sortedSuffixList = [];

    my $suffix;
    my $struct;
    open (my $file, "<:utf8", $filename) or die;
    while (<$file>) {
	chomp;

	if ($_ =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);
	    push (@{$struct->{$posS}}, [$katuyou2, $count]);
	} else {
	    if (defined ($suffix)) {
		&flushOldSuffix ($suffixMap, $suffix, $struct);
	    }
	    $suffix = $_;
	    $struct = {};
	    push (@$sortedSuffixList, $suffix);
	}
    }
    close ($file);
    &flushOldSuffix ($suffixMap, $suffix, $struct);

    return ($suffixMap, $sortedSuffixList);
}

sub flushOldSuffix {
    my ($suffixMap, $suffix, $struct) = @_;

    foreach my $posS (keys (%$struct)) {
	my $maxI = 0;
	if (scalar (@{$struct->{$posS}}) > 1) {
	    # select the most frequent katuyou2 if ambiguous
	    my $max = 0;
	    for (my $i = 0; $i < scalar (@{$struct->{$posS}}); $i++) {
		if ($struct->{$posS}->[$i]->[1] > $max) {
		    $max = $struct->{$posS}->[$i]->[1];
		    $maxI = $i;
		}
	    }
	}
	my ($katuyou2) = @{$struct->{$posS}->[$maxI]};
	push (@{$suffixMap->{$suffix}}, [$posS, $katuyou2]);
    }
}

sub makeRawSuffixList {
    my ($filename, $sortedSuffixList) = @_;

    open (my $file, ">:utf8", $filename) or die;
    foreach my $suffix (@$sortedSuffixList) {
	print $file ("$suffix\n");
    }
    close ($file);
}

sub makeIDDB {
    my ($suffixMap) = @_;
    my $posS2id = {};
    my $id2posS = [];
    my $katuyou22id = {};
    my $id2katuyou2 = [];

    while ((my $suffix = each (%$suffixMap))) {
	foreach my $tmp (@{$suffixMap->{$suffix}}) {
	    my ($posS, $katuyou2) = @$tmp;
	    unless (defined ($posS2id->{$posS})) {
		push (@$id2posS, $posS);
		$posS2id->{$posS} = $#$id2posS;
	    }
	    unless (defined ($katuyou22id->{$katuyou2})) {
		push (@$id2katuyou2, $katuyou2);
		$katuyou22id->{$katuyou2} = $#$id2katuyou2;
	    }
	}
    }
    return ($posS2id, $id2posS, $katuyou22id, $id2katuyou2);
}

sub makeSuffixID {
    my ($tx) = @_;

    my $suffix2id = {};
    my $id2suffix = [];

    my $keyNum = $tx->getKeyNum;
    for (my $i = 0; $i < $keyNum; $i++) {
	my $suffix = decode ('utf8', $tx->reverseLookup ($i));
	$suffix2id->{$suffix} = $i;
	$id2suffix->[$i] = $suffix;
    }
    return ($suffix2id, $id2suffix);
}

sub makeDB {
    my ($suffixMap, $posS2id, $id2posS, $katuyou22id, $id2katuyou2, $suffix2id, $id2suffix) = @_;

    # finger print
    my $fp2id = {};
    my $id2fp = [];
    my $idList = [];
    for (my $i = 0; $i < scalar (@$id2suffix); $i++) {
	my $suffix = $id2suffix->[$i];
	my $length = length ($suffix);

	my @list;
	# normalize POS in alphabetical order
	my @sorted = sort { $a->[0] cmp $b->[0] } @{$suffixMap->{$suffix}};
	foreach my $tmp (@sorted) {
	    my ($posS, $katuyou2) = @$tmp;
	    my $posSid = $posS2id->{$posS};
	    my $katuyou2id = $katuyou22id->{$katuyou2};
	    push (@list, $posSid, $katuyou2id);
	}
	my $fp = pack ("S*", $length, @list);
	my $id;
	if (defined ($fp2id->{$fp})) {
	    $id = $fp2id->{$fp};
	} else {
	    push (@$id2fp, $fp);
	    $id = $fp2id->{$fp} = $#$id2fp;
	}
	push (@$idList, $id);
    }
    return {
	idList => $idList, # suffix id -> fingerprint id
	id2fp => $id2fp,
	id2posS => $id2posS,
	id2katuyou2 => $id2katuyou2
    };
}

1;
