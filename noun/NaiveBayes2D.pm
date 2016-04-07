package NaiveBayes2D;

use base qw (NaiveBayes);
use utf8;
use strict;
# use warnings;

use NounCategory qw/ $CLASSID_LENGTH /;

our $ZERO_LOGPROB = log (1e-4);
our $CATEGORY_LENGTH = $CLASSID_LENGTH / 2;

sub DESTROY {
    my ($self) = @_;

}

sub addExample {
    my ($self, $example) = @_;

    my $id = $example->{id};
    my ($id0, $id1) = split (/\:/, &NounCategory::index2classID ($id));

    $self->{nameList}->{$example->{name}}->[0]->[$id0]++;
    $self->{nameList}->{$example->{name}}->[1]->[$id1]++;
    $self->{idList}->[0]->[$id0]++;
    $self->{idList}->[1]->[$id1]++;

    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	$featureList->[$cfid]->[0]->[$id0]++;
	$featureList->[$cfid]->[1]->[$id1]++;
    }

}

sub addExampleProb {
    my ($self, $example, $probList) = @_;

    for (my $id = 0; $id < scalar (@$probList); $id++) {
	my $prob = $probList->[$id];
	my ($id0, $id1) = split (/\:/, &NounCategory::index2classID ($id));

	$self->{nameList}->{$example->{name}}->[0]->[$id0] += $prob;
	$self->{nameList}->{$example->{name}}->[1]->[$id1] += $prob;
	$self->{idList}->[0]->[$id0] += $prob;
	$self->{idList}->[1]->[$id1] += $prob;
    }
    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	for (my $id = 0; $id < scalar (@$probList); $id++) {
	    my $prob = $probList->[$id];
	    my ($id0, $id1) = split (/\:/, &NounCategory::index2classID ($id));
	    $featureList->[$cfid]->[0]->[$id0] += $prob;
	    $featureList->[$cfid]->[1]->[$id1] += $prob;
	}
    }
}

sub deleteExample {
    my ($self, $example) = @_;

    my $id = $example->{id};
    my ($id0, $id1) = split (/\:/, &NounCategory::index2classID ($id));

    $self->{nameList}->{$example->{name}}->[0]->[$id0]--;
    $self->{nameList}->{$example->{name}}->[1]->[$id1]--;
    $self->{idList}->[0]->[$id0]--;
    $self->{idList}->[1]->[$id1]--;

    my $featureList = $self->{featureList};
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;
	$featureList->[$cfid]->[0]->[$id0]--;
	$featureList->[$cfid]->[1]->[$id1]--;
    }

}

sub classify {
    my ($self, $example) = @_;
    my $featureList = $self->{featureList};
    my $idList = $self->{idList};

    my $name = $example->{name};
    my $nameList = $self->{nameList}->{$name};
    my $idDenom = ($nameList->[0]->[0] || 0) + ($nameList->[0]->[1] || 0);
#     my $idDenom1 = 0;
#     for (my $id1 = 0; $id1 < $CATEGORY_LENGTH; $id1++) {
# 	$idDenom1 += $nameList->[1]->[$id1] || 0;
#     }
    my $prob00 = ($idDenom > 0)? ($nameList->[0]->[0] || 0) / $idDenom : 0;
    my $prob01 = ($idDenom > 0)? ($nameList->[0]->[1] || 0) / $idDenom : 0;
    my $logProbRigid =
	[
	 ($prob00 > 0)? log ($prob00) : $ZERO_LOGPROB,
	 ($prob01 > 0)? log ($prob01) : $ZERO_LOGPROB,
	 ];


    my $logProb = [];
    for (my $id1 = 0; $id1 < $CATEGORY_LENGTH; $id1++) {
	my $prob1 = ($idDenom > 0)? ($nameList->[1]->[$id1] || 0) / $idDenom : 0;
	my $logProb1 = ($prob1 > 0)? log ($prob1) : $ZERO_LOGPROB;

	$logProb->[$id1] = $logProbRigid->[0] + $logProb1;
	$logProb->[$id1 + $CATEGORY_LENGTH] = $logProbRigid->[1] + $logProb1;
    }
    foreach my $f (@{$example->{featureList}}) {
	my ($cfid, $v) = @$f;

	my $prob00 = ($featureList->[$cfid]->[0]->[0] || 0) / $idList->[0]->[0];
	my $prob01 = ($featureList->[$cfid]->[0]->[1] || 0) / $idList->[0]->[1];
	my $logProb00 = ($prob00 > 0)? log ( $prob00) : $ZERO_LOGPROB;
	my $logProb01 = ($prob01 > 0)? log ( $prob01) : $ZERO_LOGPROB;
	for (my $id1 = 0; $id1 < $CATEGORY_LENGTH; $id1++) {
	    my $prob = ($featureList->[$cfid]->[1]->[$id1] || 0) / $idList->[1]->[$id1];
	    my $logProb1 = ($prob > 0)? log ( $prob) : $ZERO_LOGPROB;

	    $logProb->[$id1] += $logProb00 + $logProb1;
	    $logProb->[$id1 + $CATEGORY_LENGTH] += $logProb01 + $logProb1;
	}
    }
    return $logProb;
}

1;
