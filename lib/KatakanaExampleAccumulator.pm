package KatakanaExampleAccumulator;
use strict;
use warnings;
no warnings 'redefine'; # やりたくて再定義しているのだ!
use utf8;

use base qw (ExampleAccumulator);

use Scalar::Util qw (refaddr);
use StemFinder qw/$minimumExampleNum/;

=head1 名前

KatakanaExampleAccumulator - ピボットがカタカナの用例を効率的に管理する

=head1 用法

    ExampleAccumulator の中から使う

=head1 説明

ピボットがカタカナの用例を効率的に管理する

=head1 メソッド

=head2 new

初期化。

=cut
sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	dictionaryManager => shift,
	opt => shift,
	pivotList => {},
    };

    bless ($self, $class);
    return $self;
}

=head2 add ($example)

用例を追加して、前方境界を共有する用例のリストのリストを返す
返すリストには自身は含まれていないので注意が必要。

=cut
sub add {
    my ($self, $example) = @_;

    my $pivot = $example->{pivot};

    my $sharedExamplesPerFront = [];

    # データを登録
    for (my $i = 0; $i < scalar (@{$example->{frontList}}); $i++) {
	my ($pos, $front) = @{$example->{frontList}->[$i]};

	# 選択した前方境界候補の添字を覚えておく
	my $exampleFrontSelector = {
	    example => $example,
	    frontIndex => $i
	};
	push (@{$self->{pivotList}->{$pivot}->{$front}}, $exampleFrontSelector);

	# 最低限の用例数に満たなければ後の処理をスキップする
	if (scalar @{$self->{pivotList}->{$pivot}->{$front}} >= $minimumExampleNum) {
	    my $list = $self->{pivotList}->{$pivot}->{$front};
	    my $tmp = [];
	    foreach my $val (@$list) { push (@$tmp, $val); }
	    push (@$sharedExamplesPerFront, $tmp);
	}
    }
    return $sharedExamplesPerFront;
}

# 用例リストを消して、消した用例数を返す
# もっと効率化できそうだが、そんなに頻繁に呼び出されないから放置
sub deleteExampleSelectorList {
    my ($self, $exampleSelectorList, $entry) = @_;

    # 無条件で消す用例リスト
    # selector をはいで hash に登録
    my $exampleDBPerPivotFront = {};
    foreach my $exampleSelector (@$exampleSelectorList) {
	my $example = $exampleSelector->{example};
	my $pivot = $example->{pivot};
	my ($pos, $front) = @{$example->{frontList}->[$exampleSelector->{frontIndex}]};
	my $id = refaddr ($example);
	$exampleDBPerPivotFront->{$pivot}->{$front}->{$id} = $example;
    }

    # チェックするピボットの追加
    # 用例リストのピボットを部分文字列として含むピボットも対象に
    foreach my $pivot2 (keys (%{$self->{pivotList}})) {
	next if (defined ($exampleDBPerPivotFront->{$pivot2}));
	my $pivot;
	while (($pivot = each (%$exampleDBPerPivotFront))) {
	    if (index ($pivot2, $pivot) >= 0) {
		$exampleDBPerPivotFront->{$pivot2} = {};
		last;
	    }
	}
    }

    my $count = scalar (@$exampleSelectorList); # 削除した用例数

    # ピボットごとに実際の用例をチェック
    while ((my $pivot = each (%$exampleDBPerPivotFront))) {
	my $exampleDBPerFront = $exampleDBPerPivotFront->{$pivot};
	my $list = $self->{pivotList}->{$pivot};

	# front の候補ごとにチェックするので、重複して調べる場合があるので
	# isDecomposable の結果を cache に保存
	my $cached = {};
	foreach my $front (keys (%$list)) {
	    my $exampleDB = $exampleDBPerFront->{$front};
	    my $remainder = [];  # isDecomposable のチェックをする remainder
	    my $remainder2 = []; # isDecomposable をしない remainder

	    # 消すべき用例リストを除いて remainder を作る
	    foreach my $exampleFrontSelector (@{$list->{$front}}) {
		my $example = $exampleFrontSelector->{example};
		my $id = refaddr ($example);

		# 削除対象なら remainder に追加しない
		unless (defined ($exampleDB->{$id})) {
		    # isDecomposable の実行結果がキャッシュされている
		    if (defined ($cached->{$id})) {
			# 既にチェックした用例なので count を increment しない
			unless ($cached->{$id}) {
			    push (@$remainder2, $exampleFrontSelector);
			}
		    } else {
			push (@$remainder, [$example, $id, $exampleFrontSelector]);
		    }
		}
	    }

	    # リストにない用例は、実際に解析して消すべきか決める
	    foreach my $tmp (@$remainder) {
		my ($example, $id, $exampleFrontSelector) = @$tmp;

		# チェック対象の文字列
		# 元の文と違い、語幹候補の探索範囲に絞りこまれている
		my $string = $example->{frontString} . $example->{pivot} . $example->{rearString};
		my $status = $self->{dictionaryManager}->isDecomposable ($entry, $string);
		$cached->{$id} = $status;
		if ($status) {
		    $count++; # 削除対象
		} else {
		    push (@$remainder2, $exampleFrontSelector);
		}
	    }
	    if (scalar (@$remainder2) > 0) {
		$list->{$front} = $remainder2;
	    } else {
		delete ($self->{pivotList}->{$pivot}->{$front});
	    }
	}

	# $pivot の用例がなくなれば消す
	if (scalar (keys (%{$self->{pivotList}->{$pivot}})) <= 0) {
	    delete ($self->{pivotList}->{$pivot});
	}
    }
    return $count;
}

# GC 用
sub deleteExampleList {
    my ($self, $examplePerPivotList) = @_;

    my $num = 0; # 実際に削除した数をかぞえる (debug)
    while ((my $pivot = each (%$examplePerPivotList))) {
	my $idHash = {};
	foreach my $example (@{$examplePerPivotList->{$pivot}}) {
	    my $id = refaddr ($example);
	    $idHash->{$id} = 1;
	    $num++;
	}

	my $list = $self->{pivotList}->{$pivot};
	foreach my $front (keys (%$list)) {
	    my $remainder = [];
	    foreach my $exampleFrontSelector (@{$list->{$front}}) {
		my $example = $exampleFrontSelector->{example};
		my $id = refaddr ($example);
		push (@$remainder, $exampleFrontSelector)
		    unless ($idHash->{$id});
	    }
	    if (scalar (@$remainder) > 0) {
		$list->{$front} = $remainder;
	    } else {
		delete ($list->{$front});
	    }
	}
    }
    return $num;
}

sub getAllExamples {
    my ($self) = @_;

    my $rv = [];
    while ((my $pivot = each (%{$self->{pivotList}}))) {
	my $list = $self->{pivotList}->{$pivot};
	my $idHash = {};

	foreach my $front (keys (%$list)) {
	    foreach my $exampleFrontSelector (@{$list->{$front}}) {
		my $example = $exampleFrontSelector->{example};
		my $id = refaddr ($example);
		next if ($idHash->{$id}++ > 0);
		push (@$rv, $example);
	    }
	}
    }
    return $rv;
}

1;
