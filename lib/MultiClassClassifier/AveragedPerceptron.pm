package MultiClassClassifier::AveragedPerceptron;

use strict;
use warnings;
use utf8;
use base qw/MultiClassClassifier/;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $size = shift;

    my $weightList = [];
    my $weightAvgList = [];
    for (my $i = 0; $i < $size; $i++) {
	$weightList->[$i] = [];
	$weightAvgList->[$i] = [];
    }
    my $self = {
        t => 1, # number of iterations
        weightList => $weightList, # weight
        weightAvgList => $weightAvgList,    # averaged weight
	size => $size,
	opt => shift
    };
    bless ($self, $class);
    return $self;
}

sub compact {
    my ($self) = @_;
    $self->SUPER::compact;
    delete ($self->{weightAvgList});
    delete ($self->{t});
}

sub train {
    my ($self, $exampleList, $nIter) = @_;
    $self->SUPER::train ($exampleList, $nIter);

    # w* := w - w_avg / t
    my $t = $self->{t};
    for (my $y = 0, my $ly = scalar (@{$self->{weightList}}); $y < $ly; $y++) {
	my $weightList = $self->{weightList}->[$y];
	my $weightAvgList = $self->{weightAvgList}->[$y];
	for (my $f = 0, my $lf = scalar (@$weightList); $f < $lf; $f++) {
	    next unless (defined ($weightList->[$f]));
	    $weightList->[$f] -= $weightAvgList->[$f] / $t;
	}
    }
}

sub trainStep {
    my ($self, $example) = @_;

    my $vList = $self->classify ($example);
    my $yMax = $self->getMax ($vList);
    my $y = $example->{id};
    my $t = $self->{t}++;
    if ($yMax != $y) {
        $self->updateWeight ($y, $example, 1);
	my $correctV = $vList->[$y];

	my $updateList = [];
	for (my $i = 1, my $size = $self->{size}; $i < $size; $i++) {
	    if ($vList->[$i] > $correctV) {
		push (@$updateList, $i);
	    }
	}
	my $upCount = scalar (@$updateList);
	if ($upCount > 0) {
	    my $w = -1 / $upCount;
	    foreach my $i (@$updateList) {
		$self->updateWeight ($i, $example, $w);
	    }
	}
	return 0;
    }
    return 1;
}

sub updateWeight {
    my ($self, $y, $example, $w) = @_;

    my $t = $self->{t};
    my $weight = $self->{weightList}->[$y];
    my $weightAvg = $self->{weightAvgList}->[$y];
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	if (defined ($weight->[$feature])) {
	    $weight->[$feature] += $v * $w;
	    $weightAvg->[$feature] += $t * $v * $w;
	} else {
	    $weight->[$feature] = $v * $w;
	    $weightAvg->[$feature] = $t * $v * $w;
	}
    }
}

1;
