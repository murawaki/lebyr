package BinaryClassifier::PassiveAggressive;
#
# binary PA-I
#
use strict;
use warnings;
use utf8;
use base qw/BinaryClassifier/;
use List::Util qw/max min/;

our $C = 1.0;

sub trainStep {
    my ($self, $example) = @_;
    my $featureList = $example->{featureList};

    my $val = $self->classify($example);
    my $s = ($val > 0)? 1 : -1;
    my $r = $example->{label};
    my $loss = max(0.0, 1.0 - $r * $val);
    return 1 if ($loss <= 0.0); # margin is large enough

    $self->{t}++;
    my $tauDenom = 0;
    while ((my ($feature, $v) = each(%$featureList))) {
	$tauDenom += $v * $v;
    }
    my $tau = min($C, $loss / $tauDenom);

    my $weight = $self->{weight};
    my $avgWeight = $self->{avgWeight};
    my $w = $tau * $r;
    my $t = $self->{t};
    while ((my ($feature, $v) = each(%$featureList))) {
	$weight->{$feature} += $v * $w;
	$avgWeight->{$feature} += $t * $v * $w if ($self->{opt}->{avg});
    }
    return ($loss < 1.0)? 1 : 0;
}

1;
