package CandidateEnumerator;

use strict;
use warnings;
use utf8;

use Egnee::Logger;
use Data::Dumper;

use MorphemeGrammar qw/$posList $separatorBunrui $separators $entityTagList/;

our $frontMaxLength = 8;
our $rearMaxLength = 16;
our $maxSuffixLength = 4;
our $maxStemLength = 16;  # inclusive


=head1 名前

CandidateEnumerator - 未知語の解釈の候補を列挙する

=head1 用法

  use CandidateEnumerator;
  my $enumerator = CandidateEnumerator->new($suffixList);
  $enumerator->setCallback(\&processExample);     # $example を処理するサブルーチン
  $detector->setEnumerator($enumerator);          # UnknownWordDetector に登録

=head1 説明

サフィックスのマッチングをとる。
出力は bless されていないデータ構造。

=head1 メソッド

=head2 new($suffixList)

指定されたファイルから読み込む

引数

    $suffixList: SuffixList
    $opt: オプション
      dumper => 0/1: 得られた構造体を Data::Dumper でダンプする

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	suffixList => shift,
	listener => [],
	opt => shift
    };
    # default settings
    $self->{opt}->{dumper} = 0 unless (defined($self->{opt}->{dumper}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

=head2 setCallback($code)

未定義語が検出されるごとに呼び出すサブルーチンを指定する。
現在のところ、一つしか指定できない。

引数

    $code: サブルーチン

=cut
sub setCallback {
    my ($self, $code) = @_;

    $self->{callback} = $code;
}
=head2 addListener($listener)

processExample メソッドを持つオブジェクトを指定

=cut
sub addListener {
    my ($self, $listener) = @_;

    push(@{$self->{listener}}, $listener);
}

=head2 makeExample($knpResult, $exampleCand)

検出した未知語を構造体に変換。
UnknownWordDetector から呼び出される。

=cut
sub makeExample {
    my ($self, $knpResult, $exampleCand) = @_;

    # scan morpheme sequence for front boundary enumeration
    my ($frontString, $frontList) = $self->getFrontCands($knpResult, $exampleCand);
    # scan morpheme sequence for rear boundary enumeration
    my ($rearString, $rearList) = $self->getRearCands($knpResult, $exampleCand);

    # members of $example:
    #  pivot:       検出された真ん中の形態素の見出し語
    #  frontString: pivot の前方要素を最大2文節分を文字列化したもの
    #  frontList:   前方境界の候補リスト (後ろからの文字列数)
    #  rearString:  pivot の前方要素を最大2文節分を文字列化したもの
    #  rearList:    後方境界の候補リスト (前からの文字列数)
    my $example = {
	frontString => $frontString,
	frontList => $frontList,
	rearString => $rearString,
	rearList => $rearList,
	pivot => $exampleCand->{mrph}->midasi,
    };
    if ($example->{pivot} =~ /^(\p{Katakana}|ー)+$/) {
	$example->{type} = 'カタカナ';
    } else {
	# とりあえず $feature を type にしておく
	$example->{type} = $exampleCand->{feature};
    }

    # デバッグ出力
    $self->printCands if ($self->{opt}->{debug});

    # suffix の matching で後方境界と品詞の候補を列挙
    $self->expandRearCandidates($example);

    # もう不要。ちょっとした節約
    delete($example->{rearList});

    if ($self->{opt}->{dumper}) {
	my $d = Data::Dumper->new([$example]);
	$d->Terse(1);  # 無理矢理1行にする
	$d->Indent(0);
	printf("#%s\n", $d->Dump);
    }

    if (defined($self->{callback})) {
	&{$self->{callback}}($example);
    }
    foreach my $listener (@{$self->{listener}}) {
	$listener->processExample($example);
    }

    return $example;
}

# 前方境界の候補を列挙
sub getFrontCands {
    my ($self, $knpResult, $exampleCand) = @_;

    # 走査対象を形態素列に展開
    my @bnstPos = ();
    my @mrphList = ();

    my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos})->mrph;
    for (my $i = 0; $i < $exampleCand->{mrphPos}; $i++) {
	push(@mrphList, $tmpMrphList[$i]);
    }
    $bnstPos[0] = scalar(@mrphList);
    if ($exampleCand->{bnstPos} >= 1) {
	my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos} - 1)->mrph;
	unshift(@mrphList, @tmpMrphList);
	unshift(@bnstPos, scalar(@tmpMrphList));
    }
    if ($exampleCand->{bnstPos} >= 2) {
	my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos} - 2)->mrph;
	unshift(@mrphList, @tmpMrphList);
	unshift(@bnstPos, scalar (@tmpMrphList));
    }
    my $pos = 0;
    for (my $i = 0; $i < scalar(@bnstPos); $i++) {
	my $tmp = $bnstPos[$i];
	$bnstPos[$i] = $pos;
	$pos += $tmp;
    }
    if ($exampleCand->{bnstPos} > 2) {
	unshift(@bnstPos, -1); # まだ文頭でないことを示す
    }

    # 後ろから前に境界候補を探す
    $pos = 0;
    my $frontList = [];
    my $frontString = '';
    if (scalar (@mrphList) == 0) {
	# 自分が形態素列の先頭
	$frontList->[0] = [0, '', 'BOS'];
	return ($frontString, $frontList);
    }
    if ($bnstPos[$#bnstPos] > $#mrphList) {
	# 自分の文節の $mrph よりも前に形態素がない場合
	pop(@bnstPos);
	$frontList->[0] = [0, '', 'BOB'];
    }
    for (my $i = $#mrphList; $i >= 0; $i--) {
	my $mrph = $mrphList[$i];
	my $midasi = $mrph->midasi;
	my $midasi2 = substr($midasi, 0, 1); # 記号の繰返しはまとめられる

	# 自分の後ろに境界
	if ($mrph->hinsi eq '特殊' || $separators->{$midasi2}) {
	    &addFrontBoundary($frontList, $pos, $frontString, 'BOS', 1);

	    # ここで探索を打ち切り
	    last if ($separatorBunrui->{$mrph->bunrui} || $separators->{$midasi2});
	} elsif ($mrph->midasi eq 'を') {
	    # 「〜をも」などの表現パターンがあるので注意が必要
	    &addFrontBoundary($frontList, $pos, $frontString, 'BOS', 1);
	    last; # ここで探索を打ち切り
	} elsif ($mrph->imis =~ /(\w+)末尾(外)?[\s\"]/) {
	    # 「首相」など、一部の末尾要素についても候補を列挙する
	    my $entityTag = $1;
	    if ($entityTagList->{$entityTag}) {
		# 文節境界をまたぐ場合などは上書きしない
		&addFrontBoundary($frontList, $pos, $frontString, 'END', 0);
	    } else {
		Egnee::Logger::warn("unknown entity: $entityTag\n");
	    }
	} elsif ($mrph->hinsi eq '接頭辞') {
	    # 「高タンパク」の「高」など
	    &addFrontBoundary($frontList, $pos, $frontString, 'PRE', 0);
	}

	$frontString = $midasi . $frontString;
	$pos += length($midasi);
	last if ($pos > $frontMaxLength);

	# 文節境界が手前にある
	if ($i == $bnstPos[$#bnstPos]) {
	    pop(@bnstPos);
	    &addFrontBoundary($frontList, $pos, $frontString, (scalar (@bnstPos) > 0)? 'BOB' : 'BOS', 1);
	}
    }
    return ($frontString, $frontList);
}

sub addFrontBoundary {
    my ($frontList, $pos, $frontString, $type, $doOverride) = @_;

    my $flag = 1;
    if (scalar(@$frontList) > 0) {
	if ($frontList->[$#$frontList]->[0] == $pos) {
	    # $pos で既に登録済み
	    if ($doOverride) {
		$frontList->[$#$frontList] = [$pos, $frontString, $type];
		return;
	    } else {
		$flag = 0;
	    }
	}
    }
    push(@$frontList, [$pos, $frontString, $type]) if ($flag);
}

# 後方境界の候補を列挙
sub getRearCands {
    my ($self, $knpResult, $exampleCand) = @_;

    my @bnstList = $knpResult->bnst;
    
    # 走査対象を形態素列に展開
    my @bnstPos = ();
    my @mrphList = ();
    my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos})->mrph;
    $bnstPos[0] = scalar(@tmpMrphList) - ($exampleCand->{mrphPos} + 1);
    for (my $i = $exampleCand->{mrphPos} + 1; $i < scalar(@tmpMrphList); $i++) {
	push(@mrphList, $tmpMrphList[$i]);
    }
    if ($exampleCand->{bnstPos} + 1 < scalar(@bnstList)) {
	my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos} + 1)->mrph;
	push(@mrphList, @tmpMrphList);
	push(@bnstPos, scalar(@tmpMrphList));
    }
    if ($exampleCand->{bnstPos} + 2 < scalar(@bnstList)) {
	my @tmpMrphList = $knpResult->bnst($exampleCand->{bnstPos} + 2)->mrph;
	push(@mrphList, @tmpMrphList);
	push(@bnstPos, scalar(@tmpMrphList));
    }
    my $pos = 0;
    for (my $i = 0; $i < scalar(@bnstPos); $i++) {
	$pos = $bnstPos[$i] = $pos + $bnstPos[$i];
    }

    # 前から後ろへと境界候補を探す
    $pos = 0;
    my $rearList = [];
    my $rearString = '';
    if (scalar(@mrphList) == 0) {
	# 自分が形態素列の最後
	$rearList->[0] = [0, 'EOS'];
	return ($rearString, $rearList);
    }
    if ($bnstPos[0] == 0) {
	# 自身が文節末
	$rearList->[0] = [0, 'EOB'];
	shift(@bnstPos);
    }
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	my $midasi = $mrph->midasi;
	my $midasi2 = substr($midasi, 0, 1); # 記号の繰返しはまとめられる

	# 自分の手前に境界
	#   一つ前の形態素が、自分の後ろに境界を設定した場合は重複するので注意が必要
	if ($mrph->hinsi eq '特殊' || $separators->{$midasi2}) {
	    &addRearBoundary($rearList, $pos, 'EOS', 1);

	    # ここで探索を打ち切り
	    last if ($separatorBunrui->{$mrph->bunrui} || $separators->{$midasi2});
	} elsif ($mrph->imis =~ /(\w+)末尾(外)?[\s\"]/) {
	    # 「首相」など、一部の末尾要素についても候補を列挙する
	    my $entityTag = $1;
	    if ($entityTagList->{$entityTag}) {
		# 文節境界をまたぐ場合などは上書きしない
		&addRearBoundary($rearList, $pos, $entityTag, 0);
	    } else {
		Egnee::Logger::warn("unknown entity: $entityTag\n");
	    }
	} elsif (!($mrph->fstring =~ /\<品詞変更\:/) && length($mrph->midasi) >= 2
		 && (($mrph->hinsi eq '動詞' && !($mrph->fstring =~ /\<付属動詞候補/))
		     && ($mrph->katuyou2 ne '基本連用形'   # 連用名詞化に失敗している可能性がある
			 || (defined($mrphList[$i+1])
			     && (($mrphList[$i+1])->imis =~ /付属動詞候補（基本）/           # 遊び始める
				 || ($mrphList[$i+1])->bunrui =~ /(?:動詞性|述語)接尾辞$/))) # 遊びます, 遊びそうだ
		     || ($mrph->hinsi eq '形容詞' && $mrph->katuyou2 ne '語幹')
		     || ($mrph->bunrui eq 'サ変名詞' && $mrph->fstring =~ /\<サ変動詞\>/))) {
	    # for adverbs
	    &addRearBoundary($rearList, $pos, '用言:' . $mrph->genkei, 1); # override EOB
	} elsif ($mrph->hinsi eq '接頭辞') {
	    # 「高タンパク低脂肪の」の「低」など
	    &addRearBoundary($rearList, $pos, 'EOB', 0);
	}

	$rearString .= $midasi;
	$pos += length($midasi);
	last if ($pos > $rearMaxLength);

	# 自分の後ろに境界
	# suffix のマッチングにつかうので、「を」は残しておくが、
	# 後方の探索はここで打ち切る
	if ($mrph->midasi eq 'を') {
	    # type をは境界を表すために一時的に追加
	    &addRearBoundary($rearList, $pos, 'を', 1);
	    last;
	}

	# 文節境界が後ろにある
	if ($i + 1 == $bnstPos[0]) {
	    shift (@bnstPos);
	    &addRearBoundary($rearList, $pos, 'EOB', 1);
	}
    }
    return ($rearString, $rearList);
}

sub addRearBoundary {
    my ($rearList, $pos, $type, $doOverride) = @_;

    my $flag = 1;
    if (scalar(@$rearList) > 0) {
	# 登録済みの場合
	if ($rearList->[$#$rearList]->[0] == $pos) {
	    if ($doOverride) {
		$rearList->[$#$rearList] = [$pos, $type];
		return;
	    } else {
		$flag = 0;
	    }
	}
    }
    push(@$rearList, [$pos, $type]) if ($flag);
}

# suffix の matching により後方境界を展開する
sub expandRearCandidates {
    my ($self, $example) = @_;

    # pivot も含めて探索を行なう
    my $string = $example->{pivot} . $example->{rearString};
    my $rv = $self->suffixMatch($string, $example);

    my $offset = length($example->{pivot});

    my $jS = 0;
    for (my $i = 0; $i < scalar(@{$example->{rearList}}); $i++) {
	my ($rpos, $type) = @{$example->{rearList}->[$i]};
	my $pos1 = $offset + $rpos;

	# 「を」の後ろを後方境界とするのは、suffix matching の都合
	# 最終的な候補からは外す
	next if ($type eq 'を');

	if ($type eq 'EOB' || $type eq 'EOS') {
	    # suffix がマッチしなかった境界候補に EOB を付与
	    my $flag = 0;
	    for (my $j = $jS; $j < scalar(@$rv); $j++) {
		my $pos2 = $rv->[$j]->[0];
		if ($pos1 == $pos2) {
		    $flag = 1;
		    last;
		} elsif ($pos1 > $pos2) {
		    $jS++;
		} else {
		    last;
		}
	    }
	    if (!$flag) {
		my $part = substr($string, 0, $pos1);
		$example->{rearCands}->{$part} = $type;
	    }
	} elsif ($type =~ /^用言\:/) {
	    # TODO: 用言の処理
	    my $part = substr($string, 0, $pos1);
	    $example->{rearCands}->{$part}->{'普通名詞'} = [$type, ''];
	} else {
	    # 「末尾」の形態素の場合は、名詞に展開
	    # 一応、マッチしたサフィックスで上書きされる可能性あり
	    my $part = substr($string, 0, $pos1);
	    $example->{rearCands}->{$part}->{'普通名詞'} = [$type, ''];
	}
    }
    # 普通の品詞の展開
    foreach my $tmp (@$rv) {
	my ($pos, $id) = @$tmp;

 	my $part = substr($string, 0, $pos);
	my $suffix = $self->{suffixList}->getSuffixByID($id);
	my $suffixContent = $self->{suffixList}->getSuffixContentByID($id);
	foreach my $tmp2 (@$suffixContent) {
	    my ($posS, $katuyou2) = @$tmp2;

 	    # 品詞の追加制約のチェックは StemFinder でやる。
	    # 語幹が確定しないと処理しにくいから。
	    $example->{rearCands}->{$part}->{$posS} = [$katuyou2, $suffix];
	}
    }
    return $example;
}


# 個々の未定義語を含む文字列に対して探索を行なう
# マッチしたすべての結果を返す
sub suffixMatch {
    my ($self, $string, $example) = @_;

    # $string は pivot と rearString の concat
    my $offset = length($example->{pivot});
    my $rearList = $example->{rearList};
    my $limitLength = length($string);

    my $iS = 0;
    if ($example->{type} eq 'カタカナ') {
	$iS = $offset;
    }

    my $suffixList = $self->{suffixList};

    my $cands = [];
    for (my $i = $iS; $i < $limitLength; $i++) {
	my $substr = substr($string, $i);

	# 未知語の最低の語幹の長さが語幹の最大長を越えると駄目
	if ($i > $maxStemLength) {
	    last;
	}

 	# substr と開始位置が一致する
 	# suffix のリスト (tx の内部 ID のリスト) を得る
	my $idList = $suffixList->commonPrefixSearchID($substr);
	next if (scalar(@$idList) <= 0);

	my $selectedID;
	# 最長一致したものから suffix がマッチの条件を満たすかチェック
      outer:
	for (my $j = scalar(@$idList) - 1; $j >= 0; $j--) {
	    my $id = $idList->[$j];
	    my $suffixLength = $suffixList->getSuffixLengthByID($id);

	    # suffix が十分長ければ OK
	    if ($suffixLength >= $maxSuffixLength) {
		$selectedID = $id;
		last;
	    } else {
		# suffix の終了位置が文節終りと一致すれば OK
		foreach my $tmp (@$rearList) {
		    my ($pos) = @$tmp;
		    if (($offset + $pos) == ($i + $suffixLength)) {
			$selectedID = $id;
			last outer;
		    }
		}
	    }
	}
	if (defined($selectedID)) {
	    push(@$cands, [$i, $selectedID]);
	}
    }
    return $cands;
}

### for debug
sub printCands {
    my ($self, $example) = @_;

    my $frontList = $example->{frontList};
    my $frontString = $example->{frontString};
    my $rearList = $example->{rearList};
    my $rearString = $example->{rearString};

    my $buf = '';
    foreach my $tmp (@$frontList) {
	my ($p) = @$tmp;
	$buf .= 'frontCand: ' . substr($frontString, length($frontString) - $p, $p) . "\n";
    }
    foreach my $tmp (@$rearList) {
	my ($p) = @$tmp;
	$buf .= 'rearCand: ' .  substr($rearString, 0, $p) . "\n";
    }
    Egnee::Logger::info($buf);
}

1;
