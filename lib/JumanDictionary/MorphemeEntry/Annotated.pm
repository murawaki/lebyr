package JumanDictionary::MorphemeEntry::Annotated;
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use base qw/JumanDictionary::MorphemeEntry/;

use IO::Scalar;
use IO::File;
use Data::Dumper;

use SExpression;
use JumanDictionary;
use MorphemeUtilities;
use MorphemeGrammar qw /$posList $IMIS/;

=head1 名前

JumanDictionary::MorphemeEntry::Annotated - 形態素にさまざまな注釈を付与する

=head1 用法

    use JumanDictionary::MorphemeEntry::Annotated;

    my $data = <<'__EOF__';
    ; stem: 痒
    ; count: 80046
    ; countStart: 12
    ; countMerged: 5505
    (形容詞 ((読み 痒い)(見出し語 痒い)(活用型 イ形容詞イ段)(意味情報 "自動獲得")))
    ; stem: 謁
    ; count: 241
    ; countStart: 4
    ; countMerged: 0
    (動詞 ((読み 謁す)(見出し語 謁す)(活用型 子音動詞サ行)(意味情報 "自動獲得")))
    __EOF__
    my $list = JumanDictionary::MorphemeEntry::Annotated->readAnnotatedDictionaryData($data);

    # 注釈を読む
    $list->[0]->getAnnotation('count')

    # S 式を出力
    print $me->serialize, "\n";

=head1 説明

Juman 辞書の形態素に注釈を付与する。
注釈の形式は、S式の前のコメントとする

=head1 メソッド

=head2 serialize()

オブジェクトの S 式を返す

=cut
sub serialize {
    my ($self) = @_;

    my $rv = '';
    if (defined($self->{annotation})) {
	while ((my ($key, $value) = each(%{$self->{annotation}}))) {
	    if (ref(\$value) eq 'SCALAR') {
		$rv .= "; $key: $value\n";
	    } else {
		# 複雑な構造体を扱う
		# Data::Dumper は UTF-8 の文字列をエスケープするので見栄えは良くない
		my $d = Data::Dumper->new([$value]);
		$d->Terse(1);  # 無理矢理1行にする
		$d->Indent(0);
		$rv .= sprintf("; %s: #%s\n", $key, $d->Dump);
	    }
	}
    }

    $rv .= $self->SUPER::serialize();
    return $rv;
}

=head2 getAnnotationCollection()

注釈一覧を得る。

=cut
sub getAnnotationCollection {
    return ($_[0])->{annotation};
}

=head2 getAnnotation ($key)

注釈を得る。

=cut
sub getAnnotation {
    my ($self, $type, $default) = @_;
    return (defined($self->{annotation}->{$type}))? $self->{annotation}->{$type} :
	(defined($default))? ($self->{annotation}->{$type} = $default) : undef;
}

=head2 setAnnotation ($key, $value)

注釈を付加する

=cut
sub setAnnotation {
    my ($self, $key, $value) = @_;

    $self->{annotation}->{$key} = $value;
}
=head2 deleteAnnotation ($key)

注釈を削除する

=cut
sub deleteAnnotation {
    my ($self, $key) = @_;

    delete($self->{annotation}->{$key});
}

=head2 readAnnotatedDictionary ($file)

オブジェクトを作成する。

引数

    $file: ファイル名 (UTF-8)

=cut
sub readAnnotatedDictionary {
    my ($this, $file) = @_;

    my $class = ref($this) || $this;

    my $f = IO::File->new($file) or die;
    $f->binmode(':utf8');
    if (JumanDictionary->isDummyDictionary($f)) {
	$f->close;
	return;
    }

    my $rv = &_readFromFileHandle($class, $f);
    $f->close;
    return $rv;
}

=head2 readAnnotatedDictionaryData ($data)

オブジェクトを作成する。

引数

    $data: 文字列

=cut
sub readAnnotatedDictionaryData {
    my ($this, $data) = @_;

    my $class = ref($this) || $this;

    my $f = IO::Scalar->new(\$data);
    my $rv = &_readFromFileHandle($class, $f);
    $f->close;
    return $rv;
}

sub _readFromFileHandle {
    my ($class, $f) = @_;

    my $annotation = {};
    my $rv = [];
    my $ds = SExpression->new({ use_symbol_class => 1, fold_lists => 0 });
    while ((my $line = $f->getline)) {
	chomp($line);
	if ($line =~ /^\;/) { # comment
	    if ($line =~ /^\; (.*)/) { # annotation?
		my $comment = $1;
		if ($comment =~ /^([A-Za-z0-9\-]+):\s+(.*)$/) {
		    my ($key, $value) = ($1, $2); # $value は空でもよい
		    # print ("value: $value\n");
		    if ($value =~ /^\#(.+)/) { # Data::Dumper 形式
			$annotation->{$key} = eval($1);
		    } else {
			$annotation->{$key} = $value;
		    }
		} else {
		    warn("malformed input: $_\n");
		}
	    }
	} else {
	    my $se = $ds->read($line);
	    my $mspec = $class->createFromSExpression($se);
	    my $me = $mspec->[0]; # 複数形態素の記述はやらない
	    $me->{annotation} = $annotation;
	    push(@$rv, $me);
	    $annotation = {};
	}
    }
    return $rv;
}


############################################################
#                                                          #
#                      statis methods                      #
#                                                          #
############################################################

#
# ただの構造体から MorphemeEntry を作る
#
sub makeAnnotatedMorphemeEntryFromStruct {
    my ($entry) = @_;

    my $posS = $entry->{posS};
    my $stem = $entry->{stem};

    if ($entry->{defaultAdverb}) {
	$posS = '副詞';
    }

    my $constraints = $posList->{$posS}->{constraints};
    my $katuyou1; # $posList に記述されていないこともある
    if (defined($constraints->{katuyou1})) {
	($katuyou1) = sort { $constraints->{katuyou1}->{$a} <=> $constraints->{katuyou1}->{$b} }
	    (keys(%{$constraints->{katuyou1}}));
    }
    my ($hinsi) = sort { $constraints->{hinsi}->{$a} <=> $constraints->{hinsi}->{$b} }
        (keys(%{$constraints->{hinsi}}));
    my $bunrui;
    if (defined($constraints->{bunrui})) {
	($bunrui) = sort { $constraints->{bunrui}->{$a} <=> $constraints->{bunrui}->{$b} }
	    (keys(%{$constraints->{bunrui}}));
    }

    my $midasi;
    if (defined($katuyou1)) {
	$midasi = &MorphemeUtilities::getMidasiFromStem($stem, $katuyou1);
    } else {
	$midasi = $stem;
    }
    my $yomi = &MorphemeUtilities::makeYomiFromMidasi($midasi);
    my $repname = &MorphemeUtilities::makeRepnameFromMidasi($midasi);

    my $struct = {
	'読み' => $yomi,
	'見出し語' => { $midasi => 1 },
	'意味情報' => { '自動獲得' => 'テキスト', '代表表記' => $repname }
    };
    if (defined($katuyou1)) {
	$struct->{'活用型'} = $katuyou1;
    }
    my $me = JumanDictionary::MorphemeEntry::Annotated->new($hinsi, $bunrui, $struct);

    # 作成に失敗
    unless (defined($me)) {
	return undef;
    }

    # 継続監視が必要
    if ($posList->{$posS}->{fusana}) {
	$me->{'意味情報'}->{$IMIS->{FUSANA}} = JumanDictionary::MorphemeEntry->NoValue;
	$me->setAnnotation('monitor', {});
    }
    # 継続監視が必要
    if ($posList->{$posS}->{maybeAdverb}) {
	$me->{'意味情報'}->{$IMIS->{MAYBE_ADVERB}} = JumanDictionary::MorphemeEntry->NoValue;
	# $me->setAnnotation('monitor', {});
    }
    return $me;
}

1;
