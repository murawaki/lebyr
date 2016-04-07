package MultiClassClassifier::PassiveAggressive;
#
# multi-class PA-I
#
use strict;
use warnings;
use utf8;
use base qw/MultiClassClassifier/;

our $C = 1.0;

sub trainStep {
    my ($self, $example) = @_;

    my $vList = $self->classify ($example);
    my @sortedV = sort { $vList->[$b] <=> $vList->[$a] } (0..($self->{size} - 1));
    my $r = $example->{id};
    my $s = shift (@sortedV);
    $s = shift (@sortedV) if ($r == $s);

    my $gamma = $vList->[$r] - $vList->[$s];
    return 1 if ($gamma >= 1); # margin is large enough
    my $loss = 1.0 - $gamma;

    my $tauDenom = 0;
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	# simply multiply by 2
	# since PHAI(x, r) and PHAI(x, s) has no intersection
	$tauDenom += $v * $v * 2;
    }
    my $tau = $loss / $tauDenom; $tau = $C if ($tau > $C);

    $self->updateWeight ($r, $example, $tau);
    $self->updateWeight ($s, $example, -1 * $tau);
    return ($gamma > 0)? 1 : 0;
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
