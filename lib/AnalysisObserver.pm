package AnalysisObserver;
#
# abstract class for analysis observers
#
use strict;
use utf8;
use warnings;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	requiredAnalysis => undef,
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    return $self;
}


#
# one or more serviceIDs
#
sub getRequiredAnalysis {
    my ($self) = @_;
    return $self->{requiredAnalysis};
}

sub onDataAvailable {
    my ($self, $document) = @_;
    return;
}

1;
