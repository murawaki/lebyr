#!/bin/env perl
#
# randomly select N lines from a given file
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use IO::File;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'compressed');

my $total = $ARGV[0];
my $selected = $ARGV[1];
my $filePath = $ARGV[2];

my $tmp = &getRandSequence($total, $selected);

my $f = IO::File->new(($opt->{compressed})? "bzip2 -dc $filePath |" : $filePath) or die;
$f->binmode(':utf8');
my $i = 0;
while ((my $line = $f->getline)) {
    if ($i++ == $tmp->[0]) {
	shift(@$tmp);
	print($line);

	last unless (scalar(@$tmp));
    }
}
$f->close;

1;

# randomly take $num samples from sequence 0 ... $length - 1
sub getRandSequence {
    my ($length, $num) = @_;

    my $seq = {};
    for (my $i = 0; $i < $num; $i++) {
	while (1) {
	    my $rand = int(rand($length));
	    unless (defined($seq->{$rand})) {
		$seq->{$rand} = 1;
		last;
	    }
	}
    }
    my @seq2 = sort { $a <=> $b } (keys(%$seq));
    return \@seq2;
}
