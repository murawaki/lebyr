package Ngram;
#
# Ngram 操作の基本ライブラリ
#
# 用語の説明
#   word: 原形-代表表記-クラス の三組
#   id: これらを数値に変換したもの
#   key: バイナリ化したもの (これでハッシュを引く)
#
use strict;
use utf8;

our $allGenkei = 0; # すべての原形を保持するか (カウント時に使用)
our $repnameList;

our $midasi2id;
our $id2midasi;
our $repname2id;
our $id2repname;
our $class2id;
our $id2class;

our $abstractClassTable; # 具体クラスから抽象クラスへの変換

# 形態素の意味情報に付与されている末尾成分のリスト
our $entityTagList = {
    '人名' => '<SUF_PERSON>',
    '地名' => '<SUF_LOCATION>',
    '住所' => '<SUF_ADDRESS>',
    '組織名' => '<SUF_ORGANIZATION>'
};

# 文法的な自立語
our $bareHinsi = {
    '指示詞' => 1,
    '接続詞' => 2
};

# 0 はさらに分類する
# ここにないものは見出し語を返す
our $commonHinsi = {
    '名詞' => 0,
    '動詞' => 0,
    '形容詞' => 0,
    '副詞' => 0,
#    '連体詞' => '連体詞',
#    '特殊' => 'SPECIAL'
};
our $abstractBunrui = {
    '数詞' =>     '<NUMBER>',
    '人名' =>     '<PERSON>',
    '地名' =>     '<LOCATION>',
    '組織名' =>   '<ORGANIZATION>',
    '固有名詞' => '<PROPER>'
};

sub setGenkeiMode {
    $allGenkei = $_[0];
}

sub initRepnameList {
    $repnameList = $_[0];
}

# 初期化
# $abstractClassTable はいじらない
sub initTable {
    &setTable ({
	'midasi2id' => { '' => 0, '$' => 1, '#' => 2, '|' => 3 },
	'id2midasi' => ['', '$', '#', '|'],
	'repname2id' => { '' => 0 },
	'id2repname' => [''],
	'class2id' => { '' => 0 },
	'id2class' => ['']
	});
}

# 特殊な値
sub nullWord { return ''; }
sub nullID { return [0, 0, 0]; }
sub bosWord { return '$'; }
sub bosID { return [1, 0, 0]; }
sub specialWord { return '#'; }
sub specialID { return [2, 0, 0]; }
sub boundaryWord { return '|'; }
sub boundaryID { return [3, 0, 0]; }

# 抽象化クラスの初期化
sub initAbstractClasses {
    my @abstractClassList = ('<動詞>', '<イ形容詞>', 'ナ形容詞');
    foreach my $class (@abstractClassList) {
	unless (defined ($class2id->{$class})) {
	    $class2id->{$class} = scalar (@$id2class);
	    push (@$id2class, $class);
	}
    }
    while ((my $class = each (%$class2id))) {
	if ($class =~ /^\<(動詞|イ形容詞|ナ形容詞)\:/) {	
	    $abstractClassTable->{$class2id->{$class}} = $class2id->{"<$1>"};
	}
    }
}

# ID table を設定
sub setTable {
    my ($table) = @_;

    $midasi2id = $table->{'midasi2id'};
    $id2midasi = $table->{'id2midasi'};
    $repname2id = $table->{'repname2id'};
    $id2repname = $table->{'id2repname'};
    $class2id = $table->{'class2id'};
    $id2class = $table->{'id2class'};

    if (defined ($table->{'abstractClassTable'})) {
	$abstractClassTable = $table->{'abstractClassTable'};
    }
}

# ID table を get
sub getTable {
    my $rv = {
	'midasi2id' => $midasi2id,
	'id2midasi' => $id2midasi,
	'repname2id' => $repname2id,
	'id2repname' => $id2repname,
	'class2id' => $class2id,
	'id2class' => $id2class
    };
    if (defined ($abstractClassTable)) {
	$rv->{'abstractClassTable'} = $abstractClassTable;
    }
    return $rv;
}

# 別 ID table を merge
# id の mapping を返す
sub convertTable {
    my ($table) = @_;

    my $typeList = ['midasi', 'repname', 'class'];
    my $ct = {};

    foreach my $type (@$typeList) {
	my $f1 = eval ("\$${type}2id");
	my $b1 = eval ("\$id2${type}");

	my $f2 = $table->{"${type}2id"};

	my $conv;
	$ct->{$type} = $conv = [];

	while ((my $key = each (%$f2))) {
	    my $id2 = $f2->{$key};
	    my $id1;
	    unless (defined ($id1 = $f1->{$key})) {
		$id1 = $f1->{$key} = scalar (@$b1);
		push (@$b1, $key);
	    }
	    $conv->[$id2] = $id1;
	}
    }
    return $ct;
}

# n-gram の word
# 見出し語-代表表記-クラス
sub getWord {
    my ($mrph, $opt) = @_;

    return '#' if ($mrph->hinsi eq '特殊');

    # $opt で同形が fstring を持っていないことに対処
    if ($mrph->fstring =~ /\<自立\>/ ||
	(defined ($opt) && $opt->{isJiritu}) ) {
	my $repname = $mrph->repname;
	if ($allGenkei || defined ($repnameList->{$repname})) {
	    return $mrph->genkei . '-' . $repname . '-' . &getClass ($mrph);
	} else {
	    return '-' . $repname . '-' . &getClass ($mrph);
	}
    } else {
	return $mrph->midasi;
    }
}

# class: 汎化した単位
sub getClass {
    my ($mrph) = @_;

    my $hinsi = $mrph->hinsi;
    return undef if ($bareHinsi->{$hinsi});

    return '<' . $mrph->hinsi . '>' unless (defined ($commonHinsi->{$hinsi}));

    if ($hinsi eq '形容詞') {
	return (($mrph->katuyou1 =~ /^イ形容詞/)? '<イ形容詞:' : '<ナ形容詞:') . $mrph->katuyou2 . '>';
    }
    if ($hinsi eq '動詞') {
	return '<動詞:' . $mrph->katuyou2 . '>';
    }
    if ($hinsi eq '副詞') {
	return '<副詞>';
    }

    if ($mrph->imis =~ /(\w+)末尾(外)?[\s\"]/) {
	# 「首相」など、一部の末尾要素
	my $entityTag = $1;
	if ($entityTagList->{$entityTag}) {
	    return $entityTagList->{$entityTag}
	}
    }

    # ここからは 名詞
    my $class;
    if (($class = $abstractBunrui->{$mrph->bunrui})) {
	my $imis = $mrph->imis;
	if ($class eq '<PERSON>') {
	    if ($imis =~ /人名\:日本\:姓/) {
		return '<PERSON:JAPANESE:FIRST>';
	    } elsif ($imis =~ /人名\:日本\:名/) {
		return '<PERSON:JAPANESE:GIVEN>';
	    } elsif ($imis =~ /人名\:外国/) {
		return '<PERSON:FOREIGN>';
	    } else {
		# printf STDERR ("PERSON\t%s\n", $mrph->midasi);
		return $class;
	    }
# 	} elsif ($class eq '<LOCATION>') {
# 	    if ($imis =~ /地名\:([^\s]+)/) {
# 		return sprintf ("<LOCATION:%s>", $1);
# 	    } else {
# 		printf STDERR ("LOCATION\t%s\n", $mrph->midasi);
# 		return $class;
# 	    }
	} else {
	    return $class;
	}
    } else {
	return '<' . $mrph->bunrui . '>';
    }
    return '<' . $mrph->bunrui . '>';
}

# クラスの活用型の違いを吸収
sub abstractClass {
    my ($class) = @_;
    if ($class =~ /^\<(動詞|イ形容詞|ナ形容詞)\:/) {
	return "<$1>";
    } else {
	return $class;
    }
}

# word を ID 列に変換
# この時点ではバイナリではない
sub word2id {
    my ($midasi, $repname, $class) = (scalar (@_) == 3)? @_ : split (/\-/, $_[0]);

    my ($id1, $id2, $id3) = (0, 0, 0);
    if (defined ($midasi)) {
	unless (defined ($id1 = $midasi2id->{$midasi})) {
	    $id1 = $midasi2id->{$midasi} = scalar (@$id2midasi);
	    push (@$id2midasi, $midasi);
	}
    }
    if (defined ($repname)) {
	unless (defined ($id2 = $repname2id->{$repname})) {
	    $id2 = $repname2id->{$repname} = scalar (@$id2repname);
	    push (@$id2repname, $repname);
	}
    }
    if (defined ($class)) {
	unless (defined ($id3 = $class2id->{$class})) {
	    $id3 = $class2id->{$class} = scalar (@$id2class);
	    push (@$id2class, $class);
	}
    }
    return [$id1, $id2, $id3];
}

# ID 列を word に変換
sub id2word {
    my ($id1, $id2, $id3) = @{$_[0]};
    my $midasi = $id2midasi->[$id1];
    my $repname = $id2repname->[$id2];
    my $class = $id2class->[$id3];

    if (!$id2 && !$id3) {
	return $midasi;
    } else {
	return "$midasi-$repname-$class";
    }
}

# クラスを抽象化した ID を返す
# key の見出しをぬく
sub getAbstractClassID {
    my ($id) = @_;
    my $tmp;
    if ($id->[2] > 0 && ($tmp = $abstractClassTable->{$id->[2]})) {
	return [$id->[0], $id->[1], $tmp];
    } else {
	return $id;
    }
}

# key の見出しをぬく
sub getRepnameID {
    my ($id) = @_;
    if ($id->[0] > 0 && $id->[1] > 0) {
	return [0, $id->[1], $id->[2]];
    } else {
	return $id;
    }
}

# key の代表表記をぬく
sub getMidasiID {
    my ($id) = @_;
    if ($id->[0] > 0 && $id->[1] > 0) {
	return [$id->[0], 0, $id->[2]];
    } else {
	return $id;
    }
}

# id の見出しだけを変更
sub replaceMidasi {
    my ($id, $midasi) = @_;
    my $id0;
    unless (defined ($id0 = $midasi2id->{$midasi})) {
	$id0 = $midasi2id->{$midasi} = scalar (@$id2midasi);
	push (@$id2midasi, $midasi);
    }
    return [$id0, $id->[1], $id->[2]];
}

# id のリストをうけて、pack
sub compressID {
    my @list = ();
    foreach my $id (@_) {
	push (@list, @$id);
    }
    return pack ('(LLS)' . scalar (@_), @list);
}

# id のハッシュを解凍
# 解凍には長さが必要
sub uncompressID {
    my ($key, $l) = @_;
    my @list = unpack ("(LLS)$l", $key);
    my @idList;
    for (my $i = 0; $i < $l; $i++) {
	push (@idList, [$list[$i*3], $list[$i*3+1], $list[$i*3+2]]);
    }
    return wantarray ? @idList : $idList[0];
}

1;
