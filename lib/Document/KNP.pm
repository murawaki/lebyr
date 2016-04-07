package Document::KNP;
#
# wrapper for KNP::Result
#
use strict;
use utf8;
use base qw/Document/;

use IO::Scalar;
use IO::File;
use KNP::Result;
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
    my $fh;
    if ($self->{opt}->{inputType} eq 'file') {
	$fh = IO::File->new($self->{input});
	$fh->binmode(':' . $self->{opt}->{encoding});
    } else {
	$fh = IO::Scalar->new($self->{input});
    }
    my $buffer = [];
    while (my $line = $fh->getline) {
	push(@$buffer, $line);
	if ($line =~ /^EOS/) {
	    my $knpResult;
	    eval {
		$knpResult = KNP::Result->new($buffer);
	    };
	    if ($@) {
		$self->warn($@);
	    } else {
		$output->append(Sentence->new({ knp => $knpResult }));
	    }
	    $buffer = [];
	}
    }
    $fh->close;
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
