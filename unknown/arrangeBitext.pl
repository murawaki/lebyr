#!/bin/env perl
#
# Bitext を分野ごとにソート
# 面倒だから全部メモリにロード
#
use strict;
use utf8;

use Encode;
use Getopt::Long;

# binmode (STDIN,  ':utf8');
# binmode (STDOUT, ':utf8');
# binmode (STDERR, ':utf8');
binmode (STDIN,  ':encoding(euc-jp)');
binmode (STDOUT, ':encoding(euc-jp)');
binmode (STDERR, ':encoding(euc-jp)');

my $opt = {};
GetOptions ($opt, 'debug');

my $bitextFile = "/share/tool/MT/dat/JST/bitext_s_all.xml";

my $idDB = {};
my $struct;

print STDERR ("loading bitext") if ($opt->{debug});

my $count = 0;

use IO::File;
my $fh = new IO::File;
$fh->open ($bitextFile, "<:encoding(euc-jp)") or die;
while (defined (my $line = $fh->getline)) {
    if ($line =~ /docid\=\"([^\"]+)\"/) {
	my $docID = $1;
	my ($domain, $id0, $id1) = split (/\-/, $docID);

	unless ($line =~ /transid\=\"(\d+)\"/) {
	    print STDERR ("malformed input: $line\n") if ($opt->{debug});
	    next;
	}
	my $id2 = $1;
	$struct = [$id0, $id1, $id2];

	push (@{$idDB->{$domain}}, $struct);

	print STDERR (".") if (!($count++ % 10000) && $opt->{debug});

    } elsif ($line =~ /\<i_sentence\>([^\>]+)\<\/i_sentence\>/) {
	$struct->[3] = $1;
    }
}
$fh->close;

print STDERR ("done\n") if ($opt->{debug});

foreach my $domain (sort { $a cmp $b } (keys (%$idDB))) {
    my $list = $idDB->{$domain};
    my @sorted = sort { ($a->[0] <=> $b->[0]) || ($a->[1] <=> $b->[1]) || ($a->[2] <=> $b->[2]) } @$list;

    foreach my $tmp (@sorted) {
	my ($id0, $id1, $id2, $line) = @$tmp;
	printf ("# %s %s %s %s\n%s\n", $domain, $id0, $id1, $id2, $line);
    }
}



1;
