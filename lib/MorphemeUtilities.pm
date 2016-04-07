package MorphemeUtilities;
# Juman::Morpheme, KNP::Morpheme に関する utility 関数のコレクション

use strict;
use warnings;
use utf8;

use Encode;
use Unicode::Japanese;

use Juman::Grammar qw/ $FORM /;

our $enc = Encode::find_encoding('utf8');

# OBSOLETE
# 辞書に使える文字列かをチェック
# 問題があれば 0
sub isEUCConvertible {
    my ($str) = @_;

    # makeint は 1byte ずつチェックして 0x80 以下ならエラーとする
    # 
    # 二段階処理
    # 1. Encode で変換できるかチェック。これによりハングルなどは除外
    # 2. バイト列を走査。ASCII、半角カナ、3バイト漢字を除外

    my $enc;
    # 実際に変換してチェック
    eval {
	# 失敗したら死ぬ
	$enc = encode('euc-jp', $str, Encode::FB_CROAK);
    };
    if ($@) {
	print STDERR ($@);
	return 0;
    }
    {
        use bytes;
	#  region:         ASCII        HALF KANA         3 byte KANJI
	while ($enc =~ /([\x00-\x7F]|\x8e[\xa1-\xdf]|\x8f[\xa1-\xfe][\xa1-\xfe])/) {
	    print STDERR ("1 byte?\n");
	    return 0;
	}
    }
    return 1;
}


# 未定義語か否か
sub isUndefined {
    my ($mrph) = @_;
    # 2番目の項は KyotoCorpus 対策
    if (ref($mrph) eq 'KNP::Morpheme' && defined($mrph->fstring) && $mrph->fstring !~ /\<品詞変更差戻\>/) {
	# 未定義語は KNP が品詞変更している
	return ($mrph->fstring =~ /\<品詞変更\:[^-]+-[^-]+-[^-]+-15-/)? 1 : 0;
    } else {
	return ($mrph->hinsi eq '未定義語');
    }
}


# 適当に読みを振る
# わからなければ見出しのまま
# $flag は確信があるか否か
sub makeYomiFromMidasi {
    my ($midasi) = @_;

    my $rv = '';
    my @c = split(//, $midasi);
    my $flag = 1;
    foreach my $c (@c) {
	# 注意: 「ー」は Hiragana にも Katakana にも含まれない
	if ($c =~ /\p{Hiragana}/) {
	    $rv .= $c;
 	} elsif ($c =~ /\p{Katakana}/) {
 	    $rv .= Unicode::Japanese->new ($c)->kata2hira->getu;
	} else {
	    $rv .= $c;
	    $flag = 0;
	}
    }
    return wantarray? ($rv, $flag) : $rv;
}

sub makeRepnameFromMidasi {
    my ($midasi) = @_;

    
    $midasi =~ tr/！＂＃＄％＆＇＊＋，－．／：；＜＝＞？＠［＼］＾＿｀｛｜｝～/!"#$%&'*+,-.\/:;<=>?@[\\]^_`{|}~/;
    $midasi =~ tr/０-９ａ-ｚＡ-Ｚ/0-9a-zA-Z/;
    my $yomi = &makeYomiFromMidasi($midasi);
    return $midasi . '/' . $yomi;
}

# 語幹から基本形を作る
sub getMidasiFromStem {
    my ($stem, $katuyou1) = @_;

    my $newForm = $enc->encode('基本形'); # utf-8 にもどす
    my $type = $katuyou1;
    if(utf8::is_utf8($type)){
	$type = $enc->encode($type); # utf-8 にもどす
    }
    my $newID = $FORM->{$type}->[0]->{$newForm};
    my @newGobi = @{$FORM->{$type}->[$newID]};

    map( { $_ = $enc->decode($_) } @newGobi ); # encode されてるなら decode

    my $midasi = $stem;
    my $add = $newGobi[1];

    unless ($add eq '*') {
	$midasi .= $add;
    }
    return $midasi;
}

# 活用形を変化させる
sub getInflectedForm {
    my ($midasi, $katuyou1, $katuyou2F, $katuyou2T) = @_;

    my $oldForm = $enc->encode($katuyou2F); # utf-8 にもどす
    my $newForm = $enc->encode($katuyou2T); # utf-8 にもどす
    my $type = $katuyou1;
    if(utf8::is_utf8($type)){
	$type = $enc->encode($type); # utf-8 にもどす
    }
    my $oldID = $FORM->{$type}->[0]->{$oldForm};
    my @oldGobi = @{$FORM->{$type}->[$oldID]};
    my $newID = $FORM->{$type}->[0]->{$newForm};
    return undef unless (defined($newID));
    my @newGobi = @{$FORM->{$type}->[$newID]};

    map( { $_ = $enc->decode($_) } @oldGobi ); # encode されてるなら decode
    map( { $_ = $enc->decode($_) } @newGobi ); # encode されてるなら decode

    my $inflected = $midasi;
    unless ($oldGobi[1] eq '*') {
	$inflected = substr($midasi, 0, length($midasi) - length($oldGobi[1]));
    }
    unless ($newGobi[1] eq '*') {
	$inflected .= $newGobi[1];
    }
    return $inflected;
}


# 形態素を語幹と語尾に分解
# Juman::Katuyou のメソッドを使っていたが、
# KyotoCorpus が古いので問題が発生する
sub decomposeKatuyou {
    my ($mrph) = @_;

#     # change_katuyou2 では活用形がずれる
#     my $stemMrph = $mrph->change_katuyou2 ('語幹');
#     if (defined ($stemMrph)) {
# 	my $stem = $stemMrph->midasi;
# 	if ($mrph->midasi =~ /^$stem(.*)$/) {
# 	    return [$stem, $1];
# 	}
#     }
    my $newForm = $enc->encode('語幹'); # utf-8にもどす
    my $oldForm = $enc->encode($mrph->katuyou2); # utf-8にもどす
    my $type = $mrph->katuyou1;
    if(utf8::is_utf8($type)){
	$type = $enc->encode($type); # utf-8にもどす
    }
    my $oldID = $FORM->{$type}->[0]->{$oldForm};
    if ( !defined($oldID) || $oldID <= 0 ) {
	return ($mrph->midasi, '');
    }
    my $newID = $FORM->{$type}->[0]->{$newForm};
    my @oldGobi = @{$FORM->{$type}->[$oldID]}; # utf-8でやりとり
    my @newGobi = @{$FORM->{$type}->[$newID]};

    if (utf8::is_utf8($mrph->midasi)){
	map( { $_ = $enc->decode($_) } @oldGobi ); # encodeされてるならencode
	map( { $_ = $enc->decode($_) } @newGobi );
    }
    # $new->{midasi} = &_change_gobi( $this->midasi, $oldgobi[1], $newgobi[1] );
    my $stem = $mrph->midasi;
    my ($cut, $add) = ($oldGobi[1], $newGobi[1]);

    unless ($cut eq '*') {
	$stem =~ s/$cut\Z//;
    }
    unless ($add eq '*') {
	$stem .= $add;
    }
    return ($stem, ($cut eq '*')? '' : $cut);
}


# 代表表記や品詞に変更があった場合元に戻す
# なければ元の形態素を返す
# 内部構造いじりまくり
sub getOriginalMrph {
    my ($mrph, $opt) = @_;
    # option
    #   doukei: $mrph が同形形態素
    #   revertVoicing: 連濁の差戻しを行なうか

    # 何度も使うので結果をキャッシュ
    # 自身の場合には original に 0 を入れる
    # 循環参照をやらないようにしているが、効果があるかは調べてない
    # 連濁の差戻しは特殊なのでキャッシュしない
    if (!$opt->{revertVoicing} && defined($mrph->{original})) {
	return ($mrph->{original})? $mrph->{original} : $mrph;
    }

    # 変更の必要がない
    unless ($opt->{doukei} || (defined($mrph->fstring) && $mrph->fstring =~ /\<代表表記変更\:([^\>]+)\>/)
	    || ($opt->{revertVoicing} && index($mrph->imis, '濁音化') >= 0) ) {
	unless ($opt->{revertVoicing}) {
	    $mrph->{original} = 0;
	}
	return $mrph;
    }

    # 同形形態素の処理
    #   親形態素の getOriginalMrph が呼ばれたときには変更しない
    #   あとで同形形態素の getOriginalMrph を呼ぶ
    my $clone = &cloneMrph($mrph, { skipDoukeiClone => 1 });
    if ($mrph->imis =~ /品詞変更\:([^\s^\"]+)/) {
	my $code = $1;

	# 動詞は品詞も変更
	# $code の最後の意味素は使わない
	my ($midasi, $yomi, $genkei, $hinsi_id, $bunrui_id, $katuyou1_id, $katuyou2_id) = split( '-', $code);

	my $hinsi = $clone->get_hinsi($hinsi_id);
	my $bunrui = $clone->get_bunrui($hinsi_id, $bunrui_id) || '*'; # for ill-defined 副詞
	my $katuyou1 = $clone->get_type($katuyou1_id);
	my $katuyou2 = $clone->get_form($katuyou1_id, $katuyou2_id);

	if(utf8::is_utf8($code)){
	    $hinsi = $enc->decode($hinsi);
	    $bunrui = $enc->decode($bunrui);
	    $katuyou1 = $enc->decode($katuyou1);
	    $katuyou2 = $enc->decode($katuyou2);
	}

	$clone->{midasi} = $midasi;
	$clone->{yomi} = $yomi;
	$clone->{genkei} = $genkei;
	$clone->{hinsi} = $hinsi;
	$clone->{hinsi_id} = $hinsi_id;
	$clone->{bunrui} = $bunrui;
	$clone->{bunrui_id} = $bunrui_id;
	$clone->{katuyou1} = $katuyou1;
	$clone->{katuyou1_id} = $katuyou1_id;
	$clone->{katuyou2} = $katuyou2;
	$clone->{katuyou2_id} = $katuyou2_id;
	$clone->{imis} = $mrph->imis;

	# 後処理
	$clone->{imis} =~ s/品詞変更\:([^\s^\"]+)//;
	if (defined($clone->{fstring})) {
	    $clone->{fstring} =~ s/<品詞変更\:([^>]+)>//;
	    $clone->{fstring} .= '<品詞変更差戻>'; # 一応 feature を追加しておく
	}
    }
    # 形容詞は代表表記の変更のみ

    # 代表表記
    if (defined($clone->{fstring})) {
	$clone->{fstring} =~ s/\<(正規化)?代表表記\:([^>]+)\>//g;
	$clone->{fstring} =~ s/\<代表表記変更\:/\<代表表記\:/;
    }
    $clone->{imis} =~ s/代表表記\:([^\s]+)\s//;
    $clone->{imis} =~ s/代表表記変更\:/代表表記\:/;

    $clone->fstring($clone->{fstring}); # 最後に feature 配列を更新

    # 連濁差戻し
    if ($opt->{revertVoicing}) {
	&revertVoicing($clone);
    } else {
	$mrph->{original} = $mrph;
    }

    # 同形の品詞変更:
    # 意味素に埋め込まれているので、普通に getOriginalMrph を呼ぶだけでよい
    #  e.g. <ALT-たき-たき-たき-6-1-0-0-"ドメイン:家庭・暮らし 代表表記:焚き/たきv 代表表記変更:焚く/たく 品詞変更:たき-たき-たく-2-0-2-8">
    if ($mrph->{doukei}) {
	for (my $i = 0; $i < scalar(@{$mrph->{doukei}}); $i++) {
	    my $mrph2 = $mrph->{doukei}->[$i];
	    $clone->{doukei}->[$i] = &getOriginalMrph($mrph2, { doukei => 1 });
	}
    }

    return $clone;
}


# 思いっきり KNP::Morpheme の構造に依存
sub cloneMrph {
    my ($mrph, $opt) = @_;

    my $clone = {};

    while ((my $key = each(%$mrph))) {
	if (ref ($mrph->{$key}) eq 'ARRAY') {
	    # feature ARRAY; do nothing
	} else {
	    $clone->{$key} = $mrph->{$key};
	}
    }
    bless($clone, "KNP::Morpheme");

    # make feature ARRAY
    $clone->fstring($clone->{fstring});

    # make doukei ARRAY
    if ($mrph->{doukei}) {
	if ($opt->{skipDoukeiClone}) {
	    foreach my $mrph2 (@{$mrph->{doukei}}) {
		push(@{$clone->{doukei}}, $mrph2);
	    }
	} else {
	    foreach my $mrph2 (@{$mrph->{doukei}}) {
		push(@{$clone->{doukei}}, &cloneMrph($mrph2));
	    }
	}
    }

    return $clone;
}

# mapping from voiced to voiceless
our $v2vless = {
    'が' => 'か', 'ぎ' => 'き', 'ぐ' => 'く', 'げ' => 'け', 'ご' => 'こ',
    'ガ' => 'カ', 'ギ' => 'キ', 'グ' => 'ク', 'ゲ' => 'ケ', 'ゴ' => 'コ',
    'ざ' => 'さ', 'じ' => 'し', 'ず' => 'す', 'ぜ' => 'せ', 'ぞ' => 'そ',
    'ザ' => 'サ', 'ジ' => 'シ', 'ズ' => 'ス', 'ゼ' => 'セ', 'ゾ' => 'ソ',
    'だ' => 'た', 'ぢ' => 'ち', 'づ' => 'つ', 'で' => 'て', 'ど' => 'と',
    'ダ' => 'タ', 'ヂ' => 'チ', 'ヅ' => 'ツ', 'デ' => 'テ', 'ド' => 'ト',
    'ば' => 'は', 'び' => 'ひ', 'ぶ' => 'ふ', 'べ' => 'へ', 'ぼ' => 'ほ',
    'バ' => 'ハ', 'ビ' => 'ヒ', 'ブ' => 'フ', 'ベ' => 'ヘ', 'ボ' => 'ホ'
};

# 濁音化を差し戻す
# 形態素自身を書き換えるので、必要があれば clone してから呼び出すべき
sub revertVoicing {
    my ($mrph) = @_;

    return $mrph unless (index($mrph->imis, '濁音化') >= 0);

    $mrph->{midasi} = $v2vless->{substr($mrph->{midasi}, 0, 1)} . substr($mrph->{midasi}, 1);
    $mrph->{yomi} = $v2vless->{substr($mrph->{yomi}, 0, 1)} . substr($mrph->{yomi}, 1);

    # 後処理
    $mrph->{imis} =~ s/濁音化//;
    $mrph->{fstring} =~ s/\<濁音化\>// if (ref($mrph) eq 'KNP::Morpheme');
    return $mrph;
}

# p 番目の形態素 -> i 番目の文節の j 番目の形態素
sub makeBnstMap {
    my ($knpResult) = @_;

    my $bnstMap = [];
    my @bnstList = $knpResult->bnst;
    for (my $i = 0; $i < scalar(@bnstList); $i++) {
	my $bnst = $bnstList[$i];
	my @mrphList = $bnst->mrph;

	for (my $j = 0; $j < scalar(@mrphList); $j++) {
	    push(@$bnstMap, [$i, $j]);
	}
    }
    return $bnstMap;
}

1;
