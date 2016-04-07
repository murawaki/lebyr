package JumanDictionary::MorphemeEntry;
use strict;
use warnings;
use utf8;

use base qw (Class::Data::Inheritable);

use Encode;
use Juman::Morpheme;
use Juman::Grammar qw/ $HINSI $BUNRUI $TYPE $FORM /;

use MorphemeUtilities;
use MorphemeGrammar qw/$IMIS $fusanaID2pos/;

our $enc = Encode::find_encoding('utf8');
JumanDictionary::MorphemeEntry->mk_classdata(NoValue => '__NOVALUE__');

# from juman.h
our $MIDASI_MAX = 129;
our $YOMI_MAX   = 129;
our $IMI_MAX    = 1024;

=head1 名前

JumanDictionary::MorphemeEntry - Juman の辞書の entry

=head1 用法

    use JumanDictionary::MorphemeEntry;

    # 直接作成
    my $me = JumanDictionary::MorphemeEntry->new ('動詞',  # hinsi
				 undef,   # bunrui
				 {
				     '読み' => 'なぐれる',
				     '見出し語' => {
					'なぐれる' => 1,
					'殴れる' => 1
				     },
				     '活用型' => '母音動詞',
				     '意味情報' => {
					 '可能動詞' => '殴る/なぐる',
					 '代表表記' => '殴れる/なぐれる'
					 }
				 });

    # S 式を出力
    print $me->serialize, "\n";


    # S 式から作成
    use SExpression;
    my $ds = SExpression->new ({ use_symbol_class => 1, fold_lists => 0 });
    my $se = $ds->read ('(動詞 ((読み あいす)(見出し語 愛す あいす)(活用型 子音動詞サ行)(意味情報 "代表表記:愛す/あいす")))');
    $me = JumanDictionary::MorphemeEntry->createFromSExpression ($se);

=head1 説明

Juman 辞書の S 式を扱う。ただし、

  (特殊
    (読点
      ((見出し語 ，) (読み ，))
      ((見出し語 、) (読み 、))
    )
  )

のように、一つの S 式で複数の項目を登録している場合には対応していない。

=head1 メソッド

=head2 new ($hinsi, $bunrui, $others)

オブジェクトを作成する。

引数

    $hinsi: 品詞
    $bunrui: 品詞細分類 (なければ undef)
    $others: 読み、見出し語、活用型、意味情報を格納した hashref

=cut
sub new {
    my ($this, $hinsi, $bunrui, $others) = @_;

    my $class = ref($this) || $this;
    my $self = {};
    bless($self, $class);

    $self->{'品詞'} = $hinsi;
    $self->{'品詞細分類'} = $bunrui if (defined($bunrui));
    map +(
	$self->{$_} = $others->{$_}, 1
	), keys(%$others);

    unless ($self->sanitize) {
	return undef;
    }
    return $self;
}

sub clone {
    my ($self) = @_;

    my $clone = {};
    bless($clone, ref($self));
    $clone->{'品詞'} = $self->{'品詞'};
    $clone->{'品詞細分類'} = $self->{'品詞細分類'} if (defined($self->{'品詞細分類'}));
    $clone->{'品詞型'} = $self->{'品詞型'} if (defined($self->{'品詞型'}));
    $clone->{'読み'} = $self->{'読み'};
    while ((my ($midasi, $cost) = each(%{$self->{'見出し語'}}))) {
	$clone->{'見出し語'}->{$midasi} = $cost;
    }
    if (defined($self->{'意味情報'})) {
	while ((my ($key, $val) = each(%{$self->{'意味情報'}}))) {
	    $clone->{'意味情報'}->{$key} = $val;
	}
    }
    return $clone;
}

# makeint が死なないように、妥当性をチェック
# makeint/trans.c に基づく
sub sanitize {
    my ($self) = @_;

    # 見出し語
    return 0 unless ($self->{'見出し語'});
    foreach my $midasi (keys(%{$self->{'見出し語'}})) {
	my $l = length($midasi);
	return 0 if ($l <= 0 || $l > $MIDASI_MAX);
	return 0 unless (&MorphemeUtilities::isEUCConvertible($midasi));
    }

    # 読み
    return 0 unless ($self->{'読み'});
    my $l = length($self->{'読み'});
    return 0 if ($l <= 0 || $l > $YOMI_MAX);
    return 0 unless (&MorphemeUtilities::isEUCConvertible($self->{'読み'}));

    # TODO
    # 活用形などのチェック

    # 意味情報
    if ($self->{'意味情報'}) {
	my $imis = '(意味情報 "';
	$imis .= join(" ", map {
	    ($self->{'意味情報'}->{$_} eq JumanDictionary::MorphemeEntry->NoValue)?
		$_ : "$_:" . $self->{'意味情報'}->{$_}
	} (keys(%{$self->{'意味情報'}})));
	$imis .= '")';
	return 0 if (length($imis) > $IMI_MAX);
    }

    return 1;
}

=head2 serialize

オブジェクトの S 式を返す

=cut
sub serialize {
    my ($self) = @_;

    if ($self->{'品詞'} eq '連語') {
	my $result = '(連語 (';
	$result .= join(' ', map { $_->serialize } (@{$self->{meList}}) );
	$result .= ')';
	if (defined($self->{cost})) {
	    $result .= ' ' . $self->{cost};
	}
	$result .= ')';
    } else {
	return $self->serializeSingle;
    }
}

sub serializeSingle {
    my ($self) = @_;

    my $result = "(" . $self->{'品詞'} . ' (';

    if (defined($self->{'品詞細分類'})) {
	$result .= $self->{'品詞細分類'} . ' (';
    }

    if ($self->{'読み'}) {
	$result .= '(読み ' . $self->{'読み'} . ')';
    } else {
	warn("no yomi provided\n");
    }
    if ($self->{'見出し語'}) {
	$result .= '(見出し語';
	foreach my $midasi (keys(%{$self->{'見出し語'}})) {
	    if ($self->{'見出し語'}->{$midasi} == 1) {
		$result .= " $midasi";
	    } else {
		$result .= " ($midasi " . $self->{'見出し語'}->{$midasi} .  ')';
	    }
	}
	$result .= ')';
    } else {
	warn("no midasi provided\n");
    }
    if ($self->{'活用型'}) {
	$result .= '(活用型 ' . $self->{'活用型'} . ')';
    }
    if ($self->{isPartOfRengo} && $self->{'活用形'}) {
	$result .= '(活用形 ' . $self->{'活用形'} .  ')'
    }
    if ($self->{'意味情報'}) {
	$result .= '(意味情報 "';
	$result .= join(" ", map {
	    ($self->{'意味情報'}->{$_} eq JumanDictionary::MorphemeEntry->NoValue)?
		$_ : "$_:" . $self->{'意味情報'}->{$_}
	} (keys(%{$self->{'意味情報'}})));
	$result .= '")';
    }
    if (defined($self->{'品詞細分類'})) {
	$result .= ')';
    }
    $result .= '))';
    return $result;
}

=head2 getJumanMorpheme([$midasi])

JumanDictionary::MorphemeEntry から Juman::Morpheme を作る
活用する場合には基本形を作る

見出し語が複数ある場合は、指定のもの

=cut
#
# TODO: 連語対応
#
sub getJumanMorpheme {
    my ($self, $midasi) = @_;

    unless ($midasi) {
	$midasi = (keys(%{$self->{'見出し語'}}))[0];
    }
    my $genkei = $midasi;
    my $yomi = $self->{'読み'};

    my $hinsi = $self->{'品詞'};
    my $hinsiEUC = $enc->encode($hinsi);
    my $hinsiID = $HINSI->[0]->{$hinsiEUC};

    my $bunrui = $self->{'品詞細分類'};
    my $bunruiID;
    if (defined ($bunrui)) {
	$bunruiID = $BUNRUI->{$hinsiEUC}->[0]->{$enc->encode($bunrui)};
    } else {
	$bunrui = '*';
	$bunruiID = 0;
    }

    my $katuyou1 = $self->{'活用型'};
    my ($katuyou1ID, $katuyou2, $katuyou2ID);
    if (defined ($katuyou1)) {
	my $katuyou1EUC = $enc->encode($katuyou1);
	$katuyou1ID = $TYPE->[0]->{$katuyou1EUC};
	$katuyou2 = '基本形';
	$katuyou2ID = $FORM->{$katuyou1EUC}->[0]->{$enc->encode($katuyou2)};
    } else {
	$katuyou1 = $katuyou2 = '*';
	$katuyou1ID = $katuyou2ID = 0;
    }

    my $imis = '"'
	. join(" ", map {
	($self->{'意味情報'}->{$_} eq JumanDictionary::MorphemeEntry->NoValue)?
	    $_ : "$_:" . $self->{'意味情報'}->{$_}
    } (keys(%{$self->{'意味情報'}})))
	. '"';

    my $spec = sprintf("%s %s %s %s %d %s %d %s %d %s %d %s\n",
		       $midasi,
		       $yomi,
		       $genkei,
		       $hinsi,
		       $hinsiID,
		       $bunrui,
		       $bunruiID,
		       $katuyou1,
		       $katuyou1ID,
		       $katuyou2,
		       $katuyou2ID,
		       $imis);
    return Juman::Morpheme->new($spec);
}


=head2 createFromSExpression($se)

Juman 辞書の S 式から Perl の構造体を生成する
戻り値は MorphemeEntry のリスト

引数

    $se: SExpression::Cons オブジェクト

例:
    入力
      (動詞 ((読み あいす)(見出し語 愛す あいす)(活用型 子音動詞サ行)(意味情報 "代表表記:愛す/あいす")))

    出力
      '品詞' => '動詞'
      '意味情報' => HASH(0x9ff5dec)
         '代表表記' => '愛す/あいす'
      '活用型' => '子音動詞サ行'
      '見出し語' => HASH(0x9ff5858)
         'あいす' => 1
         '愛す' => 1
      '読み' => 'あいす'

=cut
sub createFromSExpression {
    my $this = shift;
    my $class = ref($this) || $this;

    my $se = shift;

    my $pos = $se->car->name;
    my $t = $se->cdr;

    if ($pos eq '連語') {
	my $self = { '品詞' => '連語' };
	bless($self, $class);

	# 先に後ろのコストを処理
	if (ref($t->cdr) eq 'SExpression::Cons') {
	    $self->{cost} = $t->cdr->car;
	}

	$t = $t->car;
	my $meList = [];
	while (ref($t) eq 'SExpression::Cons') {
	    my $mspec = &createFromSExpression($class, $t->car);
	    my $me = $mspec->[0];
	    $me->{'isPartOfRengo'} = 1;
	    push(@$meList, $me);
	    $t = $t->cdr;
	}
	$self->{meList} = $meList;
	$self->setRengoMidasi;
	return [$self];
    } else {
	# 共有される
	my $POSStruct = {
	    '品詞' => $pos
	};
	if (ref($t->car->car) eq 'SExpression::Symbol') {
	    $t = $t->car;
	    $POSStruct->{'品詞細分類'} = $t->car->name;
	    $t = $t->cdr;
	}

	# 指示詞などは、一つの S 式で複数の形態素を記述している
	my $meList = [];
	while (ref($t) eq 'SExpression::Cons') {
	    my $me = &processMorphemeSpec($class, $POSStruct, $t->car);
	    push(@$meList, $me);
	    $t = $t->cdr;
	}
	return $meList;
    }
}

# <形態素情報> の処理
sub processMorphemeSpec {
    my ($class, $POSStruct, $t) = @_;

    my $self = { '品詞' => $POSStruct->{'品詞'} };
    if (defined($POSStruct->{'品詞細分類'})) {
	$self->{'品詞細分類'} = $POSStruct->{'品詞細分類'};
    }
    bless($self, $class);

    while (ref($t) eq 'SExpression::Cons') {
	my $n = $t->car->car->name;
	if ($n eq '見出し語') {
	    $self->{$n} = {};
	    my $tin = $t->car->cdr;
	    while (ref($tin) eq 'SExpression::Cons') {
		if (ref($tin->car) eq 'SExpression::Cons') {
		    $self->{$n}->{$tin->car->car->name} = $tin->car->cdr->car; # コストが数字で与えられる
		} else {
		    $self->{$n}->{$tin->car->name} = 1;
		}
		$tin = $tin->cdr;
	    }
	} elsif ($n eq '意味情報') {
	    my @list = split(/\s/, $t->car->cdr->car); # シンボルではなく文字列
	    $self->{$n} = {};
	    foreach my $str (@list) {
		# 複数の : で区切られている場合は、最初の : で key, value に分割
		#  e.g. 自他動詞:自:渡る/わたる, 人名:日本:姓:3:0.00774
		my ($key, $value, $pos);
		if (($pos = index($str, ':')) > 0) {
		    $key = substr($str, 0, $pos);
		    $value = substr($str, $pos + 1);
		} else {
		    $key = $str;
		    $value = JumanDictionary::MorphemeEntry->NoValue;;
		}
		$self->{$n}->{$key} = $value;
	    }
	} else {
	    $self->{$n} = $t->car->cdr->car->name;
	}
	$t = $t->cdr;
    }
    return $self;
}

# 連語に疑似的な見出し語を設定
sub setRengoMidasi {
    my ($self) = @_;

    # 組み合わせの要素
    my $midasiListList = [];
    foreach my $me (@{$self->{meList}}) {
	my $midasiList = [];

	if (defined($me->{'活用形'}) && $me->{'活用形'} ne '*') {
	    foreach my $midasi (keys(%{$me->{'見出し語'}})) {
		my $inflected = &MorphemeUtilities::getInflectedForm
		    ($midasi, $me->{'活用型'}, '基本形', $me->{'活用形'});
		push(@$midasiList, $inflected);
	    }	    
	} else {
	    foreach my $midasi (keys(%{$me->{'見出し語'}})) {
		push(@$midasiList, $midasi);
	    }
	}
	push(@$midasiListList, $midasiList);
    }

    # 組み合わせの合成
    my $combMidasi = [''];
    foreach my $midasiList (@$midasiListList) {
	my $combMidasiTmp = [];
	foreach my $midasi (@$midasiList) {
	    foreach my $old (@$combMidasi) {
		push(@$combMidasiTmp, $old . $midasi);
	    }
	}
	$combMidasi = $combMidasiTmp;
    }

    my $struct = {};
    foreach my $midasi (@$combMidasi) {
	$struct->{$midasi} = -1; # 疑似的な生起コスト
    }
    $self->{'見出し語'} = $struct;
}

sub updateFusana {
    my ($self, $id) = @_;

    my $pos = $fusanaID2pos->[$id];
    my $rv = {
	pos => $pos,
    };
    if ($id == 0 || $id == 1) {  # TODO: fix hard-coding
	$self->{'品詞'} = '名詞';
	$self->{'品詞細分類'} = $pos;
	if (defined($self->{'活用型'})) {
	    delete($self->{'活用型'});
	    # remove trailing 'だ'
	    $self->{'読み'} = substr($self->{'読み'}, 0, length ($self->{'読み'}) - 1);
	    my $tmp = {};
	    foreach my $midasi (keys(%{$self->{'見出し語'}})) {
		my $midasiNew = substr($midasi, 0, length($midasi) - 1);
		push(@{$rv->{midasiChange}}, [$midasi, $midasiNew]);
		$tmp->{$midasiNew} = $self->{'見出し語'}->{$midasi};
	    }
	    $self->{'見出し語'} = $tmp;
	}
    } else {
	$self->{'品詞'} = '形容詞';
	$self->{'活用型'} = $pos;
	if (defined($self->{'品詞細分類'})) {
	    delete($self->{'品詞細分類'});
	    # append trailing 'だ'
	    $self->{'読み'} .= 'だ';
	    my $tmp = {};
	    foreach my $midasi (keys(%{$self->{'見出し語'}})) {
		my $midasiNew = $midasi . 'だ';
		push(@{$rv->{midasiChange}}, [$midasi, $midasiNew]);
		$tmp->{$midasiNew} = $self->{'見出し語'}->{$midasi};
	    }
	    $self->{'見出し語'} = $tmp;
	}
    }
    delete($self->{'意味情報'}->{$IMIS->{FUSANA}});
    return $rv;
}

1;
