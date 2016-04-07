package Analyzer;

use strict;
use warnings;
use utf8;

# abstact class
#
# exec-each
#
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	serviceID => shift,
	opt => shift
    };
    bless($self, $class);
    return $self;
}
#
# must implement exec, serialize, and deserialize
#
# - exec($source, $type)
# - serialize($data)
# - deserialize($data)
#
sub getServiceID {
    my ($self) = @_;
    return $self->{serviceID};
}

1;
