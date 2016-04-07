package CaseFrameExtractor;
#
# re-implementation of Kawahara-san's Examples.pm
# TODO: rename CaseFrameExtractor to PredicateArgumentsExtractor
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;
use Encode;

our $euc = Encode::find_encoding('euc-jp');

# 複合辞
# 複合辞は原形の読みに統一する
our $fukugojiList = {
    'を除く' => 'をのぞく', 
    'を通じる' => 'をつうじる', 
    'を通ずる' => 'をつうじる', 
    'を通す' => "をつうじる", 
    'を含める' => 'をふくめる', 
    'を始める' => 'をはじめる', 
    'に絡む' => 'にからむ', 
    'に沿う' => 'にそう', 
    'に向ける' => 'にむける', 
    'に伴う' => 'にともなう', 
    'に基づく' => 'にもとづく', 
    'に対する' => 'にたいする', 
    'に関する' => 'にかんする', 
    'に代わる' => 'にかわる', 
    'に加える' => 'にくわえる', 
    'に限る' => 'にかぎる', 
    'に続く' => 'につづく', 
    'に合わせる' => 'にあわせる', 
    'に比べる' => 'にくらべる', 
    'に並ぶ' => 'にならぶ', 
    'に限るぬ' => 'にかぎるぬ',
};

# 連用形の活用
our $renyouKatuyouList = {
    '基本連用形' => 1, 
    '文語連用形' => 1, 
    'タ形連用テ形' => 1, 
    'タ形連用タリ形' => 1, 
    'タ形連用チャ形' => 1, 
    'タ形連用チャ形２' => 1, 
    'ダ列基本連用形' => 1, 
    'ダ列タ形連用テ形' => 1, 
    'ダ列タ形連用タリ形' => 1, 
    'ダ列タ系連用ジャ形' => 1, 
    'デアル列基本連用形' => 1, 
    'デアル列タ形連用テ形' => 1, 
    'デアル列タ系連用タリ形' => 1, 
    'デス列タ系連用テ形' => 1, 
    'デス列タ系連用タリ形' => 1,
};

# <時間>の単語
our $timeNoun = { 'とき' => 1, '際' => 1, '半ば' => 1, 'その間' => 1, '前半' => 1, '後半' => 1 };

# <数量>ではない単語
our $noNumeral = { '何' => 1 };

# 削除する単語
our $stopwordList = { 'もの' => 1, 'こと' => 1, 'うち' => 1, 'ほう' => 1 };


sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift
    };

    # default settings
    $self->{opt}->{probcase} = 0 unless (defined($self->{opt}->{probcase}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}


# SentenceBasedAnalysisObserverRegistry に登録しているので、document が渡される
# sub onDocumentChange {
#     my ($self, $document) = @_;
# }

# SentenceBasedAnalysisObserverRegistry に登録しているので、sentence が渡される
sub onSentenceAvailable {
    my ($self, $sentence) = @_;

    # callback を用意していないので、
    # option dump を設定していないと onSentenceAvailable を呼んでも意味がない

    # 抽出結果が欲しい場合は prepare, extract, clean を順に呼ぶ

    my $knpResult = $sentence->get('knp');
    $self->prepare($knpResult);
    $self->extract($knpResult);
    $self->clean($knpResult);
}

# 下準備
# extract の実行前に必要
sub prepare {
    my ($self, $knpResult) = @_;

    # HACK
    # WARNING: KNP::Bunsetsu の中身を書き換える
    my $bnstP = undef;
    foreach my $bnst ($knpResult->bnst) {
	if (defined ($bnstP)) {
	    $bnst->{_prev} = $bnstP;
	    $bnstP->{_next} = $bnst;
	}
	$bnst->{_jiritsu} = &getJiritsuMrphList($bnst);
	$bnstP = $bnst;

	if ($self->{opt}->{probcase}) {
	    foreach my $tag ($bnst->tag) {
		$tag->{_bnst} = $bnst;
	    }
	}
    }
}

# 掃除
sub clean {
    my ($self, $knpResult) = @_;
    foreach my $bnst ($knpResult->bnst) {
	delete($bnst->{_prev});
	delete($bnst->{_next});
	delete($bnst->{_jiritsu});
	if ($self->{opt}->{probcase}) {
	    foreach my $tag ($bnst->tag) {
		delete($tag->{_bnst});
	    }
	}
    }
}

sub extract {
    my ($self, $knpResult) = @_;

    my $paList = [];
    if ($self->{opt}->{probcase}) {
	foreach my $bnst (reverse($knpResult->bnst)) {
	    $self->extractProbcase($knpResult, $bnst->id, $paList);
	}
    } else {
	foreach my $bnst (reverse($knpResult->bnst)) {
	    last unless ($self->isValidSentence($knpResult, $bnst->id));
	    my $paList2 = $self->extractFromBunsetsu($knpResult, $bnst->id);
	    push(@$paList, @$paList2) if (defined($paList2));
	}
    }
    return $paList;
}

# 文末または括弧終にある用言をチェック
sub isValidSentence {
    my ($self, $knpResult, $i) = @_;

    my $bnst = $knpResult->bnst($i);
    my $fstring = $bnst->fstring;
    # 文末または括弧終にある用言をチェック
    if ($fstring =~ /\<文末\>/ || $fstring =~ /\<括弧終\>/) {
	if ($self->{opt}->{discardAmbiguity}) {
	    # 格・副助詞、読点で終わっているときは収集しない
	    return 0 if (&isJoshiToutenEnding($bnst));
	    # 文末, 括弧終で連用形のときは収集しない
	    return 0 if (&isRenyouEnding($bnst));
	    # 文末, 括弧終で命令形のときは収集しない
	    return 0 if (&isMeireiEnding($bnst));
	}
    }
    return 1;
}

# 特殊な操作をほどこした KNP::Result に対して作用するので、
# あらかじめ prepare を呼ぶ必要がある。
# また、終了後は clean を呼んで掃除する。
sub extractFromBunsetsu {
    my ($self, $knpResult, $i) = @_;
    my $bnst = $knpResult->bnst($i);
    my $fstring = $bnst->fstring;

    my $EOSV = 0; # 文末の用言
    if ($fstring =~ /\<文末\>/ || $fstring =~ /\<括弧終\>/) {
	$EOSV = 1;
	if ($self->{opt}->{discardAmbiguity}) {
	    # 文末のサ変名詞、判定詞なしの体言止めは収集しない
	    if ($fstring =~ /\<体言止\>/ && $fstring =~ /\<(?:サ変|用言:判)\>/) {
		# 判定詞なしの体言止めの例: 小さな椅子に机。
		return;
	    }
	}
    }

    # 自立語が必要
    my $jiritsuMrphList = $bnst->{_jiritsu};
    return unless (scalar(@$jiritsuMrphList) > 0);

    # 曖昧な用言
    if ($self->{opt}->{discardAmbiguity}) {
	return if ($fstring =~ /\<レベル:A-\>/);
	return if ($fstring =~ /<ID:(?:〜と（引用）|〜と（いう）)>/); # 「医者からも完治したと太鼓判を押された」のレベル:Cの壁(2.5%減)
	return if ($fstring =~ /\<用言:弱\>/);
	return if ($fstring =~ /\<デ\>/); # 「で」は判定詞か動詞かわからない
	return if ($fstring =~ /\<ID:（サ変）読点\>/);
	return if ($fstring =~ /\<サ変動詞化\>/); # 「工場を見学に行く」の「見学」など
	return if ($fstring =~ /\<述語化\>/); # 「方法をご存知の」の「存知」など

	if (!$self->{opt}->{useRepname}) {
	    # 「あった」など
	    return if (scalar(@$jiritsuMrphList) > 0 && $jiritsuMrphList->[-1]->fstring =~ /\<原形曖昧\>/);
	}

	# 「干し椎茸」の「干し」の部分を用言として収集しない
	if (!($bnst->fstring =~ /\<読点\>/)
	    && &isLastMrphRenyou($bnst)) { # 基本連用形
	    my $bnstN = $bnst->{_next};
	    return if (defined($bnstN) && $bnstN->fstring =~ /\<体言\>/);
	}

	# アンケートなどの1文節の括弧の用言を収集しない
	return if ($fstring =~ /\<括弧始\>/ && $fstring =~ /\<括弧終\>/);
    }

    # 直前格要素 (もっとも近い格要素)
    my $adjacence = &getClosestCC($bnst);

    # 用言のタイプ
    my $vtype = &getPredType($bnst);
    return unless (defined($vtype));

    # 用言表記
    my $V;
    if ($self->{opt}->{useRepname}) {
	$V = &getPredRepresentationForRepname($bnst, $vtype, $jiritsuMrphList->[-1]);
    } else {
	$V = &getPredRepresentation($bnst, $vtype, $jiritsuMrphList->[-1]);
    }
    return unless (defined($V));

    # my $KEYS = [ $V ];

    # 用言が並列で係る場合は信用できない? -> 保留
    # 6.4%減少
    # if ($corpus->{Bunsetsu}[$i]{DpndType} eq 'P') {
    # 	return;
    # }

    my $caseList = []; # 格要素の文字列のリスト
    my $phrases = [];
    my $gaga = {};

    # 親をみる (連体修飾先)
    if ($fstring =~ /\<係:連格\>/ && $bnst->dpndtype ne 'P' && # 並列ではない
	$bnst->parent->fstring =~ /\<体言\>/) { # 係り先は体言

	my $isAmbiguous = 1;
	# 係先の曖昧性 KNP の -check オプション
	if ($fstring =~ /\<候補:([^\>]+)\>/ && (my @cands = split(/\:/, $1))) {
	    $isAmbiguous = 0 if (scalar(@cands) == 1);
	}
	if (!$isAmbiguous || !$self->{opt}->{discardAmbiguity}) {
	    my $component = $self->getCaseComponent($bnst, $bnst->parent, '連体', $adjacence);
	    if (defined($component)) {
		push(@$caseList, { string => $component, bnst => $bnst->parent });
	    }
	}
    }

    # 子供をみる (格要素)
    foreach my $child ($bnst->child) {
	if ($self->{opt}->{discardAmbiguity}) {
	    # 〜を〜に疑: 用言ごと収集しないために、とりあえずここにある
	    return if ($child->fstring =~ /\<〜を〜に疑\>/);
	    # 文末以外の用言が子用言と並列のときは、格要素の係り先候補数が信用できない
	    # 7.6%減少
	    return if ($child->dpndtype eq 'P' && !$EOSV);

	    # 格助詞と判定された「〜で、」の係る用言は収集しない
	    # 1.6%減少
	    return if ($child->fstring =~ /\<係:デ格\>/
		       && $child->fstring !~ /\<ハ\>/
		       && $child->fstring =~ /\<読点\>/);
	}

	# 格要素を作成
	my ($component, $isFukugoji) = $self->getCaseComponents($bnst, $child, $adjacence, $EOSV);

	# 強調構文は除外(<補文>が判定詞に係る場合)
	return if (defined($component) && $component =~ /^<補文>:(?:未|ガ)格/ && $vtype eq '判');

	if ($component) {
	    my $bnst = ($isFukugoji)? $child->{_prev} : $child;
	    push(@$caseList, { string => $component, bnst => $bnst });
	    push(@$phrases, join ('', map { $_->midasi } ($child->mrph)));
	    $gaga = &getGAGA($child) if ($self->{opt}->{gaga});
	} elsif ($self->{opt}->{strict}) {
	    # 「どれかひとつ格要素を作れないときは用言ごと収集しない」になる (6割減)
	    return;
	} elsif (&isAdjacent($child, $adjacence)) {
	    # 直前格要素なのに格要素を作れないとき
	    return;
	}
    }

    # 同じ格が複数ある場合は捨てる (同じ格の一番最後の格要素だけをとってもいいかも)
    # 0.5%減少
    if ($self->{opt}->{discardAmbiguity}) {
	return if (&isCaseDuplicated($caseList));
    }

    # AのBをV: Aを「ノ格」として記録 (判定詞の場合は判定詞に係るもの)
    my $elem = $self->getNoCase($bnst, $caseList, $phrases, $vtype, $adjacence);

    # ガ格|ヲ格 <数量>:無格* ならば入れ替え
    &swapMukaku($caseList);

    my $paList = [];
    if (scalar (@$caseList) > 0) {
	foreach my $struct (@$caseList) {
	    $struct->{bnst}->push_feature('採用文節'); # no parentheses
	}

	# ノ格は $caseBnstList に入っていない
	my $paStruct = {
	    verb => $V,
	    verbBunsetsu => $bnst,
	    phrases => $phrases,
	    caseList => $caseList,
	};
	push(@$paList, $paStruct);

	if ($self->{opt}->{dump}) {
	    printf("%s %s %s\n", $knpResult->id, $V, join(' ', (map { $_->{string} } @$caseList)));
 	}
    }
    return $paList;
}

# 直前格要素 (もっとも近い格要素)
sub getClosestCC {
    my ($bnst) = @_;

    my @children = $bnst->child;
    return undef unless (scalar(@children) > 0);

    foreach my $child (reverse(@children)) {
	my $type = &getCaseType($child);
	return $child if (defined($type));
    }
    return undef;
}

sub getCaseType {
    my ($bnst) = @_;

    $bnst->fstring =~ /\<係:([^\>]+)\>/;
    my $case = $1 || '';

    return undef if ($case =~ /無格従属|同格/);
    return $case if ($case =~ /格/ && $case !~ /(?:未|ノ|連)格/);
    return $case if ($case =~ /未格/ && $bnst->fstring =~ /\<(ハ|モ)\>/);
    return undef;
}

# 用言の種類の判別
sub getPredType {
    my ($bnst) = @_;

    my $fstring = $bnst->fstring;
    return '動' if ($fstring =~ /\<用言:[^\>]*動\>/);
    return '判' if ($fstring =~ /\<用言:[^\>]*判\>/);
    return '形' if ($fstring =~ /\<用言:[^\>]*形\>/);
    return '準' if ($fstring =~ /\<準用言\>/);
    return undef;
}

# 用言表記を作り出す
sub getPredRepresentation {
    my ($bnst, $vtype, $lastJiritsuMrph) = @_;

    my $ret = $lastJiritsuMrph->genkei; # default value

    my @mrphList = $bnst->mrph;
    while (scalar(@mrphList) > 0) {
	my $mrph = shift(@mrphList);
	last if ($mrph == $lastJiritsuMrph);
    }
    my $mrph = $mrphList[0];
    if (defined($mrph)) {
	# 最後自立語の次の付属語をチェック
	if (($mrph->hinsi eq '接尾辞'
	     && $mrph->genkei =~ /^(?:する|なる|ある|化|的だ|る|い)$/) # これらは接尾辞
	    || ($lastJiritsuMrph->hinsi eq '形容詞' # 「長さ:判」など
		&& $lastJiritsuMrph->katuyou2 eq '語幹' && $mrph->genkei eq 'さ')) {
	    # 活用形 + 付属語原形
	    $ret = $lastJiritsuMrph->midasi . $mrph->genkei;
# 	} elsif ($mrph->fstring =~ /<(?:(?:準)?内容語|意味有)>/) {
# 	    # 「県」などはそれだけで
# 	    $ret = $mrph->genkei;
	}
    }

    # 用言タイプを付加
    $ret .= ':' . $vtype;

    # 最後自立語以降の付属語をチェックし、voice情報を付加
    my $f = &getPredSuffix(\@mrphList);
    $ret .= ':' . join('', @$f) if (scalar(@$f) > 0);

    return $ret;
}

# 用言表記を作り出す(代表表記)
sub getPredRepresentationForRepname {
    my ($bnst, $vtype, $lastJiritsuMrph) = @_;

    # set default value
    my $ret = &getRepname($lastJiritsuMrph);

    # process ALT
    my $altret = {};
    $altret->{$ret} = 1;
    foreach my $doukei ($lastJiritsuMrph->doukei) {
	my $repname = &getRepname($doukei);
	$altret->{$repname}++;
    }
    # WARNING: EUC-JP の場合と順序が違う
    $ret = join('?', &esort(keys(%$altret))); # uniq

    my @mrphList = $bnst->mrph;
    while (scalar(@mrphList) > 0) {
	my $mrph = shift(@mrphList);
	last if ($mrph == $lastJiritsuMrph);
    }
    my $mrph = $mrphList[0];
    if (defined ($mrph)) {
	# 最後自立語の次の付属語をチェック
	if (($mrph->hinsi eq '接尾辞'
	     && $mrph->genkei =~ /^(?:する|なる|ある|化|的だ|る|い)$/) # これらは接尾辞
	    || ($lastJiritsuMrph->hinsi eq '形容詞' # 「長さ:判」など
		&& $lastJiritsuMrph->katuyou2 eq '語幹' && $mrph->genkei eq 'さ')) {
	    # 明らかにする -> 明らかだ/あきらかだ+する/する など

	    # 付属語の代表表記
	    my $tmpret = &getRepname($mrph);

	    # 自立語の代表表記
	    my @altret = split(/\?/, $ret);
	    foreach $ret (@altret) {
		$ret .= "+" . $tmpret;
	    }
	    # WARNING: EUC-JP の場合と順序が違う
	    $ret = join ("?", &esort(@altret));
# 	} elsif ($mrph->fstring =~ /<(?:(?:準)?内容語|意味有)>/) {
# 	    # 「県」などはそれだけで
# 	    $ret = &getRepname ($mrph);
	}
    }

    # 用言タイプを付加
    $ret .= ':' . $vtype;

    # 最後自立語以降の付属語をチェックし、voice情報を付加
    my $f = &getPredSuffix(\@mrphList);
    $ret .= ':' . join('', @$f) if (scalar(@$f) > 0);

    return $ret;
}

# 最後自立語以降の付属語を作成
sub getPredSuffix {
    my ($mrphList) = @_;

    my $f = [];
    # 最後自立語以降の付属語をチェック
    while (scalar (@$mrphList) > 0) {
	my $mrph = shift (@$mrphList);
	my $genkei = $mrph->genkei;

	if ($genkei =~ /^(?:ら)?れる$/) {
	    push(@$f, 'P'); # れる, られる
	} elsif ($genkei =~ /^(?:す|さす|せる|させる)$/) {
	    push(@$f, 'C'); # す, さす, せる, させる
	} elsif ($genkei =~ /^(?:出来る|できる|得る|うる)$/) {
	    push(@$f, 'A'); # 出来る, できる, 得る, うる
	} elsif ($genkei =~ /^(?:もらう|いただく)$/) {
	    push(@$f, 'M'); # もらう, いただく
	} elsif ($genkei =~ /^(?:もらえる|いただける)$/) {
	    push(@$f, 'L'); # もらえる, いただける
	} elsif ($genkei =~ /^(?:くれ|下さ|くださ)る$/) {
	    push(@$f, 'K'); # くれる, 下さる, くださる
	} elsif ($genkei =~ /^たい$/) {
	    push(@$f, 'T'); # たい
	} elsif ($genkei =~ /^(?:ほ|欲)しい$/) {
	    push(@$f, 'H'); # 欲しい, ほしい
	} elsif ($genkei =~ /^(?:にく|やす|がた|づら)い$/) {
	    push(@$f, 'N'); # にくい, やすい, がたい
	} elsif ($genkei =~ /^(?:や|あげ)る$/) {
	    push(@$f, 'Y'); # やる, あげる
	} elsif ($genkei =~ /^(?:あ|上)がる$/) {
	    push(@$f, 'G'); # 上がる, あがる
	}
    }
    return $f;
}

# 1つの格要素を構成する (チェックなし)
sub getCaseComponent {
    my ($self, $bnst, $caseBnst, $TYPE, $adjacence) = @_;

    # FIX
    # sometimes $bnst has no jiritsu mrph
    return undef unless (scalar(@{$caseBnst->{_jiritsu}} > 0));

    # 直前格要素フラグ
    my $adjacencyFlag = (&isAdjacent($caseBnst, $adjacence))? '*' : '';
    # 複合名詞フラグ
    my $compoundNounFlag = (&isCompoundNoun($caseBnst))? '%' : '';

    my $content = $self->getCaseComponentsContent($bnst, $caseBnst, undef, $adjacencyFlag);
    return undef unless (defined($content));
    return sprintf("%s:%s%s%s", $content, $TYPE, $compoundNounFlag, $adjacencyFlag);
}

# 1つの格要素を構成する (チェックあり)
sub getCaseComponents {
    my ($self, $bnst, $child, $adjacence, $EOSV) = @_;

    # FIX
    # sometimes $bnst has no jiritsu mrph
    return undef unless (scalar(@{$child->{_jiritsu}} > 0));

    # 直前格要素フラグ
    my $adjacencyFlag = (&isAdjacent($child, $adjacence))? '*' : '';
    # 複合名詞フラグ
    my $compoundNounFlag = (&isCompoundNoun($child))? '%' : '';

    if ($self->{opt}->{discardAmbiguity}) {
	my $isAmbiguous = 1;
	# 係先の曖昧性 KNP の -check オプション
	if ($child->fstring =~ /\<候補:([^\>]+)\>/ && (my @cands = split(/\:/, $1))) {
	    $isAmbiguous = 0 if (scalar(@cands) == 1);
	}
	return undef if ($isAmbiguous); # 候補がひとつ

	###################################################
	# TODO: この三つはまとめられるはず
	###################################################

	# 格要素と用言の間に用言 (A-) が存在するかどうか
	return undef if (&hasIntermediateVerb($child, $bnst));

	# 格要素と用言の間に未知語が存在するかどうか
	return undef if (&hasIntermediateUNK($child, $bnst));

	# 格要素と用言の間に連用形名詞化が存在するかどうか
	return undef if (&hasIntermediateVerbalNoun($child, $bnst));

	# 読点アリで文末などでない
	return undef if ($child->fstring =~ /\<読点\>/ && $EOSV == 0);

	$child->fstring =~ /\<係:([^\>]+)\>/ and my $childCase = $1;
	# ト格で並列はだめ
	return undef if ($child->dpndtype eq 'P' && $childCase eq "ト格");


	# 「では」, 「でも」, 「にも」, 「とは」, 「とも」, 「にと」はとりあえずだめ
	return undef if ($child->fstring =~ /\<(?:デハ|デモ|ニモ|トハ|トモ|ニト)\>/ || 
			 $child->fstring =~ /\<ト\>\<ハ\>/ ||  # 「とは」の現在のfeature
			 $child->fstring =~ /\<ト\>\<ニ\>/);   # 「にと」の現在のfeature

	# 指示詞, 接続詞はいらない
	return undef if ($child->fstring =~ /\<(?:指示詞|接続詞)\>/);

	# 補文ではない<括弧終>の格要素はだめ
	return undef if ($child->fstring =~ /\<括弧終\>/ && $child->fstring !~ /\<補文\>/);


	# 「〜だけに」,「〜なしに」はニ格ではない場合がある
	return undef if (&hasFuzoku($child, ['だけ', 'に']) || 
			 &hasFuzoku($child, ['なし', 'に']));

	# 「係:隣接 + <数量>:ガ|ヲ格」は収集しない
	return undef if (&isRinsetsuSuuryo($bnst->{_prev}, $bnst));

	# 〜が〜の疑: このガ格を収集しない
	my $bnstN = $child->{_next};
	return undef if (defined($bnstN) && $bnstN->fstring =~ /\<〜が〜の疑\>/);

	# 直前格要素ではないト格は並列の可能性が低いもののみ収集する
	if (!$adjacencyFlag && $childCase eq  'ト格') {
	    if ($child->fstring =~ /\<並列類似度:([^\>]+)\>/) {
		if ($1 >= 2.0) {
		    return undef;
		}
	    }
	}
    }

    my $isFukugoji = 0;
    my $TYPE;
    my $content;
    # 複合辞 (連用のみ)
    if ($child->fstring =~ /\<複合辞\>/ && 
	$child->fstring =~ /\<係:連用\>/ && 
	$child->fstring !~ /〜によると/) {
	# 前の文節の助詞
	my $bnstP = $child->{_prev};
	$TYPE = $bnstP->mrph(-1)->genkei;
	# 複合名詞フラグ (1つ前をチェックし直す)
	my $compoundNounFlag = (&isCompoundNoun($bnstP))? '%' : '';
	# 自分の自立語
	for my $mrph ($child->mrph) {
	    # 特殊, 助詞以外
	    if ($mrph->hinsi ne '特殊' && $mrph->hinsi ne '助詞') {
		$TYPE .= $mrph->genkei;
	    }
	}

	# 複合辞の統一
	$TYPE = $fukugojiList->{$TYPE} if (defined($fukugojiList->{$TYPE}));

	if (!&isValidFukugoji($TYPE)) {
	    Egnee::Logger::warn("Illegal fukugoji %s\n", $TYPE);
	    return undef;
	}
	$isFukugoji = 1;
	$content = $self->getCaseComponentsContent($bnst, $bnstP, undef, $adjacencyFlag);
    } else {
	# 修飾をひとつの格にする
	if ($child->fstring =~ /\<修飾\>/) {
	    $TYPE = "修飾";
	} else {
	    # その子供が〜格であれば (未格以外)
	    return undef unless ($TYPE = &getCaseType($child));
	}
	$content = $self->getCaseComponentsContent($bnst, $child, \$TYPE, $adjacencyFlag);
    }

    return undef unless ($content);
    return (sprintf("%s:%s%s%s", $content, $TYPE, $compoundNounFlag, $adjacencyFlag), $isFukugoji);
}

# 登録する自立語を生成する関数
sub getCaseComponentsContent {
    my ($self, $bnst, $caseBnst, $TYPE,, $adjacencyFlag) = @_;

    # そのままの表記
    my $lastword = $self->getRepresentation($caseBnst, 0);

    $caseBnst->fstring =~ /\<係:([^\>]+)\>/ and my $case = $1;
    my $content;
    if ($caseBnst->fstring =~ /\<補文\>/) {
	# 引用の場合汎化 => <補文>
	$content = '<補文>';
    } elsif (($caseBnst->fstring =~ /\<時間\>/ || &isTime($lastword))
	     && (&isStrongTime($caseBnst) || !$adjacencyFlag)) {

	# WARNING: このロジックは怪しい

	# 時間の場合汎化
	# 強時間 または 直前格要素以外の普通の時間  => <時間>
	$content = sprintf("<時間>:%s", $lastword);
	# 直前格要素ではないなら時間格にする
	# … 中身が<時間>となったものの一部が時間格となる
	if (defined($case) &&
	    ($case eq '無格' || 
	     (!$adjacencyFlag && defined($TYPE) && $case eq 'ニ格'))) {
	    $$TYPE = "時間";
	}
    } elsif ($caseBnst->fstring =~ /\<数量\>/ && &isNumeral($lastword)) {
	# 数量の場合汎化 => <数量>

	# ????????
	# # ひとつ前の文節
	# $target = $caseBnst->{_prev};

	# 数量に単位があるとき
	my $str = $self->getMrphCounter($caseBnst);
	if ($str) {
	    $content = sprintf("<数量>%s:%s", $str, $lastword);
	}
	else {
	    $content = sprintf("<数量>:%s", $lastword);
	}
    } elsif (&hasFuzoku($caseBnst, ['前|中|後|間'])) {
	# 〜前,中,後
	if ($caseBnst->fstring =~ /\<時間\>/) { # 時間
	    if ($self->{opt}->{useRepname}) {
		$content = sprintf("<時間>:%s", $lastword . '+' . $self->getFirstFuzoku($caseBnst));
	    } else {
		$content = sprintf("<時間>:%s", $lastword . $self->getFirstFuzoku($caseBnst));
	    }

	    if (defined($case) &&
		($case eq '無格' || 
		 (!$adjacencyFlag && defined($TYPE) && $case eq 'ニ格'))) {
		$$TYPE = "時間";
	    }
	} else {
	    # それ以外?
	    $content = $self->getFirstFuzoku($caseBnst);
	}
    } else {
	if (&isSkipWord($lastword)) {
	    # 「もの」やひらがな一文字は除く
	    $content = undef;
	} elsif (&hasMrphsFeature($caseBnst, '顔文字')) {
	    # 顔文字を除く
	    $content = undef;
	} else {
	    $content = $lastword;
	    
	    # 固有表現の場合汎化 => <NE:*>   
	    if ($caseBnst->fstring =~ /\<NE:(.*?):.*?\>/) {
		$content = $content . ";n" . $1;
	    }
	    # カテゴリの場合汎化 => <カテゴリ:*>   
 	    if ($caseBnst->fstring =~ /\<カテゴリ:(.*?)\>/) {
		$content = $content . ";c" . $_ for (split (/:|;/, $1));
	    }
	}
    }

    # 汎化しない
    if (!$self->{opt}->{generalize}) {
	if (defined($content) && $content =~ /\<.+\>/) {
	    return $lastword;
	}
    }
    return $content;
}

# ノ格要素の抽出
sub getNoCase {
    my ($self, $bnst, $caseList, $phrases, $vtype, $adjacence) = @_;

    my $componentBnst;

    my $bnstP = $bnst->{_prev};
    if ($vtype eq '判') { # 判定詞
	if (scalar(@$caseList) > 0 && defined($bnstP)) {
	    $bnstP->fstring =~ /\<係:([^\>]+)\>/;
	    my $caseP = $1 || '';
	    if ($caseP eq 'ノ格' && $bnstP->parent == $bnst) {
		$componentBnst = $bnstP;
	    }
	}
    } elsif (defined($adjacence) && &doesExistClosest($caseList) && defined($bnstP)) { # 動詞, 形容詞
	my $bnstPP = $bnstP->{_prev};
	if (defined ($bnstPP)) {
	    $bnstPP->fstring =~ /\<係:([^\>]+)\>/;
	    my $casePP = $1 || '';
	    if ($casePP eq 'ノ格' && $bnstPP->parent == $adjacence) {
		$componentBnst = $bnstPP;
	    }
	}
    }

    if (defined($componentBnst)) {
	my $component = $self->getCaseComponent($bnst, $componentBnst, 'ノ格', $adjacence);
	return undef unless ($component); # 失敗することがある
	splice(@$caseList, scalar(@$caseList) - 1, 0, { string => $component, bnst => $componentBnst });
	my $tmp = pop(@$phrases);
	push(@$phrases, (join('', map { $_->midasi } ($componentBnst->mrph))));
	return $componentBnst;
    }

    return undef;
}

# ガ格|ヲ格 <数量>:無格* ならば入れ替え
# 直前格要素を交換する
# ほかの格は?
sub swapMukaku {
    my ($list) = @_;
    if (scalar(@$list) > 1 && $list->[$#{$list}]->{string} =~ /\<数量\>[^:]*:[^:]+:無格/ && 
	$list->[$#{$list}-1]->{string} =~ /(?:ガ|ヲ)格$/ && 
	$list->[$#{$list}-1]->{string} !~ /\<数量\>/) {
	# スワップ
	($list->[$#{$list}-1], $list->[$#{$list}]) = ($list->[$#{$list}], $list->[$#{$list}-1]);
	$list->[$#{$list}-1]->{string} =~ s/\*$//; # 直前格マークを削除
	$list->[$#{$list}]->{string} .= '*';       # 直前格マークを付与
	return 1;
    }
    return 0;
}

# 格要素表記を作り出す
sub getRepresentation {
    my ($self, $bnst, $useGenkei) = @_;

    if ($self->{opt}->{useCompoundNoun}) {
	# 複合名詞から表記を作るとき
	return $self->getCompoundRepresentation($bnst, $useGenkei);
    } else {
	# 主辞のみから表記を作るとき
	return $self->getHeadRepresentation($bnst, $useGenkei);
    }
}

# 主辞の格要素表記を作り出す
sub getHeadRepresentation {
    my ($self, $bnst, $useGenkei) = @_;

    if (!$self->{opt}->{useRepname}) { # 代表表記を使わないとき
	return $self->getHeadRepresentationForNonReppname($bnst, $useGenkei);
    } else {
	return $self->getHeadRepresentationForRepname($bnst, $useGenkei);
    }
}

# 主辞の格要素表記を作り出す (非代表表記版)
sub getHeadRepresentationForNonRepname {
    my ($self, $bnst, $useGenkei) = @_;

    my $ret = '';

    my $lastJiritsuMrph = $bnst->{_jiritsu}->[-1];
    # FIX
    # sometimes $bnst has no jiritsu mrph
    return undef unless (defined($lastJiritsuMrph));

    my @mrphList = $bnst->mrph;
    my $lastHeadMrph = $lastJiritsuMrph;

    # 最後自立語の次の付属語があれば求めておく
    while (scalar(@mrphList) > 0) {
	my $mrph = shift(@mrphList);
	last if ($mrph == $lastJiritsuMrph);
    }
    my $mrph = $mrphList[0];
    if (defined($mrph)) {
	if ($lastJiritsuMrph->hinsi eq '形容詞'
	    && $lastJiritsuMrph->katuyou2 eq '語幹'
	    && $mrph->genkei eq 'さ') {
	    # 形容詞語幹+「さ」などの場合 (e.g.「長さ」)
	    $ret = $lastJiritsuMrph->midasi;
	    $lastHeadMrph = $mrph;
	} elsif ($mrph->genkei eq '的だ' || $mrph->genkei eq '化' || 
		 $mrph->fstring =~ /\<(?:(?:準)?内容語|意味有)\>/) {
	    # 「化」「県」などはこの一語のみ
	    $lastHeadMrph = $mrph;
	}
    }

    if ($useGenkei) {
	$ret .= $lastHeadMrph->genkei;
    } else {
	$ret .= $lastHeadMrph->midasi;
    }
    return $ret;
}

# 主辞の格要素表記を作り出す (代表表記版)
sub getHeadRepresentationForRepname {
    my ($self, $bnst, $useGenkei) = @_;

    # 文節に<主辞代表表記:..>がある場合
    if ($bnst->fstring =~ /<主辞代表表記:([^>]+)>/) {
	return $1;
    }
    my $ret = '';

    my $lastJiritsuMrph = $bnst->{_jiritsu}->[-1];
    # FIX
    # sometimes $bnst has no jiritsu mrph
    return undef unless (defined($lastJiritsuMrph));

    my @mrphList = $bnst->mrph;
    my $lastHeadMrph = $lastJiritsuMrph;

    # 最後自立語の次の付属語があれば求めておく
    while (scalar(@mrphList) > 0) {
	my $mrph = shift(@mrphList);
	last if ($mrph == $lastJiritsuMrph);
    }
    my $mrph = $mrphList[0];
    if (defined ($mrph)) {
	if ($lastJiritsuMrph->hinsi eq '形容詞'
	    && $lastJiritsuMrph->katuyou2 eq '語幹'
	    && $mrph->genkei eq 'さ') {
	    # 形容詞語幹+「さ」などの場合 (e.g.「長さ」)

	    my $tmpret = &getRepname($lastJiritsuMrph);

	    # process ALT
	    my $altret = {};
	    $altret->{$ret} = 1;
	    foreach my $doukei ($lastJiritsuMrph->doukei) {
		my $repname = &getRepname($doukei);
		$altret->{$repname}++;
	    }
	    # WARNING: EUC-JP の場合と順序が違う
	    $ret = join('?', &esort(keys(%$altret))); # uniq

	    $lastHeadMrph = $mrph;
	} elsif ($mrph->genkei eq '的だ' || $mrph->genkei eq '化' || 
		 $mrph->fstring =~ /\<(?:(?:準)?内容語|意味有)\>/) {
	    # 「化」「県」などはこの一語のみ
	    $lastHeadMrph = $mrph;
	}
    }

    # 数量、時間は代表表記なし

    if ($bnst->fstring =~ /\<時間\>/ || $bnst->fstring =~ /\<数量\>/) {
	$ret .= &getRepname($lastHeadMrph);
    } else {
	my $tmpret = &getRepname($lastHeadMrph);

	# 早い/はやい+さ/さ?速い/はやい+さ/さ
	if ($ret =~ /^(.+)\?(.+)\+$/) {
	    $ret =~ s/\+$//;
	    my @altret = split(/\?/, $ret);
	    foreach my $gokan (@altret) {
		$gokan .= '+' . $tmpret;
	    }
	    $ret = join('?', @altret);
	} else {
	    $ret .= $tmpret;
	}
	
	# process ALT
	my $altret = {};
	$altret->{$ret} = 1;
	foreach my $doukei ($lastHeadMrph->doukei) {
	    if ($doukei->imis  =~ /代表表記:([^\s\"]+)/) {
		# 無理/むり?無理だ/無理だ を防止
		$tmpret = $1;
		my $tmpret2 = $tmpret;
		if ($tmpret2 =~ /だ\//) {
		    $tmpret2 =~ s/だ\//\//g;
		    $tmpret2 =~ s/だ$//g;
		    next if ($tmpret2 eq $ret);
		}
		$altret->{$tmpret}++;
	    } elsif (($doukei->fstring =~ /ALT\-([^\-]+)\-([^\-]+)/)) {
		$altret->{"$1/$2"}++;
	    }
	}
	# WARNING: EUC-JP の場合と順序が違う
	$ret = join('?', &esort(keys(%$altret))); # uniq
    }
    return $ret;
}

# 複合名詞の格要素表記を作り出す
sub getCompoundRepresentation {
    my ($self, $bnst, $useGenkei) = @_;

    my @ret = ();

    if ($self->{opt}->{useRepname}) {
	if ($self->{opt}->{useCompoundNoun} > 1) {
	    # 最長複合名詞
	    # 文節に<正規化代表表記:..>がある場合
	    if ($bnst->fstring =~ /<正規化代表表記:([^>]+)>/) {
		return $1;
	    }
	} elsif ($self->{opt}->{useCompoundNoun} == 1) {
	    # 最短複合名詞(主辞が漢字一文字ならひとつ前まで含める)
	    # 文節に<主辞’代表表記:..>がある場合
	    if ($bnst->fstring =~ /<主辞’代表表記:([^>]+)>/) {
		return $1;
	    } else {
		# <主辞’代表表記:..>がなければ<主辞代表表記:..>
		return $self->getHeadRepresentation($bnst, $useGenkei);
	    }
	}
    }

    my $jiritsuStartPoint = -1;
    my $jiritsuEndPoint = -1;
    my @mrphList = $bnst->mrph;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	if ($mrph->fstring =~ /<(?:(?:準)?内容語|意味有)>/) {
	    $jiritsuStartPoint = $i;
	    last;
	}
    }
    for (my $i = scalar(@mrphList) - 1; $i >= 0; $i--) {
	my $mrph = $mrphList[$i];
	if ($mrph->fstring =~ /<(?:(?:準)?内容語|意味有)>/) {
	    $jiritsuEndPoint = $i;
	    last;
	}
    }
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	if ($i >= $jiritsuStartPoint) {
	    if ($i == $jiritsuEndPoint) {
		# 最後の自立語
		push (@ret, $self->getMrphRepresentation($mrph, $useGenkei));
	    } else {
		# 複合名詞の途中
		push (@ret, $self->getMrphRepresentation($mrph, 0));
	    }
	}
    }
    return join('+', @ret);
}

# ExtractMorphRepname()へのラッパー (非代表表記サポートのため)
sub getMrphRepresentation {
    my ($self, $mrph, $useGenkei) = @_;

    if (!$self->{opt}->{useRepname}) {
	if ($useGenkei) {
	    return $mrph->genkei;
	} else {
	    return $mrph->midasi;
	}
    } else {
	return &getRepname2($mrph);
    }
}

sub isAdjacent {
    my ($caseBnst, $adjacence) = @_;
    return (defined($adjacence) && $adjacence == $caseBnst)? 1 : 0;
}

sub isCompoundNoun {
    my ($bnst) = @_;

    my $jiritsuMrphList = $bnst->{_jiritsu};
    return (scalar (@$jiritsuMrphList) > 1)? 1 : 0;
}

# 正規化周りで検討が必要
sub getRepname {
    my ($mrph) = @_;

    return $1 if ($mrph->imis =~ /代表表記:([^\s\"]+)/);
    return $1 if (($mrph->fstring || '') =~ /疑似代表表記:([^\s\>]+)/);
    return $mrph->midasi . '/' . $mrph->yomi;
}


# 形態素の代表表記をつくる
sub getRepname2 {
    my ($mrph) = @_;

    # 形態素に<正規化代表表記:..>がある場合
    return $1 if ($mrph->fstring =~ /<正規化代表表記:([^>]+)>/);
    # 以下、'?'連結には未対応
    return $1 if ($mrph->fstring =~ /代表表記:([^\s\"\>]+)/);
    return $mrph->midasi  . '/' . $mrph->yomi;
}

sub getJiritsuMrphList {
    my ($bnst) = @_;

    my $jiritsuMrphList = [];
    foreach my $mrph ($bnst->mrph) {
	if ($mrph->fstring =~ /\<自立\>/) {
	    push (@$jiritsuMrphList, $mrph);
	}
    }
    return $jiritsuMrphList;
}

# カウンタ文字列の作成
sub getMrphCounter {
    my ($self, $bnst) = @_;

    my ($flag, $begin, $end);
    my @mrphList = $bnst->mrph;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	if ($mrph->fstring =~ /\<カウンタ\>/) {
	    $flag = 1;
	    $begin = $i;
	    $end = $i;
	} elsif ($flag && $mrph->fstring =~ /\<(?:準)?内容語\>/) {
	    # カウンタの後に内容語がある場合
	    $end = $i; # 最後の内容語の位置
	}
    }
    if ($flag) {
	if ($self->{opt}->{useCompoundNoun} > 1) {
	    # 最長複合名詞を使う場合
	    # $beginから$endまでを連結
	    my @strs = ();
	    for (my $i = $begin; $i < scalar(@mrphList); $i++) {
		last if ($i > $end);
		my $mrph = $mrphList[$i];
		push (@strs, $self->getMrphRepresentation($mrph, 1));
	    }
	    return join ('+', @strs);
	} else {
	    # 最後の内容語
	    return $self->getMrphRepresentation($mrphList[$end], 1);
	}
    }
    return undef;
}

# 最初の接尾辞をかえす
sub getFirstFuzoku {
    my ($self, $bnst) = @_;

    my $ret;
    foreach my $mrph ($bnst->mrph) {
	if ($mrph->fstring =~ /\<自立\>/ || $mrph->fstring =~ /\<接頭\>/) {
	    $ret = undef if (defined($ret));
	    next;
	}
	unless (defined($ret)) {
	    $ret = $self->getMrphRepresentation($mrph, 1);
	}
    }
    return $ret;
}

sub getGAGA {
    my ($bnst) = @_;

    my $gaga = {};
    $bnst->fstring =~ /\<係:([^\>]+)\>/;
    my $case = $1 || '';
    if ($bnst->fstring =~ /\<ハ\>/ && $case =~ /(未格)/) {
	$gaga->{$1} = $bnst;
    } elsif ($case =~ /(ガ格)/) {
	$gaga->{$1} = $bnst;
    }
    return $gaga;
}

# 格・副助詞、読点で終わっているか
# 文末か括弧終の文節という仮定あり
sub isJoshiToutenEnding {
    my ($bnst) = @_;

    foreach my $mrph (reverse($bnst->mrph)) {
	if ($mrph->fstring =~ /\<表現文末\>/) {
	    return ($mrph->bunrui =~ /^(?:格|副)助詞$/ || $mrph->midasi =~ /^(?:、|，)$/)? 1 : 0;
	}
    }
    return 0;
}

# 連用形で終わっているか
# 文末か括弧終の文節という仮定あり
sub isRenyouEnding {
    my ($bnst) = @_;

    foreach my $mrph (reverse($bnst->mrph)) {
	if ($mrph->fstring =~ /\<活用語\>/) {
	    return (defined($renyouKatuyouList->{$mrph->katuyou2}))? 1 : 0;
	}
    }
    return 0;
}

# 命令形で終わっているか
# 文末か括弧終の文節という仮定あり
sub isMeireiEnding {
    my ($bnst) = @_;

    foreach my $mrph (reverse($bnst->mrph)) {
	if ($mrph->fstring =~ /\<活用語\>/) {
	    return ($mrph->katuyou2 eq '命令形')? 1 : 0;
	}
    }
    return 0;
}

# 最後の形態素が基本連用形かどうかチェック
sub isLastMrphRenyou {
    my ($bnst) = @_;

    my $mrph = $bnst->mrph(-1);
    return ($mrph->katuyou2 eq  '基本連用形')? 1 : 0;
}

# 「ときに」などであれば真をかえす
sub isTime {
    my ($str) = @_;

    # 代表表記化されている場合は「/」の前だけとる
    if ($str =~ /\//) {
	return 0 if ($str =~ /\+/); # 複合名詞ならチェックしない
	$str = (split('/', $str))[0];
    }

    return (defined($timeNoun->{$str}))? 1 : 0;
}

# 「３時」,「３年」などであれば真をかえす
sub isStrongTime {
    my ($bnst) = @_;
    return ($bnst->fstring =~ /\<強時間\>/)? 1 : 0;
}

# 「何」単体などは<数量>ではないと判断する
sub isNumeral {
    my ($str) = @_;

    # 代表表記化されている場合は「/」の前だけとる
    if ($str =~ /\//) {
	return 1 if ($str =~ /\+/); # 複合名詞ならチェックしない
	$str = (split('/', $str))[0];
    }

    return (defined($noNumeral->{$str}))? 0 : 1;
}

# 接尾辞列をチェックする
sub hasFuzoku {
    my ($bnst, $target) = @_;

    my $match = 0;
    my $end = -1;
    my @mrphList = $bnst->mrph;
    for (my $i = scalar(@mrphList) - 1; $i >= 0; $i--) {
	my $mrph = $mrphList[$i];
	if ($mrph->fstring =~ /\<自立\>/ || $mrph->fstring =~ /\<接頭\>/) {
	    $end = $i;
	    last;
	}
    }
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	next if ($i <= $end);
	my $mrph = $mrphList[$i];
	if ($mrph->genkei =~ /^(?:$target->[$match++])$/) {
	    if ($match == scalar(@$target)) {
		return 1;
	    }
	} else {
	    return 0;
	}
    }
    return 0;
}

sub hasMrphsFeature {
    my ($bnst, $f) = @_;
    foreach my $mrph ($bnst->mrph) {
	if ($mrph->fstring =~ /\<$f\>/) {
	    return $mrph;
	}
    }
    return 0;
}

sub hasIntermediateVerb {
    my ($bnst1, $bnst2) = @_;

    my $bnst = $bnst1;
    while (($bnst = $bnst->{_next})) {
	last if ($bnst == $bnst2);
	return 1 if ($bnst->fstring =~ /\<用言/);
    }
    return 0;
}

sub hasIntermediateUNK {
    my ($bnst1, $bnst2) = @_;

    my $bnst = $bnst1;
    while (($bnst = $bnst->{_next})) {
	last if ($bnst == $bnst2);
	foreach my $mrph ($bnst->mrph) {
	    # 未知語
	    return 1 if ($mrph->fstring =~ /\<(?:ORG|品詞変更):[^\-]+\-[^\-]+\-[^\-]+\-15\-/);
	}
    }
    return 0;
}

sub hasIntermediateVerbalNoun {
    my ($bnst1, $bnst2) = @_;

    my $bnst = $bnst1;
    while (($bnst = $bnst->{_next})) {
	last if ($bnst == $bnst2);
	foreach my $mrph ($bnst->mrph) {
	    # 未知語
	    return 1 if ($mrph->fstring =~ /\<連用形名詞化\>/);
	}
    }
    return 0;
}

sub doesExistClosest {
    my ($list) = @_;

    for my $ins (@$list) {
	return 1 if ($ins->{string} =~ /\*$/);
    }
    return 0;
}

# 「みかん三個を食べる」のタイプは収集しない
# 「三個を食べる」になるのはこのパターン固有
sub isRinsetsuSuuryo {
    my ($bnstP, $bnst) = @_;

    return 0 unless (defined($bnstP));

    $bnst->fstring =~ /\<係:([^\>]+)\>/;
    my $case = $1 || '';
    if ($case =~ /^(?:ガ|ヲ)格$/ && $bnst->fstring =~ /\<数量\>/) {
	$bnstP->fstring =~ /\<係:([^\>]+)\>/;
	my $caseP = $1 || '';
	return 1 if ($caseP eq '隣接');
    }
    return 0;
}

# 同じ格が複数個以上あるかチェック
sub isCaseDuplicated {
    my ($list) = @_;

    my $struct = {};
    for my $data (@$list) {
	$data->{string} =~ /[^:]+:([^:\%\*]+)[\%\*]*$/;
	if ($struct->{$1}++) {
	    return 1;
	}
    }
    return 0;
}

# 辞書に登録しない単語ならば真をかえす
sub isSkipWord {
    my ($key, $sm) = @_;

    # 代表表記化されている場合は「/」の前だけとる
    $key = (split('/', $key))[0] if ($key =~ /\//);

    return 1 if (defined($stopwordList->{$key}));

    # EUC による比較
    my $enc = $key;
    # 実際に変換してチェック
    eval {
	# 失敗したら死ぬ
	$enc = $euc->encode($enc, Encode::FB_CROAK);
    };
    if ($@) {
	return 1;
    }
    {
	use bytes;
	# ひらがなをチェック
	if (&isHiragana($enc)) {
	    # 1文字のひらがなは登録しない
	    if (length($enc) < 3) {
		return 1;
	    } elsif ($sm && length ($enc) < 5) {
		# 2文字以下のひらがなをチェック (sm使用)
		my ($count);

		foreach my $ex ($sm->GetSM($enc)) {
		    next if $ex =~ /^[2m]/;
		    # 固有か接辞以外
		    $count++;
		}
		return 1 if ($count > 3);    # 曖昧性が3つ以上なら登録しない
	    }
	}
    }

    # 記号を除く
    if ($key =~ /^\p{S}+$/ || $key =~ /^\p{InCJKSymbolsAndPunctuation}+$/) {
	return 1;
    }
    return 0;
}

sub isHiragana {
    use bytes;

    my ($str) = @_;

    while ($str =~ /([\x80-\xff]{2})/g) {
	my $char = $1;
	return 0 if $char !~ /^\xa4/;
    }
    return 1;
}

# 全部ひらがなであるかチェック
sub isValidFukugoji {
    my ($str) = @_;
    my $enc;
    eval {
	# 失敗したら死ぬ
	$enc = $euc->encode($str, Encode::FB_CROAK);
    };
    if ($@) {
	return 0;
    }

    {
	use bytes;
	while ($enc =~ /([\x80-\xff]{2})/g) {
	    my $char = $1;
	    if ($char !~ /\xa4(.)/) {
		return 0;
	    }
	}
	return 1;
    }
}

# EUC-JP に従ってソート
sub esort {
    my @tmp;
    foreach my $key (@_) {
	push (@tmp, $euc->encode($key));
    }
    my @tmp2 = sort(@tmp);
    undef(@tmp);
    foreach my $key (@tmp2) {
	push(@tmp, $euc->decode($key));
    }
    return @tmp;
}

# 特殊な操作をほどこした KNP::Result に対して作用するので、
# あらかじめ prepare を呼ぶ必要がある。
# また、終了後は clean を呼んで掃除する。
#
# 格解析結果で係り受けからの抽出を模倣
sub extractProbcase {
    my ($self, $knpResult, $i, $paList) = @_;
    my $bnst = $knpResult->bnst($i);
    my $fstring = $bnst->fstring;
    my $id = $knpResult->id;

    foreach my $tag (reverse($bnst->tag)) {
	next unless ($tag->fstring =~ /\<格解析結果:(.+?):([^:]+(?::[A-Z]+)?\d+):(.+?)\>/);
	my ($verb, $cfId, $caseString) = ($1, $2, $3);
	my $vtype = substr($cfId, 0, 1);
	next if ($vtype eq '名');

	# 用言表記
	my $jiritsuMrphList = $bnst->{_jiritsu};
	unless (scalar(@$jiritsuMrphList) > 0) {
	    Egnee::Logger::warn("something wrong with case frame $1:$2\n");
	    next;
	}
	my $V;
	if ($self->{opt}->{useRepname}) {
	    $V = &getPredRepresentationForRepname($bnst, $vtype, $jiritsuMrphList->[-1]);
	} else {
	    $V = &getPredRepresentation($bnst, $vtype, $jiritsuMrphList->[-1]);
	}
	unless (defined($V)) {
	    Egnee::Logger::warn("cannot create predicate string $1:$2\n");
	    next;
	}

	# 格要素
	my $caseList = [];
	foreach (split(/;/, $caseString)) {
	    my ($case, $flag, $arg, $tid, $bid, $sid) = split(/\//, $_);
	    next if ($arg eq '-'); # no case element
	    next unless ($flag eq 'C' || $flag eq 'N'); # 直接係り受け (格明示/格非明示)
	    next unless ($sid eq $id);
	    my $caseBnst = $knpResult->tag($tid)->{_bnst};
	    $caseBnst->push_feature('採用文節'); # no parentheses

	    my $TYPE;
	    if ($flag eq 'N' && $bnst->fstring =~ /\<連体修飾\>/) {
		$TYPE = '連体'; # 今のところ、「連体」は Examples の振舞いに合わせる
	    } else {
		if ($case eq 'ガ２') {
		    $TYPE = 'ガ格';
		} elsif ($case eq '外の関係') {
		    $TYPE = '連体';
		} elsif ($case =~ /^\p{Katakana}+$/) {
		    $TYPE = $case . '格'; # ヲ, ニなど
		} else {
		    $TYPE = $case; # default
		}
	    }
	    # 4th arg is dummy
	    # 必ず直前格扱いになる
	    my $component = $self->getCaseComponent($bnst, $caseBnst, $TYPE, $caseBnst);
	    if (defined($component)) {
		push(@$caseList, { string => $component, bnst => $caseBnst });
	    }

	}
	next unless (scalar(@$caseList) > 0);

	# ノ格は $caseBnstList に入っていない
	my $paStruct = {
	    verb => $V,
	    verbBunsetsu => $bnst,
	    caseList => $caseList,
	};
	push(@$paList, $paStruct);

	if ($self->{opt}->{dump}) {
	    printf("%s %s %s\n", $knpResult->id, $V, join(' ', (map { $_->{string} } @$caseList)));
 	}
    }
}

1;
