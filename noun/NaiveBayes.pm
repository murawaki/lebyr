package NaiveBayes;

use utf8;
use strict;
use warnings;

use NounCategory qw/ $CLASSID_LENGTH /;

our $ZERO_LOGPROB = log (1e-4);

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	nameList => {},    # $name -> $id : int
	featureList => [], # cfid -> $id : int
	idList => [],      # $id : int
	opt => shift,
	};
    bless ($self, $class);

    return $self;
}

sub addExample {
    my ($self, $example) = @_;

    my $id = $example->{id};
    $self->{nameList}->{$example->{name}}->[$id]++;
    $self->{idList}->[$id]++;

    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	$featureList->[$cfid]->[$id]++;
    }
}

sub addExampleProb {
    my ($self, $example, $probList) = @_;

    for (my $id = 0; $id < scalar (@$probList); $id++) {
	my $prob = $probList->[$id];
	$self->{nameList}->{$example->{name}}->[$id] += $prob;
	$self->{idList}->[$id] += $prob;
    }
    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	for (my $id = 0; $id < scalar (@$probList); $id++) {
	    $featureList->[$cfid]->[$id] += $probList->[$id];
	}
    }
}

sub deleteExample {
    my ($self, $example) = @_;

    my $id = $example->{id};
    $self->{nameList}->{$example->{name}}->[$id]--;
    $self->{idList}->[$id]--;

    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	$featureList->[$cfid]->[$id]--;
    }

}

sub classify {
    my ($self, $example) = @_;

    my $CLASS_SIZE = $self->{opt}->{classSize} || $CLASSID_LENGTH;

    my $nameList = $self->{nameList};
    my $featureList = $self->{featureList};
    my $idList = $self->{idList};

    # P(class|word)
    my $name = $example->{name};
    my $idDenom = 0;
    for (my $id = 0; $id < $CLASS_SIZE; $id++) {
	$idDenom += $nameList->{$name}->[$id] || 0;
    }
    my $logProb = [];
    for (my $id = 0; $id < $CLASS_SIZE; $id++) {
	my $prob = ($idDenom > 0)? ($nameList->{$name}->[$id] || 0) / $idDenom : 0;
	$logProb->[$id] = ($prob > 0)? log ($prob) : $ZERO_LOGPROB;
    }

    # P(feature|class)
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;

	for (my $id = 0; $id < $CLASS_SIZE; $id++) {
	    my $prob = ($featureList->[$cfid]->[$id] || 0) / $idList->[$id];
	    $logProb->[$id] += ($prob > 0)? log ($prob) : $ZERO_LOGPROB;
	}
    }
    return $logProb;
}

sub classifyMax {
    my ($self, $example) = @_;

    my $logProb = $self->classify ($example);
    return $self->getMax ($logProb);
}

sub getMax {
    my ($self, $logProb) = @_;

    my $maxID = 0;
    my $maxV = $logProb->[0];
    for (my $id = 1; $id < scalar (@$logProb); $id++) {
	my $v = $logProb->[$id];
	if ($v > $maxV) {
	    $maxID = $id;
	    $maxV = $v;
	}
    }
    return $maxID;
}

sub updateBySampling {
    my ($self, $example) = @_;

    $self->deleteExample ($example);
    # do some sampling
    my $logProb = $self->classify ($example);

    my $massList = [];
    my $sum = 0;
    my $base = int (-1 * $logProb->[0]);
    # binary search is unnecessary here
    foreach my $l (@$logProb) {
	# multiply by exp (128) to avoid underflow
	# a * C == exp (log (a * C)) == exp (log (a) + log (C))
	my $n = exp ($l + $base);
	$sum += $n;
	push (@$massList, $n);
    }
    my $current = 0;
    my $newID = 0;
    my $rand = rand;
    for (; $newID < scalar (@$massList); $newID++) {
	my $v = $massList->[$newID] / $sum;
	if ($rand >= $current && $rand <= $current + $v) {
	    last;
	} else {
	    $current += $v;
	}
    }
    $example->{id} = $newID;
    $self->addExample ($example);
    return $example;
}

sub updateByMAP {
    my ($self, $example) = @_;

    $self->deleteExample ($example);
    # do some sampling
    my $newID = $self->classifyMax ($example);
    $example->{id} = $newID;
    $self->addExample ($example);
    return $example;
}

sub updateByEM {
    my ($self, $example, $nb2) = @_;

    # do some sampling
    my $logProb = $self->classify ($example);
    $example->{id} = $self->getMax ($logProb);

    my $massList = [];
    my $sum = 0;
    my $base = int (-1 * $logProb->[$example->{id}]);
    # binary search is unnecessary here
    foreach my $l (@$logProb) {
	# multiply by exp to avoid underflow
	# a * C == exp (log (a * C)) == exp (log (a) + log (C))
	my $n = exp ($l + $base);
	$sum += $n;
	push (@$massList, $n);
    }
    my $current = 0;
    my $probList = [];
    for (my $newID = 0; $newID < scalar (@$massList); $newID++) {
	$probList->[$newID] = $massList->[$newID] / $sum;
    }
    $nb2->addExampleProb ($example, $probList);
}

1;
