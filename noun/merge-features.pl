#!/bin/env perl
#
# 予め素性の数を数えておく
#
use strict;
use utf8;
use warnings;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

# require 'db.pl';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { thres => -1 }; # type => 'cdb'
GetOptions ($opt, 'debug', 'start=i', 'end=i', 'input=s', 'dir=s', 'output=s', 'thres=i', 'id'); # 'type=s'

# global vars
my $fDB;

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
if ($opt->{thres} > 0) {
    &applyThres ($opt->{thres});
}
if ($opt->{id}) {
    &setId;
}
nstore ($fDB, $opt->{output}) or die;
1;


sub processFile {
    my ($filePath) = @_;

    my $db = retrieve ($filePath) or die;
    if (!defined ($fDB)) {
	$fDB = $db;
	return;
    }

    foreach my $type (keys (%$db)) {
	my $p = $fDB->{$type};
	my $q = $db->{$type};
	while ((my $key = each (%$q))) {
	    $p->{$key} += $q->{$key};
	}
    }
}

sub applyThres {
    my ($thres) = @_;
    foreach my $type (keys (%$fDB)) {
	my $count = 0;
	my $all = 0;
	my $sum = 0; my $delCount = 0;
	my $p = $fDB->{$type};
	foreach my $key (keys (%$p)) {
	    $all++;
	    my $val = $p->{$key};
	    $sum += $val;
	    if ($val < $thres) {
		delete ($p->{$key});
		$count++;
		$delCount += $val;
	    }
	}
	printf STDERR ("%s\t%f%% (%d / %d) features removed (%f%% in freq)\n",
		       $type, ($count * 100) / $all, $count, $all, ($delCount * 100) / $sum) if ($opt->{debug});
    }
}

sub setId {
    my $c = 0;
    foreach my $type (sort (keys (%$fDB))) {
	my $p = $fDB->{$type};
	my @keys = sort { $p->{$b} <=> $p->{$a} } (keys (%$p));
	foreach my $key (@keys) {
	    $p->{$key} = $c++;
	}
    }
    printf STDERR ("%d features set\n", $c) if ($opt->{debug});
}
