package Analyzer::KNP;

use strict;
use warnings;
use utf8;
use base qw/Analyzer/;

use Egnee::Logger;
use KNP;
use KNP::Result;

our $renewInterval = 10000;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	serviceID => shift,
	opt => shift,
    };
    # default settings
    $self->{serviceID} = 'knp' unless (defined($self->{serviceID}));
    $self->{opt}->{knpOption} = '-tab -check -dpnd' unless (defined($self->{opt}->{knpOption}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    $self->init;
    return $self;
}

sub init {
    my ($self) = @_;

    if (defined($self->{knp})) {
	$self->{knp}->close;
    }
    my $knp = KNP->new( -Option => $self->{opt}->{knpOption} );
    $self->{knp} = $knp;

    $self->{count} = 1; # not 0
    $self->{cache} = [];
}

sub update {
    ($_[0])->init;
}

sub getAnalyzer {
    return ($_[0])->{knp};
}

# NOTE: if 'raw' is set to type, JUMAN in the default settings is used
#   instead of Analyzer::JUMAN
sub exec {
    my ($self, $source, $type) = @_;

    unless ($type eq 'juman' || $type eq 'raw') {
	Egnee::Logger::warn("$type not supported\n");
	return undef;
    }
    unless ($self->{count} % $renewInterval) {
	$self->init;
    }

    if ($self->{opt}->{debug}) {
	my $rawSentence;
	if ($type eq 'raw') {
	    $rawSentence = $source;
	} else {
	    $rawSentence = join('', map { $_->midasi } ($source->mrph));
	}
	push(@{$self->{cache}}, $rawSentence);
    }

    my $knp = $self->{knp};
    $self->{count}++;
    my $result;
    eval {
	$result = $knp->parse($source);
	defined($result) or die("parsing failed (KNP)");
    };
    if ($@) {
	Egnee::Logger::warn($@);
	$self->init;
	return undef;
    }
    return $result;
}

sub serialize {
    my ($self, $data) = @_;
    return $data->spec;
}

sub deserialize {
    my ($self, $data) = @_;

    my $result;
    eval {
	$result = KNP::Result->new($data);
    };
    if ($@) {
	Egnee::Logger::warn($@);
	return undef;
    }
    return $result;
}

1;
