#!/bin/env perl
#
# サフィックスを規定された最大長でマージ
#

use strict;
use utf8;

use Encode;
use Unicode::Japanese;
use IO::File;
use PerlIO::via::Bzip2;
use Getopt::Long;
use MorphemeGrammar qw /$posList/;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'dir=s', 'debug', 'start=i', 'end=i', 'base=s', 'compressed');

die unless ( -d $opt{dir} );

my $limited;
if (defined ($opt{start}) || defined ($opt{end})) {
    $limited = 1;
    $opt{start} = -1 unless (defined ($opt{start}));
    $opt{end} = 0xFFFFFFFF unless (defined ($opt{end}));
} else {
    $limited = 0;
}

my $rv = {};
if (defined ($opt{base})) {
    die unless ( -f $opt{base} );

    if ($opt{debug}) {
	print STDERR ("examine $opt{base}\n");
    }

    my $suffix;
    my $filename = $opt{base};
    my $input = IO::File->new ($filename, 'r') or die;
    $input->binmode (($opt{compressed})? ':via(Bzip2):utf8' : ':utf8');
    while (<$input>) {
	chomp;

	if ($_ =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);
	    $rv->{$suffix}->{$posS}->{$katuyou2} += $count;
	} else {
	    $suffix = $_;
	}
    }
    $input->close;
}

my $counter = 0;
opendir (my $dirh, $opt{dir}) or die;
foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
    next unless ( -f "$opt{dir}/$ftmp" );
    # next unless ($ftmp =~ /\.out$/);

    if ($limited) {
	if ($ftmp =~ /(\d+)/) {
	    my $num = $1;
	    next if ($num < $opt{start} || $num > $opt{end});
	} else {
	    next;
	}
    }

    if ($opt{debug}) {
	warn ("examine $ftmp\n");
    }

    &readOutputFile ("$opt{dir}/$ftmp", $rv);

    $counter++;
}

if ($opt{debug}) {
    warn ("# $counter files processed\n");
}

my @suffixList = keys (%$rv);
my @sortedSuffixList = sort { $a cmp $b } (@suffixList);
undef (@suffixList);

foreach my $suffix (@sortedSuffixList) {
    print ("$suffix\n");
    foreach my $posS (keys (%{$rv->{$suffix}})) {
	foreach my $katuyou2 (keys (%{$rv->{$suffix}->{$posS}})) {
	    printf ("\t%s\t%s\t%d\n", $posS, $katuyou2, $rv->{$suffix}->{$posS}->{$katuyou2});
	}
    }
}

1;


sub readOutputFile {
    my ($filename, $suffixList) = @_;

    my $input = IO::File->new ($filename, 'r') or die;
    $input->binmode (($opt{compressed})? ':via(Bzip2):utf8' : ':utf8');
    my $suffix;
    while (<$input>) {
	chomp;

	my $line = $_;
	# ノイズ対策1
	if (&isCorruptString ($line)) {
	    if ($opt{debug}) {
		warn ("corrupt line removed (corrupt string): $line\n");
	    }
	    next;
	}

	if ($line =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);

	    unless (defined ($posList->{$posS})) {
		if ($opt{debug}) {
		    warn ("corrupt line removed (bad part-of-speech): $line\n");
		}
		next;
	    }

	    # ノイズ対策2
	    # イ形容詞 音便条件形2
	    unless ($posS =~ /^(\p{Katakana}|\p{Han})+$/
		    && $katuyou2 =~ /^(\p{Hiragana}|\p{Katakana}|\p{Han}|ー)+(\d*)$/ # 単位の接尾辞も消してしまうけど
		    && $count eq ($count - 0)) {
		if ($opt{debug}) {
		    warn ("corrupt line removed (bad format): $line\n");
		}
		next;
	    }

	    $suffixList->{$suffix}->{$posS}->{$katuyou2} += $count;
	} else {
	    $suffix = $_;
	}
    }
    $input->close;
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
