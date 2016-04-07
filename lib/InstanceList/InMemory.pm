#!/bin/env perl
#
# in-memory instance list
#
package InstanceList::InMemory;

use strict;
use warnings;
use utf8;

use LanguageModel::Util;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	list => [],
	idx => -1,
    };
    bless($self, $class);
    return $self;
}

sub append {
    my ($self, $instance) = @_;
    push(@{$self->{list}}, $instance);
}

sub shuffle {
    my ($self) = @_;
    LanguageModel::Util::shuffle($self->{list});
}

sub reset {
    my ($self) = @_;
    $self->{idx} = -1;
}

sub next {
    my ($self) = @_;
    my $idx = ++$self->{idx};
    if (scalar(@{$self->{list}}) <= $idx) {
	return undef;
    } else {
	return $self->{list}->[$idx];
    }
}

1;
