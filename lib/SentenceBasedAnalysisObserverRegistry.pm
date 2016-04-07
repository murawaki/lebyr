package SentenceBasedAnalysisObserverRegistry;
#
# AnalysisObserver のサブクラス
# 解析結果を受け取って、一文ごとの解析結果を
# 各 Observer に渡す
#
# 各 Observer は、
# (1) Document が代わる毎に onDocumentChange (optional)
# (2) 各文について onSentenceAvailable
# が呼ばれる
#
# Observer は登録順に呼ばれる
#
use strict;
use utf8;
use base qw/AnalysisObserver/;
use constant {
    CLASS_OBSERVER => 1,
    SUBROUTINE_OBSERVER => 2
};

use Encode qw/encode_utf8/;
use Scalar::Util qw/refaddr/;
use Digest::MD5 qw/md5_base64/;

use Egnee::Logger;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	requiredAnalysis => 'sentence',
	observerList => [],
	opt => shift
    };
    # default settings
    $self->{opt}->{uniqueFlag} = 0 unless (defined($self->{opt}->{uniqueFlag}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

sub add {
    my ($self, $id, $observer, $opt) = @_;

    foreach my $struct (@{$self->{observerList}}) {
	my ($id2, $observer2, $type2, $opt2) = @$struct;
	if ($id eq $id2) {
	    Egnee::Logger::warn("$id already registered\n");
	    return undef;
	}
    }

    if (defined($opt)) {
	if ($opt->{'getUnique'}) {
	    $self->{opt}->{'uniqueFlag'} = 1;
	}
    } else {
	$opt = {};
    }
    push(@{$self->{observerList}}, [$id, $observer, CLASS_OBSERVER, $opt]);

    return $observer;
}

sub get {
    my ($self, $id) = @_;

    foreach my $struct (@{$self->{observerList}}) {
	my ($id2, $observer2, $type2, $opt2) = @$struct;
	if ($id eq $id2) {
	    return $observer2;
	}
    }
    return undef;
}

sub remove {
    my ($self, $id) = @_;

    my $found = 0;
    my $newList = [];
    foreach my $struct (@{$self->{observerList}}) {
	my ($id2, $observer2, $type2, $opt2) = @$struct;
	if ($id eq $id2) {
	    $found = 1;
	} else {
	    push(@$newList, $struct);
	}
    }
    my $self->{observerList} = $newList;

    unless ($found) {
	Egnee::Logger::warn("$id not found\n");
    }
}

# インスタンスではなく、サブルーチンを登録する
sub addHook {
    my ($self, $func, $opt) = @_;

    if (defined($opt)) {
	if ($opt->{'getUnique'}) {
	    $self->{opt}->{'uniqueFlag'} = 1;
	}
    } else {
	$opt = {};
    }
    push(@{$self->{observerList}}, [refaddr ($func), $func, SUBROUTINE_OBSERVER, $opt]);
}

sub removeHook {
    my ($self, $func) = @_;
    $self->remove(ref($func));
}

#
# 一つの serviceID、あるいはリスト
#
sub getRequiredAnalysis {
    my ($self) = @_;
    return $self->{requiredAnalysis};
}

sub onDataAvailable {
    my ($self, $document) = @_;

    my $sentenceList = $document->getAnalysis('sentence');
    return unless (defined($sentenceList));

    foreach my $struct (@{$self->{observerList}}) {
	my ($observerID, $observer, $type, $opt) = @$struct;
	next unless ($type == CLASS_OBSERVER);
	if ($observer->can('onDocumentChange')) {
	    $observer->onDocumentChange($document);
	}
    }

    my %udb;
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	unless ($sentence->get('knp')) {
	    Egnee::Logger::warn("failed to get knp result\n");
	    next;
	}
	my $rawString = $sentence->get('raw');

	my $isUnique = 1;
	if ($self->{opt}->{'uniqueFlag'}) {
	    my $digest = md5_base64(encode_utf8($rawString));
	    if (defined($udb{$digest})) {
		$isUnique = 0;

		Egnee::Logger::info("dup raw string: $rawString\n");
	    }
	    $udb{$digest}++;
	}

	foreach my $struct (@{$self->{observerList}}) {
	    my ($observerID, $obj, $type, $opt) = @$struct;
	    if ($isUnique || !$opt->{'getUnique'}) {
		if ($type == CLASS_OBSERVER) {
		    $obj->onSentenceAvailable($sentence);
		} else {
		    &$obj($sentence);
		}
	    }
	}
    }
}

sub evokeListener {
    my ($self, $sentence) = @_;

    foreach my $struct (@{$self->{observerList}}) {
	my ($observerID, $obj, $type, $opt) = @$struct;
	if ($type == CLASS_OBSERVER) {
	    $obj->onSentenceAvailable($sentence);
	} else {
	    &$obj($sentence);
	}
    }
}

1;
