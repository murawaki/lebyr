package MultiClassClassifier;
#
# abstract class for multi-class classifiers
#
use strict;
use warnings;
use utf8;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $size = shift;

    my $weightList = [];
    for (my $i = 0; $i < $size; $i++) {
	$weightList->[$i] = [];
    }
    my $self = {
        weightList => $weightList,
	size => $size,
	opt => shift
    };
    bless($self, $class);
    return $self;
}

sub compact {
    my ($self) = @_;
    bless($self, __PACKAGE__);
}

sub classify {
    my ($self, $example) = @_;

    my $vList = [];
    my $size = $self->{size};
    for (my $i = 0; $i < $size; $i++) {
	$vList->[$i] = 0;
    }
    my $weightList = $self->{weightList};
    foreach my $f (@{$example->{featureList}}) {
	my ($feature, $v) = @$f;
	for (my $i = 0; $i < $size; $i++) {
	    $vList->[$i] += $v * ($weightList->[$i]->[$feature] || 0);
	}
    }
    return $vList;
}

sub classifyMax {
    my ($self, $example) = @_;

    my $vList = $self->classify($example);
    return $self->getMax($vList);
}

sub getMax {
    my ($self, $vList) = @_;

    my $maxID = 0;
    my $maxV = $vList->[0];
    for (my $id = 1; $id < scalar(@$vList); $id++) {
	my $v = $vList->[$id];
	if ($v > $maxV) {
	    $maxID = $id;
	    $maxV = $v;
	}
    }
    return $maxID;
}

sub train {
    my ($self, $exampleList, $nIter) = @_;
    return if (!$exampleList || $nIter < 1);

    for (my $i = 0; $i < $nIter; $i++) {
	$exampleList->reset;
	my $correct = 0;
	my $total = 0;
	while ((my $example = $exampleList->readNext)) {
	    $total++;
            $correct += $self->trainStep($example);
        }
	if ($self->{opt}->{debug}) {
	    printf STDERR ("iter %d:\t%f%% (%d / %d)\n", $i, $correct / $total, $correct, $total);
	}
    }
}

# Each subclass should implement trainStep
#   return value is 1 if the example is correctly classified, and 0 otherwise

1;
