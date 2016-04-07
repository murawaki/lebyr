package MultiClassClassifier::Perceptron;

use strict;
use warnings;
use utf8;
use base qw/MultiClassClassifier/;

sub trainStep {
    my ($self, $example) = @_;

    my $vList = $self->classify ($example);
    my $yMax = $self->getMax ($vList);
    my $y = $example->{id};
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

    my $weight = $self->{weightList}->[$y];
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	if (defined ($weight->[$feature])) {
	    $weight->[$feature] += $v * $w;
	} else {
	    $weight->[$feature] = $v * $w;
	}
    }
}

1;
