package Analyzer::Raw;

use strict;
use warnings;
use utf8;
use base qw/Analyzer/;

use Egnee::Logger;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	serviceID => shift,
	opt => shift
    };

    # default settings
    $self->{serviceID} = 'raw' unless (defined $self->{serviceID});
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

# dummy
sub update {}
sub getAnalyzer {}

# convert Juman::Result or KNP::Result into a raw sentence
sub exec {
    my ($self, $source, $type) = @_;

    unless ($type eq 'juman' || $type eq 'knp') {
	Egnee::Logger::warn("$type not supported\n");
	return undef;
    }
    my $result = join('', (map { $_->midasi } ($source->mrph)));
    return $result;
}

sub serialize {
    my ($self, $data) = @_;
    return $data;
}

sub deserialize {
    my ($self, $data) = @_;
    return $data;
}

1;
