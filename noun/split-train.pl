#!/bin/env perl
#
# split training data into shards for distributed training
#   NOTE: shard counter starts with 1
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2; # buggy
use Storable qw/retrieve nstore/;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { shard => 10, prefix => 'shard' };
GetOptions ($opt, 'debug', 'input=s', 'shard=i', 'compressed', 'compress', 'prefix=s');

my $outputList = [];
foreach my $i (1 .. $opt->{shard}) {
    my $opath = sprintf ("%s.%d%s", $opt->{prefix}, $i, ($opt->{compress}? '.bz2' : ''));
    my $f;
    if ($opt->{compress}) {
	$f = IO::File->new ("| bzip2 -c > $opath") or die;
    } else {
	$f = IO::File->new ($opath, 'w') or die;
    }
    $f->binmode (':utf8');
    push(@$outputList, $f);
}

# initialize
my $filepath = $opt->{input};
my $input;
if ($opt->{compressed}) {
    open($input, '-|', "bzcat $filepath");
    binmode($input, ':utf8');
} else {
    open($input, "<:utf8", $filepath) or die;
}
my $i = 0;
while ((my $line = $input->getline)) {
    $outputList->[$i++ % $opt->{shard}]->print($line);
}

foreach my $output (@$outputList) {
    $output->close;
}

1;
