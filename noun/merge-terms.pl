#!/bin/env perl
#
# 形態素の df を計算
#
use strict;
use utf8;
use warnings;

use Getopt::Long;
use IO::File;
use Storable qw/retrieve nstore/;

require 'db.pl';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { thres => -1, type => 'cdb'  };
GetOptions ($opt, 'debug', 'start=i', 'end=i', 'input=s', 'dir=s', 'output=s', 'thres=i', 'idf', 'type=s');

# global vars
my $db;
my $thres = $opt->{thres};

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
if ($opt->{idf}) {
    &logIDF;
}
if ($opt->{type} eq 'cdb') {
    createCDB ($db, $opt->{output}); # save with utf8 flag { filterKey => 1 });
} else {
    nstore ($db, $opt->{output}) or die;
}

1;


sub processFile {
    my ($filePath) = @_;

    my $db2 = retrieve ($filePath) or die;
    if (!defined ($db)) {
	$db = $db2;
	return;
    }

    while ((my $term = each (%$db2))) {
	$db->{$term}->[0] += $db2->{$term}->[0];
	$db->{$term}->[1] += $db2->{$term}->[1];
    }
}

sub logIDF {
    my $D = 0;
    my $total = 0;
    if ($opt->{debug}) {
	while ((my $term = each (%$db))) {
	    $D += $db->{$term}->[1];
	    $total += $db->{$term}->[0];
	}
    } else {
	while ((my $term = each (%$db))) {
	    $D += $db->{$term}->[1];
	}
    }

    my $logIDF = {};
    my $dropped = 0;
    my $loss = 0;
    while ((my $term = each (%$db))) {
	my $df = $db->{$term}->[1];
	if ($df < $thres) {
	    $dropped++;
	    $loss += $db->{$term}->[0];
	    next;
	}

	$logIDF->{$term} = log ($D / $df);
    }
    if ($opt->{debug}) {
	printf ("%d mrphs deleted (%f%% in freq)\n", $dropped, ($loss * 100) / $total);
    }

    $db = $logIDF;
}
