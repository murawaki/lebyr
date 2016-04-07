#!/bin/env perl
#
# split aggregated data into training and test data
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'debug', 'input=s', 'compressed');

# initialize
my $filepath = $opt->{input};
my $input;
if ($opt->{compressed}) {
    $input = IO::File->new("bzip2 -dc $filepath |") or die;
} else {
    $input = IO::File->new($filepath) or die;
}
$input->binmode(':utf8');
while ((my $line = $input->getline)) {
    chomp($line);
    my @list = split(/\s+/, $line);
    if ($list[0] =~ /\*$/) {
	$list[0] = substr($list[0], 0, length ($list[0]) - 1);
	print STDERR join("\t", @list), "\n";
    } else {
	print STDOUT "$line\n";
    }
}
$input->close;

1;
