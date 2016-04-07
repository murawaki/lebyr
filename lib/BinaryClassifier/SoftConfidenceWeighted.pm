package BinaryClassifier::SoftConfidenceWeighted;
#
# binary SCW-I (Wang et al. ICML2012)
#
use strict;
use warnings;
use utf8;
use base qw/BinaryClassifier/;
use List::Util qw/max min/;

use Math::Cephes qw/:constants ndtri/;

our $C = 1.0;
our $ETA = 0.9;
our $PHI = ndtri($ETA);
our $PHI2 = $PHI * $PHI;
our $PHI4 = $PHI2 * $PHI2;
our $PSI = 1.0 + $PHI2 / 2.0;
our $ZETA = 1.0 + $PHI2;


sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = {
        weight => {},
	cov => {},  # diag. of covariance
	opt => shift
    };
    bless ($self, $class);
    return $self;
}

sub TO_JSON {
    my ($self) = @_;

    return {
	weight => $self->{weight},
	opt => $self->{opt},
	CLASS => ref($self),
    };
}

sub trainStep {
    my ($self, $example) = @_;
    my $featureList = $example->{featureList};
    my $weight = $self->{weight};
    my $cov = $self->{cov};

    my $val = $self->classify($example);
    my $s = ($val > 0)? 1 : -1;
    my $r = $example->{label};
    my $isCorrect = ($s == $r)? 1 : 0;

    my $m = $val * $r;
    my $v = 0.0;
    while ((my ($feature, $val) = each(%$featureList))) {
	# lazy evaluation
	unless (defined($cov->{$feature})) {
	    $cov->{$feature} = 1.0;
	}
	$v += $cov->{$feature} * $val * $val;
    }

    my $alpha = (-$m * $PSI + sqrt($m * $m * $PHI4 / 4.0 + $v * $PHI2 * $ZETA)) / ($v * $ZETA);
    return $isCorrect if ($alpha <= 0.0);
    $alpha = $C if ($alpha > $C);

    my $u = ((-$alpha * $v * $PHI + sqrt($alpha * $alpha * $v * $v * $PHI2 + 4 * $v)) / 2.0) ** 2;
    my $beta = ($alpha * $PHI) / (sqrt($u) + $v * $alpha * $PHI);

    my $wCons = $alpha * $r;
    while ((my ($feature, $val) = each(%$featureList))) {
	$weight->{$feature} += $wCons * $cov->{$feature} * $val;
	$cov->{$feature} -= $beta * ($val ** 2) * ($cov->{$feature} ** 2);
    }
    return $isCorrect;
}

1;
