package MultiClassClassifier::ConfidenceWeighted;
#
# multi-class confidence weighted
#   with single constraint updates (aka k=1 updates)
#
use strict;
use warnings;
use utf8;
use base qw/MultiClassClassifier/;

use Math::Cephes qw/:constants ndtri/;

our $NU = 0.1;
our $PHI = &quantile ($NU);

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $size = shift;

    my $weightList = [];
    my $covList = [];
    for (my $i = 0; $i < $size; $i++) {
	$weightList->[$i] = [];
	$covList->[$i] = [];
    }
    my $self = {
        weightList => $weightList, # mean
        covList => $covList,    # diag. covariance
	size => $size,
	opt => shift
    };
    bless ($self, $class);
    return $self;
}

sub compact {
    my ($self) = @_;
    $self->SUPER::compact;
    delete ($self->{covList});
}

sub trainStep {
    my ($self, $example) = @_;

    my $vList = $self->classify ($example);
    my @sortedV = sort { $vList->[$b] <=> $vList->[$a] } (0..($self->{size} - 1));
    my $y = $example->{id};
    my $r = shift (@sortedV);
    return 1 if ($y == $r);

    my $covList = $self->{covList};
    my $m = $vList->[$y] - $vList->[$r];
    my $vr = 0;
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	# g_{i, y_i, r}^T * sigma_i * g_{i, y_i, r} for both y_i and r
	$vr += $v * $v * (($covList->[$y]->[$feature] || 1) + ($covList->[$r]->[$feature] || 1));
    }
    my $t1 = 1 + 2 * $PHI * $m;
    my $gamma = (-1 * $t1 + sqrt ($t1 * $t1 - (8 * $PHI * ($m - $PHI * $vr)))) / (4 * $PHI * $vr);
    return 0 if ($gamma >= 0); # max (gamma, 0)

    # NEEDS re-investigation
    # \alpha_i * sigma_i * g_{i, y_i, r}
    # \alpha_i == gamma, so
    # gamma * cov->[y]->[j] * v_j  for y_i
    # gamma * cov->[y]->[j] * v_j  for r
    $self->updateMean ($y, $example, -1 * $gamma);
    $self->updateMean ($r, $example, $gamma);

    # sigma^{-1} + 2 * gamma * PHI * v_j   for y_i
    # sigma^{-1} - 2 * gamma * PHI * v_j   for r
    my $t2 = 2 * $gamma * $PHI;
    $self->updateCov ($y, $example, $t2);
    $self->updateCov ($r, $example, $t2);
    return 0;
}

sub updateMean {
    my ($self, $y, $example, $w) = @_;

    my $conv = $self->{covList}->[$y];
    my $weight = $self->{weightList}->[$y];
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	if (defined ($weight->[$feature])) {
	    $weight->[$feature] += $w * $conv->[$feature] * $v;
	} else {
	    $weight->[$feature] = $w * 1 * $v;
	}
    }
}

sub updateCov {
    my ($self, $y, $example, $w) = @_;

    my $conv = $self->{covList}->[$y];
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	unless (defined ($conv->[$feature])) {
	    $conv->[$feature] = 1;
	}
	# watch out underflow!
	# 1 / (( 1 / C ) + W)  == C / (1 + W * C)
	$conv->[$feature] = $conv->[$feature] / (1 + $w * $v * $v * $conv->[$feature]);
    }
}

# quantile function,
# or the inverse of the standard normal cumulative distribution function
sub quantile {
    return sqrt (2) * &erfi (2 * $_[0] - 1);
}

# inverse error function
sub erfi {
    return $SQRTH * ndtri ((1 + $_[0]) / 2);
}

1;
