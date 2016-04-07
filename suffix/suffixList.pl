#!/bin/env perl
#
# aggregate suffixes extracted by SuffixExtractor
#
# read files in a specified directory
# use bzip2 in data compression
# output to stdout unless --output=file is specified
#

use strict;
use utf8;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { useAcquired => 0 }; # use acquired morphemes
GetOptions ($opt, 'dir=s', 'start=i', 'end=i', 'debug', 'compressed', 'compress', 'useAcquired', 'output=s');

die unless ( -d $opt->{dir} );

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
	# if ($ftmp =~ /^x(\d+)/) {
	if ($ftmp =~ /(\d+)/) {
	    my $num = $1;
	    next if ($num < $opt->{start} || $num > $opt->{end});
	} else {
	    next;
	}
    }

    if ($opt->{debug}) {
	print STDERR ("examine $ftmp\n");
    }

    &readOutputFile ("$opt->{dir}/$ftmp", $rv);

    $counter++;
}

if ($opt->{debug}) {
    print STDERR ("# $counter files processed\n");
}

my @suffixList = keys (%$rv);
my @sortedSuffixList = sort { $a cmp $b } (@suffixList);
undef (@suffixList);


my $output = \*STDOUT;
if ($opt->{output}) {
    $output = IO::File->new ($opt->{output}, 'w') or die;
    $output->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
}
foreach my $suffix (@sortedSuffixList) {
    print $output ("$suffix\n");
    foreach my $posS (keys (%{$rv->{$suffix}})) {
	foreach my $katuyou2 (keys (%{$rv->{$suffix}->{$posS}})) {
	    printf $output ("\t%s\t%s\t%d\n", $posS, $katuyou2, $rv->{$suffix}->{$posS}->{$katuyou2});
	}
    }
}
if ($opt->{output}) {
    $output->close;
}

sub readOutputFile {
    my ($filename, $suffixList) = @_;

    my $docID;
    my $input = IO::File->new ($filename, 'r') or die;
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
	# format: suffix TAB 品詞 TAB 活用形 TAB 原形
	my ($suffix, $posS, $katuyou2, $genkei) = split (/\t/, $_);
	# make sure the input is not corrupt
	next unless (length ($genkei) > 0);
	# acquired morhpeme is marked with trailing '*'
	next if (!$opt->{useAcquired} && $genkei =~ /\*$/);

	$suffixList->{$suffix}->{$posS}->{$katuyou2}++;
    }
    $input->close;
}

1;
