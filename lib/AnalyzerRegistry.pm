package AnalyzerRegistry;

use strict;
use warnings;
use utf8;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	serviceList => {},
	opt => shift,
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    return $self;
}

# $depList は解析に必要なソースデータの優先リスト
# 前が実行不可能な場合に後が使われる
sub add {
    my ($self, $analyzer, $depList) = @_;

    my $serviceID = $analyzer->getServiceID;
    return undef if (defined($self->{serviceList}->{$serviceID}));

    $self->{serviceList}->{$serviceID} = [$analyzer, $depList];
    return;
}

sub remove {
    my ($self, $serviceID) = @_;

    return undef if (defined($self->{serviceList}->{$serviceID}));
    delete($self->{serviceList}->{$serviceID});
}

sub get {
    my ($self, $serviceID) = @_;
    return $self->{serviceList}->{$serviceID}->[0];
}

sub getDependencyList {
    my ($self, $serviceID) = @_;
    return $self->{serviceList}->{$serviceID}->[1];    
}

1;
