#!/bin/env perl
#
# サフィックスを規定された最大長でマージ
#

use strict;
use utf8;

use Unicode::Japanese;
use IO::File;
use PerlIO::via::Bzip2;
# use Encode;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { length => 4 };
GetOptions ($opt, 'input=s', 'debug', 'compressed', 'length=i');

die unless ( -f $opt->{input} );

my $filename = $opt->{input};
my $input = IO::File->new ($filename, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $currentSuffix = '';
my $currentStruct;
my $L = $opt->{length};
while (<$input>) {
    chomp;

    my $line = $_;
    # ノイズ対策1
    if (&isCorruptString ($line)) {
	if ($opt->{debug}) {
	    warn ("corrupt line removed (corrupt string): $line\n");
	}
	next;
    }
    if ($line =~ /^\t(.+)/) {
	my ($posS, $katuyou2, $count) = split (/\t/, $1);
	$currentStruct->{$posS}->{$katuyou2} += $count;
    } else {
	my $suffix = $line;

	my $suffixShort;
	if ((length ($suffix) < $L && ($suffixShort = $suffix))
	    || ($suffixShort = substr ($suffix, 0, $L)) ne $currentSuffix) {
	    # flush the old struct
	    if (defined ($currentStruct)) {
		&printSuffixStruct ();
	    }
	    $currentSuffix = $suffixShort;
	    $currentStruct = {};
	}
    }
}
$input->close;
if (defined ($currentStruct)) {
    &printSuffixStruct ();
}


sub printSuffixStruct {
    print ("$currentSuffix\n");
    foreach my $posS (keys (%$currentStruct)) {
	foreach my $katuyou2 (keys (%{$currentStruct->{$posS}})) {
	    printf ("\t%s\t%s\t%d\n", $posS, $katuyou2, $currentStruct->{$posS}->{$katuyou2});
	}
    }

}

# 折り返し変換で文字化けを調べる
# 戻り値1の時、まずい
sub isCorruptString {
    my ($input) = @_;

    my $back = Unicode::Japanese->new (Unicode::Japanese->new ($input)->euc, 'euc')->getu;
    return 1 if ($input ne $back);
    return 1 if ($input =~ /\\x[0-9A-F]{2}/);

    return 0;
}

1;
