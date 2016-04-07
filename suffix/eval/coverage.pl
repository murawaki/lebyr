#!/bin/env perl
#
# サフィックスの coverage を調べる
#
# すべてを集約した suffixThres を 100% としたとき
# より少ないドキュメントから集めたデータの coverage の統計
#
use strict;
use utf8;

use Encode;
use Unicode::Japanese;
use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'dir=s', 'debug', 'start=i', 'end=i', 'compressed');

die unless ( -d $opt{dir} );
my $suffixListFile = "/home/murawaki/research/lebyr/data/suffixThres";

print STDERR ("loading suffixThres\n") if ($opt{debug});
my $totalCount = 0;
my $suffixListAll = &init ($suffixListFile);
my $currentCount = 0;

my $limited;
if (defined ($opt{start}) || defined ($opt{end})) {
    $limited = 1;
    $opt{start} = -1 unless (defined ($opt{start}));
    $opt{end} = 0xFFFFFFFF unless (defined ($opt{end}));
} else {
    $limited = 0;
}

my $suffixList = {};

my $counter = 0;
opendir (my $dirh, $opt{dir}) or die;
foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
    next unless ( -f "$opt{dir}/$ftmp" );

    if ($limited) {
	# if ($ftmp =~ /(\d+)\.out/) {
	if ($ftmp =~ /(\d+)/) {
	    my $num = $1;
	    next if ($num < $opt{start} || $num > $opt{end});
	} else {
	    next;
	}
    }

    print STDERR ("examine $ftmp\n") if ($opt{debug});

    &readOutputFile ("$opt{dir}/$ftmp", $suffixList);
    my $rateStruct = &calcSaturationStat ($counter);

    # 出力データ
    printf ("%d\t%d\t%d\t%d\t%d\t%f\n",
	    $counter + 1,                  # 現在読んだファイルの数
	    $currentCount,                 # 現在のカウント数
	    $rateStruct->{suffixCount},    # 現在のサフィックスの異なり数
	    $rateStruct->{suffixPOSCount}, # 現在のサフィックスの異なり数 (品詞を区別)
	    $rateStruct->{suffixPOSExampleCount}, # カバーされた用例の全体での網羅率
	    $rateStruct->{suffixPOSExampleCount} / $totalCount);

    $counter++;
}

print STDERR ("# $counter files processed\n") if ($opt{debug});

1;


sub calcSaturationStat {
    my ($counter) = @_;

    my $suffixCount = 0;
    my $suffixPOSCount = 0;
    my $suffixPOSExampleCount = 0;

    my $suffix;
    while (($suffix = each (%$suffixListAll))) {
	if (defined ($suffixList->{$suffix})) {
	    $suffixCount++;
	    foreach my $posS (keys (%{$suffixListAll->{$suffix}})) {
		if (defined ($suffixList->{$suffix}->{$posS})) {
		    $suffixPOSCount++;
		    $suffixPOSExampleCount += $suffixListAll->{$suffix}->{$posS};
# 		    foreach my $katuyou2 (keys (%{$suffixListAll->{$suffix}->{$posS}})) {
# 			$suffixPOSExampleCount += $suffixListAll->{$suffix}->{$posS}->{$katuyou2};
# 		    }
		}
	    }
	}
    }
    my $stat = {
	suffixCount => $suffixCount,
	suffixPOSCount => $suffixPOSCount,
	suffixPOSExampleCount => $suffixPOSExampleCount
    };
    return $stat;
}

sub readOutputFile {
    my ($filename, $suffixList) = @_;

    my $suffix;
    my $input = IO::File->new ($filename, 'r') or die "cannot open file: $!\n";
    $input->binmode (($opt{compressed})? ':via(Bzip2):utf8' : ':utf8');
    while (<$input>) {
	chomp;

	my $line = $_;
	# ノイズ対策1
	if (&isCorruptString ($line)) {
	    print STDERR ("corrupt line removed (corrupt string): $line\n") if ($opt{debug});
	    next;
	}

	if ($line =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);

	    # ノイズ対策2
	    # イ形容詞 音便条件形2
	    unless ($posS =~ /^(\p{Katakana}|\p{Han})+$/
		    && $katuyou2 =~ /^(\p{Hiragana}|\p{Katakana}|\p{Han})+(\d*)$/
		    && $count eq ($count - 0)) {
		print STDERR ("corrupt line removed (bad format): $line\n") if ($opt{debug});
		next;
	    }

	    # $suffixList->{$suffix}->{$posS}->{$katuyou2} += $count;
	    $suffixList->{$suffix}->{$posS}  += $count;
	    $currentCount += $count;
	} else {
	    $suffix = $_;
	    if (length ($suffix) > 5) {
		$suffix = substr ($suffix, 0, 5)
	    }
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

# suffix 
sub init {
    my ($suffixListFile) = @_;

    my $suffixList = {};
    my $suffix;
    open (my $file, "<:utf8", $suffixListFile) or die;
    while (<$file>) {
	chomp;

	if ($_ =~ /^\t(.+)/) {
	    my ($posS, $katuyou2, $count) = split (/\t/, $1);
	    # $suffixList->{$suffix}->{$posS}->{$katuyou2} += $count;
	    $suffixList->{$suffix}->{$posS}  += $count;
	    $totalCount += $count;
	} else {
	    $suffix = $_;
	}
    }
    return $suffixList;
}
