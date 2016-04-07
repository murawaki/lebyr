package DocumentPool::KyotoCorpus;
#
# DocumentPool for KyotoCorpus
# one Document per article
#
use strict;
use warnings;
use utf8;
use base qw/DocumentPool/;

use IO::Dir;
use IO::File;
use KNP;
use KNP::Result;
use KNP::Morpheme;

use Egnee::Logger;
use Egnee::GlobalServices;
use Document;
use Sentence;
use LinkedList;

our $undefinedKatuyou1List = { # KNP exits when an undefined element is found
    '助動詞文語ぬ型' => '無活用型',
};

our $undefinedKatuyou2List = {
    '命令形エ形' => '命令形',
    'ダ列文語連体形' => 'ダ列基本連体形',
};

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	status => 0,
	dir => shift,
	opt => shift
    };
    $self->{opt}->{fullKNPFeatures} = 0 unless (defined($self->{opt}->{fullKNPFeatures}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{opt}->{encoding} = ':utf8' unless (defined($self->{opt}->{encoding}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    unless ( -d $self->{dir}
	     && -d "$self->{dir}/org"
	     && -d "$self->{dir}/knp" ) {
	$self->{status} = -1;
    }
    # $self->init (); # lazy
    return $self;
}

sub DESTROY {
    my ($self) = @_;

    if (defined($self->{orgFile})) {
	close($self->{orgFile});
	undef($self->{orgFile});
    }
    if (defined($self->{knpFile})) {
	close($self->{knpFile});
	undef($self->{knpFile});
    }
}

# initialization by examining the target directory
sub init {
    my ($self) = @_;

    $self->{fileIDList} = [];
    $self->{pointer} = 0;

    $self->{orgFile} = undef;
    $self->{knpFile} = undef;
    $self->{orgBuffer} = '';
    $self->{knpBuffer} = '';

    my $dir = IO::Dir->new("$self->{dir}/org") or die;
    foreach my $ftmp (sort {$a cmp $b} ($dir->read)) {
	if ($ftmp =~ /^(.*)\.org$/) {
	    push(@{$self->{fileIDList}}, $1);
	}
    }
    $dir->close;
    $self->{status} = 1;
}

sub get {
    my ($self) = @_;

    return undef if ($self->{status} < 0);
    $self->init if ($self->{status} == 0);

    # Document per article
    if (defined($self->{orgFile})) {
	# already open
	return $self->_nextDocument;
    }

    # end of file; examine next
    my $fileID = $self->{fileIDList}->[$self->{pointer}++];
    unless (defined($fileID)) {
	$self->{status} = -1;	
	return undef;
    }

    $self->{currentFileID} = $fileID;
    Egnee::Logger::info("fileID: $fileID\n");

    $self->{orgFile} = IO::File->new("$self->{dir}/org/$fileID.org") or die;
    $self->{knpFile} = IO::File->new("$self->{dir}/knp/$fileID.knp") or die;
    $self->{orgFile}->binmode($self->{opt}->{encoding});
    $self->{knpFile}->binmode($self->{opt}->{encoding});
    return $self->_nextDocument;
}

# TODO: simplify code
sub _nextDocument {
    my ($self) = @_;

    my $orgFile = $self->{orgFile};
    my $knpFile = $self->{knpFile};

    unless ($self->{orgBuffer}) {
	# just opened the file
	$self->{orgBuffer} = $orgFile->getline; chomp($self->{orgBuffer});
	$self->{knpBuffer} = $knpFile->getline; chomp($self->{knpBuffer});
	$self->{knpBuffer} .= "\n";
    }
    unless ($self->{orgBuffer}) {
	$orgFile->close;
	$knpFile->close;
	undef($self->{orgFile});
	undef($self->{knpFile});
	return undef;
    }

    my $docID;
    my $count;
    if ($self->{orgBuffer} =~ /^\# S-ID:([^-]+)-(\d+)/) {
	$docID = $1;
	$count = $2;
    } else {
	Egnee::Logger::warn("malformed input\n");
	$self->{status} = -1;
	return undef;
    }
    my $knpSID;
    if ($self->{knpBuffer} =~ /^\# S-ID:([^\s]+)/) {
	$knpSID = $1;
    } else {
	Egnee::Logger::warn("malformed input\n");
	$self->{status} = -1;
	return undef;
    }
    if ("$docID-$count" ne $knpSID) {
	Egnee::Logger::warn("malformed input\n");
	$self->{status} = -1;
	return undef;
    }

    Egnee::Logger::info("document: $docID\n");

    my $document = Document->new;
    $document->setAnnotation('documentID', $docID);

    my $sentenceList = LinkedList->new;
    $document->setAnalysis('sentence', $sentenceList);
    my $counter = 0;

    # $self->{orgBuffer} = $self->{knpBuffer} = '';
    $self->{orgBuffer} = '';
    my $flag = 0; # 1 なら S-ID 待ち
    while (1) {
	if ($flag) {
	    $self->{orgBuffer} = $orgFile->getline;
	    unless ($self->{orgBuffer}) {
		$self->{orgFile}->close;
		$self->{knpFile}->close;
		undef($self->{orgFile});
		undef($self->{knpFile});
		return $document;
	    }
	    chomp($self->{orgBuffer});
	    if ($self->{orgBuffer} =~ /^\# S-ID:([^-]+)-(.+)$/) {
		$count = $2;
		$counter++;
		if ($1 ne $docID) {
		    return $document;
		} else {
		    # $self->{orgBuffer} = $self->{knpBuffer} = '';
		    $self->{orgBuffer} = '';
		    $flag = 0;
		}
	    } else {
		Egnee::Logger::warn("malformed input\n");
		$self->{status} = -1;
		return undef;
	    }
	} else {
	    my $rawString = $orgFile->getline; chomp($rawString);
	    my $input = '';
	    while (($input = $knpFile->getline)) {
		chomp($input);
		if ($input =~ /^\# S-ID:([^-]+)-(.+)$/) {
		    last;
		} else {
		    $self->{knpBuffer} .= "$input\n";
		}
	    }
	    my $knpResult;
	    if ($self->{opt}->{fullKNPFeatures}) {
		my $knp = $self->getKNP;
		my @array;
		my $changeLog = {};
		if ($self->{opt}->{replaceUndefined}) {
		    my $idx = 0;
		    foreach my $line (split(/\n/, $self->{knpBuffer})) {
			if ($line =~ /^(?:[\#\*\+\;]|EOS)/) {
			    push(@array, $line . "\n");
			} else {
			    push(@array, $self->replaceUndefined($line, $changeLog, $idx++));
			}
		    }
		} else {
		    @array = map { $_ . "\n" } (split(/\n/, $self->{knpBuffer}));
		}
		eval {
		    $knpResult = $knp->_real_parse(\@array, $rawString);
		};
		if (@!) {
		    Egnee::Logger::warn("parsing failed: %s\n", $rawString);
		    $knpResult = KNP::Result->new($self->{knpBuffer}) or die;
		}
		if ($self->{opt}->{replaceUndefined}) {
		    $self->undoReplacement($knpResult, $changeLog);
		}
	    } else {
		$knpResult = KNP::Result->new($self->{knpBuffer}) or die;
	    }
	    $self->{knpBuffer} = ($input)? "$input\n" : '';
	    my $sentence = Sentence->new({ raw => $rawString, knp => $knpResult });
	    $sentenceList->insert($counter, $sentence);
	    $flag = 1;
	}
    }
}

sub replaceUndefined {
    my ($self, $line, $changeLog, $idx) = @_;

    my $mrph = KNP::Morpheme->new($line);
    my $katuyou1 = $undefinedKatuyou1List->{$mrph->katuyou1};
    my $katuyou2 = $undefinedKatuyou2List->{$mrph->katuyou2};
    if ($katuyou1 || $katuyou2) {
	if ($katuyou1) {
	    push(@{$changeLog->{$idx}}, ['katuyou1', $mrph->katuyou1]);
	    $mrph->{katuyou1} = $katuyou1;
	}
	if ($katuyou2) {
	    push(@{$changeLog->{$idx}}, ['katuyou2', $mrph->katuyou2]);
	    $mrph->{katuyou2} = $katuyou2;
	}
	return $mrph->spec;
    } else {
	return $line . "\n";
    }
}

sub undoReplacement {
    my ($self, $knpResult, $changeLog) = @_;

    while ((my ($idx, $changeList) = each(%$changeLog))) {
	foreach my $tmp (@$changeList) {
	    my ($key, $val) = @$tmp;
	    ($knpResult->mrph($idx))->{$key} = $val;
	}
    }
}

# under construction
sub add {
    my ($self, $document) = @_;
    return;
}

sub isEmpty {
    my ($self) = @_;
    return (scalar(@{$self->{documents}}) > 0);
}

sub getKNP {
    my ($self) = @_;
    unless (defined($self->{knp})) {
	my $registry = Egnee::GlobalServices::get('analyzer registry');
	if (defined($registry)) {
	    $self->{knp} = $registry->get('knp');
	} else {
	    Egnee::Logger::warn("analyzer registry not found\n");
	    return undef;
	}
    }
    return $self->{knp}->getAnalyzer;
}

1;
