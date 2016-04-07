#!/bin/env perl
#
# 品詞毎の divergence を調べるテスト
#
#
use strict;
use utf8;

use Getopt::Long;
use Storable qw (retrieve);

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'input=s', 'from=s', 'debug');
# usage:
#   input: 頻度の入った Storable
#   from: 全体頻度を別の品詞で考える場合

my $instanceList = retrieve ($opt->{input}) or die;
printf STDERR ("loading done\n") if ($opt->{debug});

my $all;
my $included;
if ( -s $opt->{from} ) {
    my $instanceList2 = retrieve ($opt->{from}) or die;
    $all = &initDistributionRatio ($instanceList2);
    $included = 1;
} else {
    $all = &initDistributionRatio ($instanceList);
    $included = 0;
}
printf STDERR ("initialization done\n") if ($opt->{debug});

my $count = 0;
while ((my $genkei = each (%$instanceList))) {
    my $sum = 0;
    foreach my $suffix (keys (%{$instanceList->{$genkei}})) {
	$sum += $instanceList->{$genkei}->{$suffix};
    }
    my $divergence = &calcSkewDivergence ($instanceList->{$genkei}, $all);
    printf ("%d\t%f\t# %s\n", $sum, $divergence, $genkei);

    printf STDERR ('.') if ($opt->{debug} && !(++$count % 50));
}
printf STDERR ("\n") if ($opt->{debug});

1;


# calc KL divergence
# $p, $q は hashref
#  $p: key : string, value : integer 
#  $q: key : string, value : float
# $p に観測値、$q にモデルを入れる
# 何度も使うので $q には相対値を入れておく
sub calcSkewDivergence {
    my ($q, $r) = @_;

    my $alpha = 0.99;

    my $sum = 0;
    foreach my $k (keys (%$q)) {
	$sum += $q->{$k};
    }

    my $s = {}; # smoothing
    while ((my $k = each (%$r))) {
	$s->{$k} = $alpha * ($q->{$k} / $sum) + (1 - $alpha) * $r->{$k};
    }
    if (!$included) {
	# $k not in $r
	while ((my $k = each (%$q))) {
	    unless (defined ($r->{$k})) {
		$s->{$k} = $alpha * ($q->{$k} / $sum);
	    }
	}
    }
    return &calcKLDivergence ($r, $s);
}

# $q, $r: hashref
# assume that q(y) != 0 and r(y) != 0
sub calcKLDivergence {
    my ($q, $r) = @_;

    my $divergence = 0;
    foreach my $key (keys (%$q)) {
	my $pQ = $q->{$key};
	my $pR = $r->{$key};
	$divergence += $pQ * (log ($pQ) - log ($pR));
    }
    return $divergence;
}

sub initDistributionRatio {
    my ($instanceList) = @_;

    my $sum = 0;
    my $distribution = {};
    while ((my $genkei = each (%$instanceList))) {
	my $struct = $instanceList->{$genkei};
	foreach my $suffix (keys (%$struct)) {
	    $distribution->{$suffix} += $struct->{$suffix};
	    $sum += $struct->{$suffix};
	}
    }

    my $distributionRatio = {};
    foreach my $suffix (keys (%$distribution)) {
	$distributionRatio->{$suffix} = $distribution->{$suffix} / $sum;
    }
    return $distributionRatio;
}
