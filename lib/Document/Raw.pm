package Document::Raw;
#
# document consisting of raw sentences
#
use strict;
use utf8;
use base qw/Document/;

use IO::File;
use LinkedList;
use Sentence;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	input => shift,
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0          unless (defined($self->{opt}->{debug}));
    $self->{opt}->{inputType} = 'file' unless (defined($self->{opt}->{inputType}));
    $self->{opt}->{encoding} = 'utf8'  unless (defined($self->{opt}->{encoding}));

    bless($self, $class);
    $self->init;
    return $self;
}

sub init {
    my ($self) = @_;

    my $output = LinkedList->new;
    my $sid = 1;
    if ($self->{opt}->{inputType} eq 'file') {
	my $fh = IO::File->new($self->{input});
	$fh->binmode(':' . $self->{opt}->{encoding});
	while (my $line = $fh->getline) {
	    chomp($line);
	    $output->append(Sentence->new({ raw => "$line\n" }));
	}
	$fh->close;
    } elsif (ref($self->{input}) eq 'ARRAY') {
	map { $output->append({ raw => "$_\n"}) } (@{$self->{input}});
    } else {
	map { $output->append({ raw => "$_\n"}) } (split("\n", $self->{input}));
    }
    return $self->setAnalysis('sentence', $output);
}

sub getAnalysis {
    my ($self, $serviceID) = @_;

    # 作成済みならそれを使う
    my $data = $self->SUPER::getAnalysis($serviceID);
    return $data if ($data);
    return undef;
}

sub isAnalysisAvailable {
    my ($self, $serviceID) = @_;

    return ($serviceID eq 'sentence')? 1 : ( (defined($self->{$serviceID}))? 1 : 0 );
}

1;
