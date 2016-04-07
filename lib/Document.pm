package Document;

use strict;
use warnings;
use utf8;

# abstract class for documents
# 外部の実体と関連付けず、メモリ上にのみ展開する場合には、
# Document クラスに直接 setAnalysis でデータを追加すればよい

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift,
	services => {}
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    return $self;
}

sub getAnalysis {
    my ($self, $serviceID) = @_;

    my $data = $self->{$serviceID};
    return $data if (defined($data));
    return undef;
}

sub setAnalysis {
    my ($self, $serviceID, $data) = @_;

    $self->{services}->{$serviceID} = 1;
    return $self->{$serviceID} = $data;
}

# 1:  ready
# 0:  ok but not ready
# -1: unavailable
sub isAnalysisAvailable {
    my ($self, $serviceID) = @_;

    if (defined($self->{services}->{$serviceID})) {
	return $self->{services}->{$serviceID};
    }
    return -1;
}

sub setAnalysisStatus {
    my ($self, $serviceID, $status) = @_;

    return $self->{services}->{$serviceID} = $status;
}


=head2 getAnnotation($key)

ドキュメントに付与された注釈を得る。

=cut
sub getAnnotation {
    return ($_[0])->{annotation}->{$_[1]};
}

=head2 setAnnotation($key, $value)

ドキュメントに注釈を付加する

=cut
sub setAnnotation {
    my ($self, $key, $value) = @_;

    $self->{annotation}->{$key} = $value;
}
=head2 deleteAnnotation ($key)

ドキュメントの注釈を削除する

=cut
sub deleteAnnotation {
    my ($self, $key) = @_;

    delete($self->{annotation}->{$key});
}

1;
