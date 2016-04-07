#!/bin/env perl
#
# transform stat into gnuplot dat
#
use strict;
use utf8;

use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'type=s', 'png', 'eps', 'out=s');

my $stat = &loadStat (\*STDIN);

if ($opt{out}) {
    my $stemFile = "/tmp/stem.$$";
    my $exampleFile = "/tmp/example.$$";
    $opt{plotfile} = "/tmp/plot.$$";

    open (my $stemFh, ">$stemFile");
    &outputDat ($stat, 'stemCount', $stemFh);
    close ($stemFh);

    open (my $exampleFh, ">$exampleFile");
    &outputDat ($stat, 'exampleCount', $exampleFh);
    close ($exampleFh);

    open (my $output, ">" . $opt{plotfile});
    &makeGnuplotFile ($output, $stemFile, $exampleFile, \%opt);
    close ($output);

    `gnuplot $opt{plotfile}`;

    unlink ($stemFile);
    unlink ($exampleFile);
    unlink ($opt{plotfile});
} else {
    die unless (defined ($opt{type}));
    # 一つの type について標準出力に出力
    my $type = $opt{type};
    &outputDat ($stat, $type, \*STDOUT);
}

sub loadStat {
    my ($fh) = @_;

    my $stat = [];
    my $struct = {};
    while (<$fh>) {
	chomp;

	if ($_ eq "----------") {
	    push (@$stat, $struct);
	    $struct = {};
	}
	my ($key, $value) = split (/\t/);
	$struct->{$key} = $value;
    }
    return $stat;
}

sub outputDat {
    my ($stat, $type, $fh) = @_;

    for (my $i = 0; $i < scalar (@$stat); $i++) {
	my $struct = $stat->[$i];

	printf $fh ("%d\t%d\n", $struct->{sentenceCount}, $struct->{$type});
    }
}

sub makeGnuplotFile {
    my ($output, $stemFile, $exampleFile, $opt) = @_;

    print $output <<__EOF__;
set key below
set ytics nomirror
set y2range [0:11000]
set y2tics 0, 2000
set xlabel "num. of sentences"
set ylabel "num. of acquired morphemes"
set y2label "num. of accumulated examples"
__EOF__

    if ($opt->{png}) {
	# print $output ("set terminal png large size 800,600\n");
	print $output ("set terminal png\n");
    } else {
	print $output ("set terminal postscript eps enhanced monochrome \"ArialMT\" 26\n");
    }
    if (defined ($opt->{out})) {
	print $output ("set output \"$opt->{out}\"\n");
    }

    print $output ("plot \"$stemFile\" with lines axis x1y1 title \"acquired morphemes\", \"$exampleFile\" with lines axis x1y2 title \"accumulated examples\"\n");
    
}



1;
