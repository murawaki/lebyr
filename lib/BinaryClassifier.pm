package BinaryClassifier;
#
# abstract class for binary classifiers
#
use strict;
use warnings;
use utf8;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $weight = {};
    my $self = {
        weight => $weight,
	t => 0,
	opt => shift
    };
    $self->{opt}->{avg} = 1 unless (defined($self->{opt}->{avg}));
    $self->{avgWeight} = {} if ($self->{opt}->{avg});
    bless($self, $class);
    return $self;
}

sub load {
    my ($this, $obj) = @_;

    bless($obj, $obj->{CLASS});
    delete($obj->{CLASS});
    return $obj;
}

sub TO_JSON {
    my ($self) = @_;

    $self->finalize;
    return {
	weight => $self->{weight},
	opt => $self->{opt},
	CLASS => ref($self),
    };
}

sub finalize {
    my ($self) = @_;

    if ($self->{opt}->{avg} && $self->{avgWeight} && $self->{t} > 0) {
	my $t = $self->{t};
	my $weight = $self->{weight};
	my $avgWeight = $self->{avgWeight};
	while ((my ($k, $v) = each(%$avgWeight))) {
	    $weight->{$k} -= $avgWeight->{$k} / $t;
	}
    }
    delete($self->{avgWeight});
    delete($self->{t});
}

sub compact {
    my ($self) = @_;
    bless($self, __PACKAGE__);
}

sub classify {
    my ($self, $example) = @_;

    my $val = 0.0;
    my $weight = $self->{weight};
    my $featureList = $example->{featureList};
    while ((my ($feature, $v) = each(%$featureList))) {
	$val += $v * ($weight->{$feature} || 0.0);

    }
    return $val;
}

sub classifySign {
    my ($self, $example) = @_;
    return ($self->classify($example) > 0)? 1 : -1;
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
