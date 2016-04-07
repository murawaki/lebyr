package StringTrie;
use strict;
use utf8;

use Scalar::Util qw (refaddr);

=head1 名前

Trie - トライ

=head1 用法

  use StringTrie;
  my $trie = new StringTrie;

=head1 説明

用例のトライ。
hash を使った効率の悪い実装。

=head1 メソッド

=head2 new ()

初期化

=cut
sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	opt => shift,
	root => {},
	'id2nodes' => {}
    };
    $self->{opt}->{debug} = 0 unless (defined $self->{opt}->{debug});

    bless ($self, $class);
    return $self;
}

=head2 root

ルートを返す

=cut
sub root {
    return ($_[0]->{root});
}


=head2 add ($key, $val)

該当キーによって $val を追加すると同時に、
substring とするキーと用例リストのペアのリストを返す
$val がなければ追加はしない
返すリストには自身は含まれていないので注意が必要。

=cut
sub add {
    my ($self, $key, $val) = @_;

    my $list = []; # return value
    my $node = $self->root;
    my @charList = split (//, $key);

    # 一応 root も調べる
    my $k = '';
    my $list2 = $self->getLeavesByNode ($node);
    if (scalar (@$list) > 0) { # assert
	$self->warn ("root node has leaves.\n");
	push (@$list, [$k, $list2]);
    }

    for (my $i = 0; $i < scalar (@charList); $i++) {
	my $c = $charList[$i];
	$k .= $c;
	if (defined ($node->{$c})) {
	    my $list2 = $self->getLeavesByNode ($node->{$c});
	    if (scalar (@$list2) > 0) {
		push (@$list, [$k, $list2]);
	    }
	} else {
	    $node->{$c} = {};
	}
	$node = $node->{$c};
    }
    if (defined ($val)) { # $val がなければ追加しない
	my $id = refaddr ($val);
	push (@{$node->{LEAF}}, $val);
	push (@{$self->{id2nodes}->{$id}}, $node);
	# $list に自身を追加しない
    }
    &_getDescendantKEPairList ($node, $k, $list, 0);

    return $list;
}

=head2 getLeaves ($key)

該当ノードにある用例のリストを返す

=cut
sub getLeaves {
    my ($self, $key) = @_;

    my $node = $self->getNode ($key);
    return undef unless (defined ($node));

    return $self->getLeavesByNode ($node);
}

=head2 getNode ($key)

該当キーでルートからたどったノードを返す

=cut
sub getNode {
    my ($self, $key) = @_;

    my @charList = split (//, $key);
    my $node = $self->{root};
    for (my $i = 0; $i < scalar (@charList); $i++) {
	my $char = $charList[$i];
	unless (defined ($node->{$char})) {
	    return undef;
	}
	$node = $node->{$char};
    }
    return $node;
}

=head2 getLeavesByNode ($node)

該当ノードにある用例のリストを返す

=cut
sub getLeavesByNode {
    my ($self, $node) = @_;

    # my $list = [];
    if (defined ($node->{LEAF})) {
	# LEAF の中身をそのまま返す
	# clone した方が良いかもしれない
	return $node->{LEAF};
    } else {
	return [];
    }
}

# 子孫ノードの「キーと用例リストのペア」を $list に追加していく
# $flag は自分自身の子供を追加するか
sub _getDescendantKEPairList {
    my ($node, $k, $list, $flag) = @_;

    if ($flag && defined ($node->{LEAF})) {
	my $list2 = [];
	foreach my $val (@{$node->{LEAF}}) {
	    push (@$list2, $val);
	}
	push (@$list, [$k, $list2]);
    }
    foreach my $edge (keys (%$node)) {
	next if ($edge =~ /[A-Z]+/);
	&_getDescendantKEPairList ($node->{$edge}, $k . $edge, $list, 1);
    }
}


=head2 getDescendants ($node)

あるノードより深くにある用例のリストを返す。
複数のノードに登録されている同じ値は一つ。

=cut
sub getDescendants {
    my ($self, $node) = @_;
    $node = $self->{root} unless (defined ($node));
    return &_getDescendantsMain ([], {}, $node);
}
sub _getDescendantsMain {
    my ($rv, $idHash, $node) = @_;

    if (defined ($node->{LEAF})) {
	foreach my $val (@{$node->{LEAF}}) {
	    my $id = refaddr ($val);
	    next if ($idHash->{$id}++ > 0);
	    push (@$rv, $val);
	}
    }
    foreach my $edge (keys (%$node)) {
	next if ($edge =~ /[A-Z]+/);

	&_getDescendantsMain ($rv, $idHash, $node->{$edge});
    }
    return $rv;
}

=head2 isEmpty

空か否かを返す
clean を流用しているので遅い。
=cut
sub isEmpty {
    my ($self) = @_;

    return ($self->clean)? 0 : 1;
}

=head2 clean ($node)

子供がなくなったノードを掃除。
ノードを指定しなければ、ルートから掃除。

=cut
sub clean {
    my ($self, $node) = @_;

    $node = $self->{root} unless (defined ($node));

    my $flag = 0; # 自分が必要か
    foreach my $edge (keys (%$node)) {
	if ($edge =~ /[A-Z]+/) {
	    $flag = 1;
	    next;
	}
	if ($self->clean ($node->{$edge})) {
	    $flag = 1;
	} else {
	    delete ($node->{$edge});
	}
    }
    return $flag;
}

sub delete {
    my ($self, $val) = @_;

    my $id = refaddr ($val);
    foreach my $node (@{$self->{'id2nodes'}->{$id}}) {
	if (defined ($node->{LEAF})) {
	    for (my $i = 0; $i < scalar (@{$node->{LEAF}}); $i++) {
		if ($node->{LEAF}->[$i] == $val) {
		    splice (@{$node->{LEAF}}, $i, 1);
		    last;
		}
	    }
	}
    }
    delete ($self->{'id2nodes'}->{$id});
}

# 効率化のため、複数の削除をまとめて処理
sub deleteGroup {
    my ($self, $list) = @_;

    # 先に node ごとにまとめる
    my $nodeList = {};
    foreach my $val (@$list) {
	my $id = refaddr ($val);
	foreach my $node (@{$self->{'id2nodes'}->{$id}}) {
	    my $nodeID = refaddr ($node);
	    $nodeList->{$nodeID}->[0] = $node;
	    $nodeList->{$nodeID}->[1]->{$id} = $val;
	}
	delete ($self->{'id2nodes'}->{$id});
    }
    foreach my $tmp (values (%{$nodeList})) {
	my ($node, $leafHash) = @$tmp;
	if (defined ($node->{LEAF})) {
	    my $newList = [];
	    for (my $i = 0; $i < scalar (@{$node->{LEAF}}); $i++) {
		my $val = $node->{LEAF}->[$i];
		my $id = refaddr ($val);
		unless (defined ($leafHash->{$id})) {
		    push (@$newList, $val);
		}
	    }
	    if (scalar (@$newList) > 0) {
		$node->{LEAF} = $newList;
	    } else {
		delete ($node->{LEAF});
	    }
	}
    }

    # 効率悪い
    $self->clean;

    # debug
    if ($self->{opt}->{debug}) {
	print ("clean??\n");
	$self->print;
    }
}

=head2 print ()

トライを整形して print

=cut
sub print {
    my ($self) = @_;
    &printTrieMain ($self->{root}, 0);
}

sub printTrieMain {
    my ($node, $depth) = @_;

    my $indent = '';
    for (0 .. $depth) {
	$indent .= "  ";
    }
    if (defined ($node->{LEAF})) {
	printf ("%sLEAF: %d\n", $indent, scalar (@{$node->{LEAF}}));
    }
    foreach my $edge (keys (%$node)) {
	next if ($edge =~ /[A-Z]+/);
	printf ("%s%s:\n", $indent, $edge);
	&printTrieMain ($node->{$edge}, $depth + 1);
    }
}

1;
