package JumanDictionary::Static;

use strict;
use warnings;
use utf8;
use base qw/JumanDictionary/;

use Encode qw/encode_utf8 decode_utf8/;
use POSIX qw/SEEK_SET/;
use IO::File;
use CDB_File;
use Storable qw/nfreeze thaw/;
use bytes qw//; # nothing imported

use Egnee::Logger;

# ディレクトリに置くファイル名
our $midasiDicFile = 'midasiDic.cdb';
our $contentDBFile = 'contentDB';

=head1 名前

JumanDictionary::Static - 書き込み不可の静的な辞書

=head1 用法

  use JumanDictionary::Static;
  my $mainDictionary =
    JumanDictionary::Static->makeDB ('/home/murawaki/research/lebyr/data', # データを置くディレクトリ
                                   '/home/murawaki/download/juman/dic'); # 辞書のディレクトリ

=head1 説明

JUMAN の辞書を静的に保存する。
メモリの使い方が控え目になると期待される。

getMorpheme するたびに S式から JumanDictionary::MorphemeEntry を作る
getAllMorphemes は明らかに効率が悪い

データ構造:
midasiDB.cdb
    見出し語 -> 対応する辞書項目の contentDB 内での位置
    pos len pos len ... を pack したもの
    pos は contentDB における offset
    len は長さ (byte)
contentDB
    辞書項目を Storable で順番に直列化したもの

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $dir = shift;
    my $self = {
	midasiDBFile => "$dir/$midasiDicFile",
	contentDBFile => "$dir/$contentDBFile",
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    unless ($self->init) {
	$self->close;
	return undef;
    }
    return $self;
}

sub init {
    my ($self) = @_;

    die(sprintf("%s not found\n", $self->{midasiDBFile}))
	unless ( -f $self->{midasiDBFile} );
    die(sprintf("%s not found\n", $self->{contentDBFile}))
	unless ( -f $self->{contentDBFile} );

    my $cdb = tie(my %h, 'CDB_File', $self->{midasiDBFile});

    die("tie failed: $!\n") unless ($cdb);

    $self->{cdb} = $cdb;
    $self->{midasiDB} = \%h;

    my $file = IO::File->new;
    $file->open($self->{contentDBFile}, "<:bytes") or die("open failed: $!\n");
    $self->{contentDB} = $file;
}

sub DESTROY {
    my ($self) = @_;
    $self->close;
}

sub close {
    my ($self) = @_;

    if (defined($self->{cdb})) {
	delete($self->{cdb});
	untie(%{$self->{midasiDB}});
	delete($self->{midasiDB});
    }
    if (defined($self->{contentDB})) {
	close($self->{contentDB});
	delete($self->{contentDB});
    }
}

=head2 getMorpheme ($midasi, $constraints)

登録済みの形態素を引く。存在すればリストで返す。なければ undef。

引数
  $midasi: 見出し語
  $constraints (optional): 見出し語以外の制約

=cut
sub getMorpheme {
    my ($self, $midasi, $constraints) = @_;

    my $mes = $self->{midasiDB}->{$midasi};
    return undef unless (defined($mes));

    my $meList = [];
    my @tmp = unpack("(LS)*", $mes);
    while (1) {
	my $pos = shift(@tmp); last unless (defined($pos));
	my $len = shift(@tmp);
	$self->{contentDB}->seek($pos, SEEK_SET);

	$self->{contentDB}->read(my $buf, $len);
	my $me = thaw($buf);
	if (defined($me)) {
	    push(@$meList, $me);
	}
    }
    return $meList unless (defined($constraints));
    my $filtered = $self->checkConstraints($meList, $constraints);
    return undef if (scalar(@$filtered) < 0);
    return $filtered;
}

sub getAllMorphemes {
    my ($self) = @_;

    my $midasiDB = $self->{midasiDB};
    my $contentDB = $self->{contentDB};

    # 一意な形態素のリストを作る
    # 効率が悪い
    my $midasiPerPos = {};
    while ((my ($midasi, $val) = each(%$midasiDB))) {
	my @tmp = unpack("(LS)*", $val);
	while (1) {
	    my $pos = shift(@tmp); last unless (defined($pos));
	    my $len = shift(@tmp);
	    $midasiPerPos->{$pos} = $len;
	}
    }
    my @sorted = sort { $a <=> $b } (keys(%$midasiPerPos));

    my @mrphList;
    $contentDB->seek(0, SEEK_SET);
    foreach my $pos (@sorted) {
	my $len = $midasiPerPos->{$pos};
	$contentDB->read(my $serialized, $len);
	my $me = thaw($serialized);
	push(@mrphList, $me);
    }
    return \@mrphList;
}



############################################################
#        The method for constructing the dictionary        #
############################################################
sub makeDB {
    my ($this, $saveDirPath, $dicDirPath, $opt) = @_;

    die("invalid argument\n")
	unless ( -d $saveDirPath && -d $dicDirPath );

    my $class = ref($this) || $this;
    my $self = {};
    bless($self, $class);

    $self->loadDictionary($dicDirPath);

    my $midasiDB = {};
    my $contentFile = IO::File->new;
    $contentFile->open("$saveDirPath/$contentDBFile", ">:bytes") or die;

    my $meList = $self->SUPER::getAllMorphemes;
    foreach my $me (@$meList) {
	# 連語は無視する
	# TODO: 見直し
	next if ($me->{'品詞'} eq '連語');

	my $pos = $contentFile->tell;
	my $serialized = nfreeze($me);
	my $len = bytes::length($serialized);
	$contentFile->print($serialized);

	foreach my $midasi (keys(%{$me->{'見出し語'}})) {
	    push(@{$midasiDB->{$midasi}}, $pos, $len);
	}
    }
    $contentFile->close;

    my $t = CDB_File->new("$saveDirPath/$midasiDicFile", "$saveDirPath/$midasiDicFile.$$") or die;
    while ((my $midasi = each(%$midasiDB))) {
	my $val = pack("(LS)*", @{$midasiDB->{$midasi}});
	$t->insert(encode_utf8($midasi), $val);
    }
    $t->finish;
}


############################################################
#               This dictionary is read-only               #
############################################################
sub addMorpheme {
    return ($_[0])->errorStatic;
}
sub removeMorpheme {
    return ($_[0])->errorStatic;
}
sub clear {
    return ($_[0])->errorStatic;
}
sub saveAsDictionary {
    return ($_[0])->errorStatic;
}
sub update {
    return ($_[0])->errorStatic;
}
sub errorStatic {
    Egnee::Logger::warn("dictionary not writable\n");
}

1;
