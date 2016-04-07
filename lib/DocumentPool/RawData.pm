package DocumentPool::RawData;
#
# one document per article
#
use strict;
use utf8;
use warnings;
use base qw /DocumentPool/;

use IO::File;
# use PerlIO::via::Bzip2; # MEMORY LEAK!!!!
use KNP::Result;

use Egnee::Logger;
use Document;
use Sentence;
use LinkedList;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	status => 0,
	filePath => shift,
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    if (defined($self->{input})) {
	$self->{input}->close;
	undef($self->{knpFile});
    }
}

sub init {
    my ($self) = @_;

    my $input;
    if ($self->{opt}->{compressed}) {
	open($input, '-|', "bzcat $self->{filePath}") or die;
    } else {
	$input = IO::File->new($self->{filePath}) or die;
    }
    $input->binmode(':utf8');
    # $input->binmode(($self->{opt}->{compressed})? ':via(Bzip2):utf8' : ':utf8') or die;
    $self->{input} = $input;
    $self->{status} = 1;
}

sub get {
    my ($self) = @_;

    return undef if ($self->{status} < 0);
    $self->init if ($self->{status} == 0);

    my $document = Document->new;
    if (defined($self->{buffered})) {
	$document->setAnnotation('documentID', $self->{buffered});
    } else {
	my $line = $self->{input}->getline;
	if ($line =~ /^\#document\s+(.+)/) {
	    $document->setAnnotation('documentID', $1);
	} else {
	    die("malformed input: $line\n");
	}
    }

    my $sentenceList = LinkedList->new;
    $document->setAnalysis('sentence', $sentenceList);
    my $counter = 0;

    while (1) {
	my $line = $self->{input}->getline;
	unless (defined($line)) {
	    $self->{status} = -1;
	    $self->{input}->close;
	    undef($self->{input});
	    last;
	}
	if ($line =~ /^\#document/) {
	    if ($line =~ /^\#document\s+(.+)/) {
		$self->{buffered} = $1;
		last;
	    } else {
		die("malformed input: $line\n");
	    }
	}
	my $sentence = Sentence->new({ raw => $line });
	$sentenceList->insert($counter++, $sentence);
    }
    return $document;
}

# under construction
sub add {
    my ($self, $document) = @_;

    return;
}

sub isEmpty {
    my ($self) = @_;

    return ($self->{status} >= 0);
}

1;
