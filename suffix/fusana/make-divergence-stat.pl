#!/bin/env perl
#
# suffix 抽出の生ファイルから divergence 計算用の
# instance 毎の統計を計算
#
use strict;
use utf8;

# use Encode;
use Getopt::Long;
use Storable qw (retrieve nstore);
use IO::File;
use PerlIO::via::Bzip2;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { thres => 4 };
GetOptions ($opt, 'index=i', 'dir=s', 'output=s', 'start=i', 'end=i', 'compressed', 'subpos', 'thres=i', 'debug');

die unless ( -d $opt->{dir} );
die unless (defined ($opt->{output}));

my $limited;
if (defined ($opt->{start}) || defined ($opt->{end})) {
    $limited = 1;
    $opt->{start} = -1 unless (defined ($opt->{start}));
    $opt->{end} = 0xFFFFFFFF unless (defined ($opt->{end}));
} else {
    $limited = 0;
}

my $counter = 0;
my $rv = {};
opendir (my $dirh, $opt->{dir}) or die;
foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
    next unless ( -f "$opt->{dir}/$ftmp" );

    if ($limited) {
	# if ($ftmp =~ /^x(\d+)\.out/) {
	if ($ftmp =~ /(\d+)/) {
	    my $num = $1;
	    next if ($num < $opt->{start} || $num > $opt->{end});
	} else {
	    next;
	}
    }

    print STDERR ("examine $ftmp\n") if ($opt->{debug});

    &readOutputFile ("$opt->{dir}/$ftmp", $rv);

    $counter++;
}

print STDERR ("# $counter files processed\n") if ($opt->{debug});

nstore ($rv, $opt->{output}) or die;

sub readOutputFile {
    my ($filename, $instanceList) = @_;

    my $docID;
    my $input = IO::File->new ($filename, 'r') or die "cannot open file: $!\n";
    $input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
    while (<$input>) {
	chomp;
	if ($_ =~ /^\#(.+)/) {
	    my ($name, $value) = split (/\t/, $1);
	    if ($name eq 'document') {
		$docID = $value;
	    }
	    next;
	}
	# 出力 format: suffix TAB 品詞 TAB 活用形 TAB 原形
	my ($suffix, $posS, $katuyou2, $genkei, $subPosS) = split (/\t/, $_);
	if ($subPosS && $opt->{subpos}) {
	    $posS = $subPosS;
	}
	if ($opt->{thres} > 0) {
	    $suffix = substr ($suffix, 0, $opt->{thres});
	}

	# make sure the input is not corrupt
	unless (length ($genkei) > 0) {
	    print STDERR ("malformed input $_\n");
	    next;
	}

	# $instanceList->{$posS}->{$genkei}->{$katuyou2}++;
	$instanceList->{$posS}->{$genkei}->{$suffix}++;
    }
    $input->close;
}

1;
