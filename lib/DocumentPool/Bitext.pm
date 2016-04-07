package DocumentPool::Bitext;
#
# EBMT 用の対訳テキスト (JST)
#   元の XML ファイルと
#   分野・論文ごとに並べ変えたテキストファイルを受け付ける
#
use strict;
use utf8;
use base qw /DocumentPool/;

use IO::File;

use Egnee::Logger;
use Document;
use Sentence;
use LinkedList;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	status => 1,
	filePath => shift,
	opt => shift
    };
    $self->{type} = ($self->{filePath} =~ /\.xml$/)? 'xml' : 'sorted';
    $self->{opt}->{debug} = 0          unless (defined $self->{opt}->{debug});
    $self->{opt}->{encoding} = 'utf8'  unless (defined $self->{opt}->{encoding});

    $self->{fh} = IO::File->new;
    $self->{fh}->open($self->{filePath}, "<:encoding($self->{opt}->{encoding})") or die;

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    if (defined($self->{fh})) {
	$self->close;
    }
}

sub close {
    my ($self) = @_;

    $self->{fh}->close;
    $self->{fh} = undef;
    $self->{status} = -1;
}

sub get {
    my ($self) = @_;

    return undef if ($self->{status} < 0);

    if ($self->{type} eq 'xml') {
	return $self->getXML;
    } else {
	return $self->getSorted;
    }
}

# 文書がバラバラになっている。
# 1文ごとに Document を作る
sub getXML {
    my ($self) = @_;

    my $input;
    while (defined(my $line = $self->{fh}->getline)) {
	if ($line =~ /\<i_sentence\>([^\>]+)\<\/i_sentence\>/) {
	    $input = $1;
	    last;
	} elsif ($line =~ /docid\=\"([^\"]+)\"/) {
	    $self->{curDocID} = $1;
	} elsif ($line =~ /\<para_sentence id=\"([^\"]+)\"/) {
	    $self->{curDocID} = $1;
	}
    }
    unless (defined($input)) {
	$self->close;
	return undef;
    }

    my $document = Document->new;
    $document->setAnnotation('documentID', $self->{curDocID});

    my $sentenceList = LinkedList->new;
    $document->setAnalysis('sentence', $sentenceList);
    my $sentence = Sentence->new({ raw => $input });
    $sentenceList->insert(0, $sentence);

    return $document;
}

# ID を元に論文ごとに文書を作る
sub getSorted {
    my ($self) = @_;

    my $sentenceList = LinkedList->new;

    my $curID = -1;
    if (defined($self->{bufferedID})) {
	$curID = $self->{bufferedID};
	$self->{bufferedID} = undef;
	my $line = $self->{fh}->getline;
	my $sentence = Sentence->new({ raw => $line });
	$sentenceList->append($sentence);
    }

    while (1) {
	my $line = $self->{fh}->getline;
	last unless (defined($line));
	chomp($line);
	if ($line =~ /^\# [A-Za-z] ([0-9_A-Z\.]+) [0-9]+ [0-9]+$/) {
	    my $id = $1;
	    if ($curID >= 0 && $id ne $curID) {
		$self->{bufferedID} = $id;
		last;
	    }
	    $curID = $id;
	} else {
	    Egnee::Logger::warn("malformed input: $line\n");
	}
	my $line = $self->{fh}->getline;
	my $sentence = Sentence->new({ raw => $line });
	$sentenceList->append($sentence);
    }
    if ($sentenceList->length <= 0) {
	$self->close;
	return undef;
    }

    my $document = Document->new;
    $document->setAnnotation('documentID', $curID);
    $document->setAnalysis('sentence', $sentenceList);
    return $document;
}

sub isEmpty {
    my ($self) = @_;
    return ($self->{status} > 0)? 1 : 0;
}

1;
