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
use warnings;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/nstore/;

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

# nstore ($rv, $opt->{output}) or die;
my @nameList = sort { $rv->{$b}->{df} <=> $rv->{$a}->{df} } (keys (%$rv));
foreach my $name (@nameList) {
    my $neRank = join ("\t", map { $_ . "\t" . $rv->{$name}->{_}->{$_} } (keys (%{$rv->{$name}->{_}})));
    printf ("%s\t%d\t%d\t%s\n", $name, $rv->{$name}->{df}, $rv->{$name}->{tf}, $neRank);
}


sub readOutputFile {
    my ($filename, $suffixList) = @_;

    # my $docID;
    my $input;
    if ($opt->{compressed}) {
	open ($input, '-|', "bzcat $filename");
	binmode ($input, ':utf8');
    } else {
	open ($input, "<:utf8", $filename) or die;
    }
    # my $input = IO::File->new ($filename, 'r') or die;
    # $input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
    my $tmp = {};
    while (<$input>) {
	chomp;
	if ($_ =~ /^\#(.+)/) {
# 	    my ($name, $value) = split (/\t/, $1);
# 	    if ($name eq 'document') {
# 		$docID = $value;
# 	    }
	    foreach my $name (keys (%$tmp)) {
		$rv->{$name}->{df}++;
	    }
	    $tmp = {};
	} else {
	    my ($name, $id, $type, $neString) = split (/\s+/, $_);
	    $rv->{$name}->{_}->{$type}++;
	    $rv->{$name}->{tf}++;
	    $tmp->{$name} = 1;
	}
    }
    $input->close;
}

1;
