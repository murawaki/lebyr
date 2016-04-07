#!/bin/env perl
#
# 予め素性の数を数えておく
#
use strict;
use utf8;
use warnings;

use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { acquired => 0, verbose => 1 };
GetOptions ($opt, 'debug', 'start=i', 'end=i', 'verbose=i', 'input=s', 'dir=s', 'compressed', 'output=s');

# global vars
my $fDB = {};

my $limited;
if (defined ($opt->{start}) || defined ($opt->{end})) {
    $limited = 1;
    $opt->{start} = -1 unless (defined ($opt->{start}));
    $opt->{end} = 0xFFFFFFFF unless (defined ($opt->{end}));
} else {
    $limited = 0;
}

if ($opt->{input}) {
    &processFile ($opt->{input});
} else {
    my $counter = 0;
    opendir (my $dirh, $opt->{dir}) or die;
    foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
	# next unless ($ftmp =~ /\.out$/);
	next unless ( -f "$opt->{dir}/$ftmp" );

	if ($limited) {
	    if ($ftmp =~ /(\d+)/) {
		my $num = $1;
		next if ($num < $opt->{start} || $num > $opt->{end});
	    } else {
		next;
	    }
	}
	print STDERR ("examine $ftmp\n") if ($opt->{debug});

	&processFile ("$opt->{dir}/$ftmp");

	$counter++;
    }
    print STDERR ("$counter files processed\n") if ($opt->{debug});
}
nstore ($fDB, $opt->{output}) or die;

1;


sub processFile {
    my ($filePath) = @_;

    my $f = &iterInit ($filePath);
    while ((my $tmp = &iterNext ($f))) {
	no warnings qw(uninitialized);

	my ($midasi, $cat, $ftype, $fname) = @$tmp;
	$fDB->{$ftype}->{$fname}++;
    }
    &iterClose ($f);
}

sub iterInit {
    my ($filepath) = @_;
    my $input;
    if ($opt->{compressed}) {
	open ($input, '-|', "bzcat $filepath");
	binmode ($input, ':utf8');
    } else {
	open ($input, "<:utf8", $filepath) or die;
    }
    # my $input = IO::File->new ($filepath, 'r') or die;
    # $input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
    return $input;
}

sub iterNext {
    my ($f) = @_;
    while (1) {
	my $line = $f->getline;
	return undef unless (defined ($line));

	chomp ($line);
	next if ($line =~ /^\#/);
	next if ($line =~ /^\$/);

	my @tmp = split (/\s/, $line);
	return \@tmp;
    }
}

sub iterClose {
    my ($f) = @_;
    $f->close;
}
