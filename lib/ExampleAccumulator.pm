package ExampleAccumulator;
use strict;
use warnings;
no warnings 'redefine'; # intentional
use utf8;

use Egnee::Logger;
use StringTrie;
use KatakanaExampleAccumulator;
use StemFinder qw/$minimumExampleNum/;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	dictionaryManager => shift,
	opt => shift,
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{trie} = StringTrie->new;
    $self->{total} = 0;

    $self->{katakana} = KatakanaExampleAccumulator->new($self->{dictionaryManager}, $self->{opt});

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

# 未知語構造体を格納。
# 前方境界を共有する用例のリストのリストを返す
# 追加された用例は、用例リストの最後であることを保証する
sub add {
    my ($self, $example) = @_;

    # カタカナの場合は効率を考えて特別扱い
    if ($example->{type} eq 'カタカナ') {
	$self->{total}++;
	return $self->{katakana}->add($example);
    }

    # 一般の未知語

    my $sharedExamplesPerFront = [];
    my @partList = sort { length ($a) <=> length ($b) } (keys(%{$example->{rearCands}}));
    my $keyR = $partList[0]; # 後方境界の一番短いの

    my $regFlag = 0; # 一度でも登録したか
    for (my $i = 0; $i < scalar(@{$example->{frontList}}); $i++) {
	my ($pos, $keyF) = @{$example->{frontList}->[$i]};
	my $key;
	# キーが空文字列ではいけない
	if ($keyF || $keyR) {
	    $key = $keyF . $keyR;
	} else {
	    if (scalar(@partList) > 1) {
		$key = $partList[1]; # 二番目に短い後方境界を使う
	    } else {
		Egnee::Logger::warn("skip null key\n");
		last;
	    }
	}
	Egnee::Logger::info("key: $key\n");
	$regFlag = 1;

	# trie に用例を追加
	# trie から大雑把に候補を集める
	my $kePairList = $self->{trie}->add($key, $example);

 	# trie のキーと front とを関連付ける
 	$example->{key2front}->{$key} = $i;
	my $exampleFrontSelector = {
	    example => $example,
	    frontIndex => $i
	};

	my $sharedExampleList = $self->getExamplesSharingFront($kePairList, $example);
	push(@$sharedExampleList, $exampleFrontSelector);
	if (scalar(@$sharedExampleList) >= $minimumExampleNum) {
	    push(@$sharedExamplesPerFront, $sharedExampleList);
	}

    }
    if ($regFlag) {
	$self->{total}++;
    } else {
	# frontString が長過ぎるとき
	# 一つも前方境界候補ができない場合がある
	Egnee::Logger::warn("example never stored\n");
    }
    return $sharedExamplesPerFront;
}

# 用例リストに selector をかぶせる
# 非カタカナピボットの場合
sub getExamplesSharingFront {
    my ($self, $kePairList) = @_;

    my $sharedExampleList = [];
    for (my $i = 0; $i < scalar(@$kePairList); $i++) {
	my ($subkey, $examples) = @{$kePairList->[$i]};
	for (my $j = 0; $j < scalar(@$examples); $j++) {
	    my $example = $examples->[$j];

	    my $k = $example->{key2front}->{$subkey};
	    # assert
	    unless (defined($k)) {
		Egnee::Logger::warn("frontIndex not found: $subkey\n");
		next;
	    }
	    my $exampleFrontSelector = {
		example => $example,
		frontIndex => $k
	    };
	    push(@$sharedExampleList, $exampleFrontSelector);
	}
    }
    return $sharedExampleList;
}

sub deleteExampleSelectorList {
    my ($self, $exampleSelectorList, $entry) = @_;

    my $rawExampleList = []; # 普通の
    my $exampleSelectorList2 = []; # カタカナ

    foreach my $exampleSelector (@$exampleSelectorList) {
	my $example = $exampleSelector->{example};
	if ($example->{type} eq 'カタカナ') {
	    push(@$exampleSelectorList2, $exampleSelector);
	} else {
	    push(@$rawExampleList, $example);
	}
    }

    my $count = scalar(@$rawExampleList);
    if ($count > 0) {
	$self->{trie}->deleteGroup($rawExampleList);
    }

    if (scalar(@$exampleSelectorList2) > 0) {
	$count += $self->{katakana}->deleteExampleSelectorList($exampleSelectorList2, $entry);
    }

    $self->{total} -= $count;
    return $count;
}

# GC 用の汚いメソッド
sub deleteExampleList {
    my ($self, $rawList, $katakanaList) = @_;

    $self->{trie}->deleteGroup($rawList);
    $self->{total} -= scalar(@$rawList);

    my $num = $self->{katakana}->deleteExampleList($katakanaList);
    $self->{total} -= $num;
}

# 格納されている用例の数
sub getTotal {
    my ($self) = @_;
    return $self->{total};
}

# 格納されているすべての用例を返す
sub getAllExamples {
    my ($self) = @_;

    my $rv = $self->{trie}->getDescendants;
    my $rv2 = $self->{katakana}->getAllExamples;
    push(@$rv, @$rv2);

    # total の勘定がバグっている問題へのやっつけ対処
    $self->{total} = scalar(@$rv);
    return $rv;
}

1;
