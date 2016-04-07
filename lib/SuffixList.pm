package SuffixList;

use strict;
use warnings;
use utf8;

use Encode qw /encode_utf8 decode_utf8/;
use Storable qw /retrieve/;

use Text::Trie::Tx;

=head1 名前

SuffixList - サフィックス関係のデータを管理

=head1 用法

  use SuffixList;
  my $suffixList = SuffixList->new("/home/murawaki/research/lebyr/data");

=head1 説明

サフィックス関係のデータを管理する。
サフィックスの一覧は tx で管理。
サフィックスから品詞と活用形のペアの組へのマッピングは Storable で管理。

=head1 メソッド

=head2 new (...)

指定されたファイルから読み込む

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $inputDir = shift;
    my $self = {
	opt => shift
    };

    die unless ( -d $inputDir );

    # default settings
    $self->{opt}->{debug} = 0  unless (defined($self->{opt}->{debug}));

    bless($self, $class);

    my $idxFile = "$inputDir/suffix.tx";
    my $dbFile = "$inputDir/suffix.storable";
    $self->{tx} = Text::Trie::Tx->open($idxFile) or die;
    $self->{db} = retrieve($dbFile) or die;
    return $self;
}

sub DESTROY{
    my ($self) = @_;
    delete($self->{tx});
}

sub getTotal {
    my ($self) = @_;
    return $self->{tx}->getKeyNum;
}

# commonPrefixSearch を行なって、マッチしたサフィックスの ID のリストを返す
# サフィックスは短いものから順にならんでいる
sub commonPrefixSearchID {
    my ($self, $str) = @_;
    return $self->{tx}->commonPrefixSearchID(encode_utf8($str));
}

# ID からサフィックスに変換
sub getSuffixByID {
    my ($self, $id) = @_;
    return decode_utf8($self->{tx}->reverseLookup($id));
}

sub getSuffixLengthByID {
    my ($self, $id) = @_;

    my $fp = $self->{db}->{id2fp}->[$self->{db}->{idList}->[$id]];
    my @list = unpack("S*", $fp);
    return $list[0]; # 0番がサフィックスの長さ
}

# サフィックスに対応する品詞と活用形のペアのリストを返す
sub getSuffixContentByID {
    my ($self, $id) = @_;

    my $fp = $self->{db}->{id2fp}->[$self->{db}->{idList}->[$id]];
    my @list = unpack("S*", $fp);
    shift (@list); # 0番がサフィックスの長さ
    my $rv = [];
    while (scalar(@list) > 0) {
	my $posSid = shift(@list);
	my $katuyou2id = shift(@list);
	push(@$rv, [$self->{db}->{id2posS}->[$posSid], $self->{db}->{id2katuyou2}->[$katuyou2id]]);
    }
    return $rv;
}

sub getIDBySuffix {
    my ($self, $suffix) = @_;

    my $idList = $self->commonPrefixSearchID($suffix);
    return undef if (scalar(@$idList) <= 0);
    my $id = $idList->[-1];
    my $suffixLength = $self->getSuffixLengthByID($id);
    return ($suffixLength == length($suffix))? $id : undef;
}

1;
