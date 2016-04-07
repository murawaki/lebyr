package MultiClassClassifier::FactoredMatrix;
#
# multi-class classifier using factored matrix
#   buggy
#
use strict;
use warnings;
use utf8;
# use base qw/MultiClassClassifier/;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $size = shift;
    my $opt = shift || {};

    my $self = {
	size => $size,
	k => $opt->{k} || 100,            # reduced dimension
	lambda => $opt->{lambda} || 0.01, # update rate
	PC => $opt->{PC} || 0.0001,       # penalty consonant
	u => 0.0,  # cumulative penalty
	opt => $opt,
    };
    bless ($self, $class);
    $self->randomInit;
    
    return $self;
}

sub randomInit {
    my ($self) = @_;
    my $U = [];
    my $qU = [];
    my $V = [];
    my $qV = [];
    for (my $i = 0; $i < $self->{k}; $i++) {
	$U->[$i] = [];
	$V->[$i] = [];
	$qU->[$i] = [];
	$qV->[$i] = [];
	for (my $j = 0; $j < $self->{size}; $j++) {
	    $V->[$i]->[$j] = &drawGaussian (0.0, 0.1);
	    $V->[$i]->[$j] = 0.0;
	}
    }
    $self->{U} = $U;
    $self->{V} = $V;
    $self->{qU} = $qU;
    $self->{qV} = $qV;
}

sub classify {
    my ($self, $example) = @_;

    my $size = $self->{size};
    my $U = $self->{U};
    my $V = $self->{V};
    my $k = $self->{k};

    my $xUList = []; # x^T U^T
    for (my $i = 0; $i < $k; $i++) {
	$xUList->[$i] = 0;
    }
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	for (my $i = 0; $i < $k; $i++) {
	    $xUList->[$i] += $v * ($U->[$i]->[$feature] || 0);
	}
    }
    my $vList = [];
    for (my $i = 0; $i < $size; $i++) {
	my $sum = 0;
	for (my $j = 0; $j < $k; $j++) {
	    $sum += $xUList->[$j] * $V->[$j]->[$i];
	}
	$vList->[$i] = $sum;
    }
    return $vList;
}

sub classifyWithInit {
    my ($self, $example) = @_;

    my $size = $self->{size};
    my $U = $self->{U};
    my $V = $self->{V};
    my $k = $self->{k};

    my $xUList = []; # x^T U^T
    for (my $i = 0; $i < $k; $i++) {
	$xUList->[$i] = 0;
    }
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	unless (defined ($U->[0]->[$feature])) {
	    for (my $i = 0; $i < $k; $i++) {
		$U->[$i]->[$feature] = &drawGaussian (0.0, 0.1);
	    }
	}
	for (my $i = 0; $i < $k; $i++) {
	    $xUList->[$i] += $v * $U->[$i]->[$feature];
	}
    }
    my $vList = [];
    for (my $i = 0; $i < $size; $i++) {
	my $sum = 0;
	for (my $j = 0; $j < $k; $j++) {
	    $sum += $xUList->[$j] * $V->[$j]->[$i];
	}
	$vList->[$i] = $sum;
    }
    return $vList;
}

sub compact {
    my ($self) = @_;

    # TODO
}

sub classifyMax {
    my ($self, $example) = @_;

    my $vList = $self->classify ($example);
    return $self->getMax ($vList);
}

sub trainStep {
    my ($self, $example) = @_;

    my $u = ($self->{u} += $self->{PC});
    my $vList = $self->classifyWithInit ($example);
    my @sortedV = sort { $vList->[$b] <=> $vList->[$a] } (0..($self->{size} - 1));
    my $r = $example->{id};
    my $s = shift (@sortedV);
    $s = shift (@sortedV) if ($r == $s);

    my $gamma = $vList->[$r] - $vList->[$s];
    return 1 if ($gamma >= 1); # margin is large enough
    my $loss = 1.0 - $gamma;

    my $size = $self->{size};
    my $k = $self->{k};
    my $LAMBDA = $self->{lambda};
    my $U = $self->{U};
    my $V = $self->{V};
    my $qU = $self->{qU};
    my $qV = $self->{qV};
    if (rand (1.0) >= 0.5) {
	# update U
	my $VeList = [];
	for (my $i = 0; $i < $k; $i++) {
	    $VeList->[$i] = $V->[$i]->[$r] - $V->[$i]->[$s];
	}
	foreach my $f (@{$example->{featureList}}) {
	    my ($feature, $v) = @$f;
	    for (my $i = 0; $i < $k; $i++) {
		my $w = ($U->[$i]->[$feature] += $LAMBDA * $VeList->[$i] * $v);

		# apply penalty
		my $z = $w;
		my $q = $qU->[$i]->[$feature] || 0;
		if ($w > 0) {
		    $w = &max(0, $w - ($u + $q));
		} elsif ($w < 0) {
		    $w = &min(0, $w + ($u + $q));
		}
		$U->[$i]->[$feature] = $w;
		$qU->[$i]->[$feature] += $w - $z;
	    }
	}
    } else {
	# update V
	my $UxList = [];
	for (my $i = 0; $i < $k; $i++) {
	    $UxList->[$i] = 0;
	}
	foreach my $f (@{$example->{featureList}}) {
	    my ($feature, $v) = @$f;
	    for (my $i = 0; $i < $k; $i++) {
		$UxList->[$i] += $U->[$i]->[$feature] * $v;
	    }
	}
	for (my $i = 0; $i < $k; $i++) {
	    {
		my $w = ($V->[$i]->[$r] += $LAMBDA * $UxList->[$i]);

		# apply penalty
		my $z = $w;
		my $q = $qV->[$i]->[$r] || 0;
		if ($w > 0) {
		    $w = &max(0, $w - ($u + $q));
		} elsif ($w < 0) {
		    $w = &min(0, $w + ($u + $q));
		}
		$V->[$i]->[$r] = $w;
		$qV->[$i]->[$r] += $w - $z;
	    }
	    {
		my $w = ($V->[$i]->[$s] -= $LAMBDA * $UxList->[$i]);

		# apply penalty
		my $z = $w;
		my $q = $qV->[$i]->[$s] || 0;
		if ($w > 0) {
		    $w = &max(0, $w - ($u + $q));
		} elsif ($w < 0) {
		    $w = &min(0, $w + ($u + $q));
		}
		$V->[$i]->[$s] = $w;
		$qV->[$i]->[$s] += $w - $z;
	    }
	}
    }
    return ($gamma > 0)? 1 : 0;
}

# Marsaglia
sub drawGaussian {
    my ($mean, $variance) = @_;
    while (1) {
	my $z1 = rand (2) - 1; my $z2 = rand (2) - 1;
	my $r2 = $z1 * $z1 + $z2 * $z2;
	next unless ($r2 <= 1);

	my $t = sqrt ((-2 * log ($r2)) / $r2);
	my $y1 = $z1 * $t;
	my $x1 = $variance * $y1 + $mean;
	return $x1 unless (wantarray);

	my $y2 = $z2 * $t;
	my $x2 = $variance * $y2 + $mean;
	return ($x1, $x2);
    }
}

sub max { return ($_[0] > $_[1])? $_[0] : $_[1]; }
sub min { return ($_[0] < $_[1])? $_[0] : $_[1]; }

1;
