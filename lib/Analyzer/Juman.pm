package Analyzer::Juman;

use strict;
use warnings;
use utf8;
use base qw/Analyzer/;

use Egnee::Logger;
use Juman;
use Juman::Result;
use Juman::Morpheme;
use MorphemeUtilities;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	serviceID => shift,
	opt => shift
    };
    # default settings
    $self->{serviceID} = 'juman' unless (defined($self->{serviceID}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    $self->init;
    return $self;
}

sub init {
    my ($self) = @_;

    if (defined($self->{juman})) {
	$self->{juman}->close;
    }
    my $juman = Juman->new($self->{opt}->{jumanOpt});
    $self->{juman} = $juman;
}

sub update {
    ($_[0])->init;
}

sub getAnalyzer {
    return ($_[0])->{juman};
}

sub exec {
    my ($self, $source, $type) = @_;

    if ($type eq 'knp') {
	return $self->knp2juman($source);
    }

    my $juman = $self->{juman};
    my $result;
    eval {
	$result = $juman->analysis($source);
	defined($result) or die "parsing failed (Juman).";
    };
    if ($@) {
	Egnee::Logger::warn($@);
	return undef;
    }
    return $result;
}

sub knp2juman {
    my ($self, $knpResult) = @_;

    my @mrph;
    foreach my $kmrph ($knpResult->mrph) {
	# TODO: speed-up
	my $orig = &MorphemeUtilities::getOriginalMrph($kmrph);

	# Juman::Morpheme#spec does not handle doukei
	my $spec .= $orig->Juman::Morpheme::spec;
	foreach my $doukei ($orig->doukei()){
	    $spec .= '@ ' . $doukei->spec();
	}
	my $jmrph = Juman::Morpheme->new($spec);
	push(@mrph, $jmrph);
    }
    my $jumanResult = Juman::Result->Juman::MList::new(@mrph);
    return $jumanResult;
}

sub serialize {
    my ($self, $data);
    return $data->spec;
}

sub deserialize {
    my ($self, $data) = @_;

    my $result;
    eval {
	$result = Juman::Result->new($data);
    };
    if ($@) {
	Egnee::Logger::warn($@);
	next;
    }
    return $result;
}

1;
