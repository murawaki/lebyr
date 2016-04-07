package JumanDictionary::EditDistance;

use strict;
use warnings;
use utf8;

use Encode;
use Scalar::Util qw/refaddr/;
use List::Util qw/max/;

use Egnee::Logger;
use SimString;
use JumanDictionary::Util;
use MorphemeUtilities;

our $CF_NOUN_THRES = 0.35;
our $CF_PRED_THRES = 0.25;
our $FILTER_THRES = 0.6;
our $LENGTH_THRES = 2;
our $ED_THRES = 0.5;
our $enc = Encode::find_encoding('utf8');

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift,
    };
    $self->{opt}->{deleteOnExit} = 0 unless (defined($self->{opt}->{deleteOnExit}));
    $self->{opt}->{debug} = 0        unless (defined($self->{opt}->{debug}));

    bless ($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    $self->close;

    delete($self->{cscfNoun});
    delete($self->{cscfPred});
}

sub setCSCF {
    my ($self, $noun, $pred) = @_;
    $self->{cscfNoun} = $noun;
    $self->{cscfPred} = $pred;
}

sub mergeVariant {
    my ($self, $me, $workingDictionary) = @_;

    return if ($me->{'意味情報'}->{'既知語帰着'});
    # policy:
    # 動詞 - 動詞: pred
    # イ形容詞 - イ形容詞: pred
    # ナ(ノ)形容詞 - ナ(ノ)形容詞: pred
    ##   ナ形容詞 - 名詞: +noun
    # 名詞 - 名詞: noun
    #     サ変名詞 - サ変名詞: +pred
    #
    # reject:
    #   名詞 - 名詞-人名

    my $cands = $self->getCands($me);
    return unless (scalar(@$cands) > 0);

    my $nounStruct = [$self->{cscfNoun}, {}, \&_getNounKey];
    my $predStruct = [$self->{cscfPred}, { verb => 1 }, \&_getPredKey];

    my ($cscf, $simOpt, $keyfunc) = ($me->{'品詞'} eq '名詞')?
	@$nounStruct : @$predStruct;

    my $repname = &$keyfunc($me);
    my $repnameP = &{$predStruct->[2]}($me) if (($me->{'品詞細分類'} || '') eq 'サ変名詞');

    # single entry for nouns, possibly multiple entries for verbs and adjectives
    my ($maxME, $maxScore) = (undef, -1);
    my $finals = [];
    foreach my $me2 (@$cands) {
	my $repname2 = &$keyfunc($me2);
	my $score = $cscf->CalcSimilarity($repname, $repname2, $simOpt);
	if (defined($repnameP) && ($me2->{'品詞細分類'} || '') eq 'サ変名詞') {
	    my $repnameP2 = &{$predStruct->[2]}($me2);
	    my $score2 = $predStruct->[0]->CalcSimilarity($repnameP, $repnameP2, $predStruct->[1]);
	    $score = max($score, $score2);
	}
	Egnee::Logger::info(sprintf("%s\t%s\t%f\n", join('-', keys(%{$me->{'見出し語'}})),
				    join('-', keys(%{$me2->{'見出し語'}})), $score));

	if ($score >= $CF_NOUN_THRES && $score > $maxScore) {
	    $maxME = $me2;
	    $maxScore = $score;
	}
	if ($score >= $CF_PRED_THRES) {
	    push(@$finals, $me2);
	}
    }

    if (defined($maxME)) {
	if (($maxME->{'品詞細分類'} || '') eq '人名') {
	    # # only Japanese?
	    # (defined($maxME->{'意味情報'}->{'人名'}) && $maxME->{'意味情報'}->{'人名'} =~ /^日本\:/)
	    Egnee::Logger::info(sprintf("person name\t%s\t%s\n", join('-', keys(%{$me->{'見出し語'}})),
					join('-', keys(%{$maxME->{'見出し語'}}))));
	    return;
	}
    }
    if (($me->{'品詞'} eq '動詞' or $me->{'品詞'} eq '形容詞') and scalar(@$finals) > 0) {
	$me->{'意味情報'}->{'既知語帰着'} = '表記・出現類似';
	my $clones = [];
	# NOTE: some repname has more than one morpheme entry, e.g. 凄い, すっごい
	#   randomly select one morpheme as the norm
	my $finals = &_uniqMEByRepname($finals);
	for (my $i = 1; $i < scalar(@$finals); $i++) {
	    push(@$clones, $me->clone);
	}
	my $me2 = pop(@$finals);
	$self->copyMEInfo($me, $me2);
	while ((my $me2 = pop(@$finals))) {
	    my $clone = pop(@$clones);
	    $self->copyMEInfo($clone, $me2);
	    $workingDictionary->addMorpheme($clone);
	}
    } elsif (defined($maxME)) {
	$me->{'意味情報'}->{'既知語帰着'} = '表記・出現類似';
	$self->copyMEInfo($me, $maxME);
    }
}

sub copyMEInfo {
    my ($self, $to, $from) = @_;

    $to->{'品詞'} = $from->{'品詞'};
    delete($to->{'品詞細分類'});
    $to->{'品詞細分類'} = $from->{'品詞細分類'} if (defined($from->{'品詞細分類'}));
    delete($to->{'活用型'});
    $to->{'活用型'} = $from->{'活用型'} if (defined($from->{'活用型'}));
    foreach my $key (keys(%{$from->{'意味情報'}})) {
	$to->{'意味情報'}->{$key} = $from->{'意味情報'}->{$key};
    }
    delete($to->{'意味情報'}->{'意味分類'});
    # TODO: yomi?
}

sub close {
    my ($self) = @_;

    if ($self->{filterDB}) {
	$self->{filterDB}->close;
	delete($self->{filterDB});
	$self->deleteFilterDB if ($self->{opt}->{deleteOnExit});
    }
}

sub deleteFilterDB {
    my ($self) = @_;

    foreach my $path (glob($self->{dbPath} . '*')) {
	unlink($path);
    }
}

sub openFilterDB {
    my ($self, $dbPath) = @_;

    my $db = SimString::Reader->new($dbPath);
    $db->{measure} = $SimString::overlap;
    $db->{threshold} = $FILTER_THRES;
    $self->{filterDB} = $db;
}

sub buildFilterDB {
    my ($self, $dbPath, $meList) = @_;

    $self->{dbPath} = $dbPath;
    my $db = SimString::Writer->new($dbPath, 3, 1);
    my $list = {};
    foreach my $me (@$meList) {
	foreach my $midasi (keys(%{$me->{'見出し語'}})) {
	    my $stem = ($me->{'活用型'})?
		&MorphemeUtilities::getInflectedForm($midasi, $me->{'活用型'}, '基本形', '語幹')
		: $midasi;
	    next unless ($stem);
	    my $kana = Unicode::Japanese->new($stem)->kata2hira->getu;
	    my $norm = &JumanDictionary::Util::romanize($kana);
	    unless (defined($list->{$norm})) {
		$db->insert($enc->encode($norm));
	    }
	    $list->{$norm}->{kana} = $kana;
	    push(@{$list->{$norm}->{meList}}, $me);
	}
    }
    $db->close;
    $self->{norm2meList} = $list;
    $self->openFilterDB($dbPath);
}

# three-stage enumeration of variant candidates
# 1. rough enumeration using the overlap of substrings
# 2. filtering based on POS consistency
# 3. edit-distance-based filtering
sub getCands {
    my ($self, $me) = @_;

    my $rv = [];
    my $norm2meList = $self->{norm2meList};
    foreach my $midasi (keys(%{$me->{'見出し語'}})) {
	my $stem = ($me->{'活用型'})?
	    &MorphemeUtilities::getInflectedForm($midasi, $me->{'活用型'}, '基本形', '語幹')
	    : $midasi;
	my $kana = Unicode::Japanese->new($stem)->kata2hira->getu;
	my $norm = &JumanDictionary::Util::romanize($kana);
	my $list = $self->getFilteredCands($norm);
	foreach my $norm2 (@$list) {
	    my $kana2 = $norm2meList->{$norm2}->{kana};
	    next unless (abs(length($kana) - length($kana2)) <= $LENGTH_THRES);
	    my $meList = $norm2meList->{$norm2}->{meList};
	    my @filtered = grep {
		&MorphemeGrammar::isPOSConsistent($me->{'品詞'}, $me->{'品詞細分類'}, $me->{'活用型'},
						  $_->{'品詞'}, $_->{'品詞細分類'}, $_->{'活用型'}, $_) } (@$meList);
	    next unless (scalar(@filtered) > 0);
	    my $score = &JumanDictionary::Util::calcNormalizedEditDistance($kana, $kana2);
	    next unless ($score <= $ED_THRES);
	    push(@$rv, @filtered);
	}
    }
    return _uniqME($rv);
}

sub getFilteredCands {
    my ($self, $norm) = @_;

    my $flagged = $self->{filterDB}->retrieve($enc->encode($norm));
    my @list = map { $enc->decode($_) } (@$flagged);
    return \@list;
}

sub _uniqME {
    my ($meList) = @_;

    my $tmp = {};
    my $rv = [];
    foreach my $me (@$meList) {
	my $addr = refaddr($me);
	unless (defined($tmp->{$addr})) {
	    push(@$rv, $me);
	    $tmp->{$addr} = 1;
	}
    }
    return $rv;
}

sub _uniqMEByRepname {
    my ($meList) = @_;

    my $tmp = {};
    my $rv = [];
    foreach my $me (@$meList) {
	my $repname = &JumanDictionary::Util::getRepname($me);
	unless (defined($tmp->{$repname})) {
	    push(@$rv, $me);
	    $tmp->{$repname} = 1;
	}
    }
    return $rv;
}

sub _getNounKey {
    return &JumanDictionary::Util::getRepname($_[0]);
}

sub _getPredKey {
    my ($me) = @_;

    my $type = substr($me->{'品詞'}, 0, 1);    
    if (($me->{'品詞細分類'} || '') eq 'サ変名詞') {
	$type = '動';
    }
    return &JumanDictionary::Util::getRepname($me) . ':' . $type;
}

1;
