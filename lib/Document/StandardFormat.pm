package Document::StandardFormat;
#
# Document class for Standard format
#
use strict;
use utf8;
use base qw/Document/;

use IO::File;
use XML::LibXML;
use KNP::Result;

use Egnee::Logger;
use Egnee::GlobalConf;
use Sentence;
use LinkedList;

our $sharedParser; # cache a XML::LibXML instance
BEGIN {
    Egnee::Logger::setLogger(0);
}

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	input => shift,
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0          unless (defined $self->{opt}->{debug});
    $self->{opt}->{inputType} = 'file' unless (defined $self->{opt}->{inputType});
    $self->{opt}->{encoding} = 'utf8'  unless (defined $self->{opt}->{encoding});
    $self->{opt}->{maxFileSize} = 1024 * 1024 * 16
	unless (defined $self->{opt}->{maxFileSize}); # 16MB (decompressed)

    bless($self, $class);
    $self->init;
    return $self;
}

sub init {
    my ($self) = @_;

    my $buf = '';
    if ($self->{opt}->{inputType} eq 'file') {
	# skip too large files
	my $fSize = (stat($self->{input}))[7];
	if ($fSize > $self->{opt}->{maxFileSize}) {
	    Egnee::Logger::warn(sprintf("%s exceeds file size limit: %d\n", $self->{input}, $fSize));
	    $self->{dom} = undef;
	    return;
	}

	my $fh = IO::File->new($self->{input}) or die;
	$fh->binmode(':' . $self->{opt}->{encoding});
	while ((my $line = $fh->getline)) {
	    chomp($line);;
	    $buf .= "$line\n";
	}
	$fh->close;
    } else {
	$buf = $self->{input};
    }

    my $parser = $sharedParser || ($sharedParser = XML::LibXML->new);
    eval {
	$self->{dom} = $parser->parse_string($buf);
    };
    if ($@) {
	Egnee::Logger::warn($@);
	$self->{dom} = undef;
    }
}

sub getAnalysis {
    my ($self, $serviceID) = @_;

    # 作成済みならそれを使う
    my $data = $self->SUPER::getAnalysis($serviceID);
    return $data if ($data);

    # sentence のみ自分で作る
    return undef unless (defined($self->{dom}));
    return undef unless ($serviceID eq 'sentence');

    my $nodeList = $self->{dom}->getElementsByTagName('Text');
    return undef if (!$nodeList);

    my $sList = $nodeList->get_node(0)->getElementsByTagName('S');
    my $rv = LinkedList->new;

    my $knpFlag = Egnee::GlobalConf::get('standardformat-document.use-knp-annotation');
    $knpFlag = 1 unless (defined($knpFlag));

    my $sNode;
    while (($sNode = $sList->shift)) {
	next if (($sNode->getAttribute('is_Japanese_Sentence') || $sNode->getAttribute('is_Normal_Sentence')) ne '1');

	my $sid = $sNode->getAttribute('Id');
	my $rawstringNode = $sNode->getElementsByTagName('RawString')->get_node(0);
	next unless ($rawstringNode);
	my $sentence = Sentence->new({ raw => $rawstringNode->textContent });
	$rv->insert($sid, $sentence);

	next unless ($knpFlag);
	my $annotationNode = $sNode->getElementsByTagName('Annotation')->get_node(0);
	if ($annotationNode) {
	    my $scheme = $annotationNode->getAttribute('Scheme');
	    if (defined($scheme) && ($scheme eq 'Knp' || $scheme eq 'SynGraph')) {
		my $knpRaw = $annotationNode->textContent;
		my $knpResult;
		eval {
		    $knpResult = KNP::Result->new($knpRaw);
		};
		if ($@) {
		    Egnee::Logger::warn($@);
		} else {
		    $sentence->set('knp', $knpResult);
		}
	    }
	}
    }
    return $self->setAnalysis('sentence', $rv);
}

sub isAnalysisAvailable {
    my ($self, $serviceID) = @_;

    return 0 unless (defined($self->{dom}));
    return 1 if ($serviceID eq 'sentence');
    return 0;
}

# methods specific to StandardFormat
sub url {
    my ($self) = @_;
    return (defined($self->{dom}))? $self->{dom}->documentElement->getAttribute('Url') : undef;
}

1;
