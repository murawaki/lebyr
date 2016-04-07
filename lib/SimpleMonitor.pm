package SimpleMonitor;

use MorphemeGrammar qw /$IMIS/;

use strict;
use utf8;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift
    };

    # デフォルト値の設定
    $self->{opt}->{debug} = 0           unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    return $self;
}

sub setCallback {
    my ($self, $code, $type) = @_;

    if ($type eq 'documentChange') {
	push(@{$self->{documentChange}}, $code);
    } elsif ($type eq 'sentenceAvailable') {
	push(@{$self->{sentenceAvailable}}, $code);
    } else {
	if ($self->{opt}->{debug}) {
	    printf STDERR ("no such type: %s\n", $type);
	}
    }
}

# SentenceBasedAnalysisObserverRegistry に登録しているので、document が渡される
sub onDocumentChange {
    my ($self, $document) = @_;

    $self->{documentCount}++;

    foreach my $code (@{$self->{documentChange}}) {
	&$code($self, $document);
    }
}

# SentenceBasedAnalysisObserverRegistry に登録しているので、sentence が渡される
sub onSentenceAvailable {
    my ($self, $sentence) = @_;

    my $knpResult = $sentence->get('knp');
    return unless (defined($knpResult));

    $self->{sentenceCount}++;
    foreach my $bnst ($knpResult->bnst) {
	$self->{bnstCount}++;

	foreach my $mrph ($bnst->mrph) {
	    $self->{mrphCount}++;

	    # 自動獲得
	    if (index($mrph->imis, '自動獲得:テキスト') >= 0) {
		$self->{acquisitionCount}++;
	    }
	}
    }

    foreach my $code (@{$self->{sentenceAvailable}}) {
	&$code($self, $knpResult);
    }
}

1;
