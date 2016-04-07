#!/bin/env perl
#
# select the instance of nouns listed in a given file
# usage: PROGRAM --input INPUT --list LIST > REMAINDER 2> LISTED
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'main=s', 'rest=s', 'list=s', 'compressed', 'compress');

my $list = {};
{
    my $listFH = IO::File->new ($opt->{list}, 'r') or die;
    $listFH->binmode (':utf8');
    while ((my $line = $listFH->getline)) {
	chomp ($line);
	$list->{$line} = 1;
    }
    $listFH->close;
}

my $filepath = $opt->{input};
my $input = IO::File->new (($opt->{compressed})? "bzip2 -dc $filepath |" : $filepath) or die;
$input->binmode (':utf8');
my $mainpath = $opt->{main};
my $restpath = $opt->{rest};
my ($main, $rest);
if ($opt->{compress}) {
    $main = IO::File->new ("| bzip2 -c > $mainpath") or die;
    $rest = IO::File->new ("| bzip2 -c > $restpath") or die;
} else {
    $main = IO::File->new ($mainpath, 'w') or die;
    $rest = IO::File->new ($restpath, 'w') or die;
}
$main->binmode (':utf8');
$rest->binmode (':utf8');

while ((my $line = $input->getline)) {
    chomp ($line);
    my ($name) = split (/\s+/, $line);
    if ($list->{$name}) {
	$rest->print("$line\n");
    } else {
	$main->print("$line\n");
    }
}
$input->close;
$main->close;
$rest->close;

1;
