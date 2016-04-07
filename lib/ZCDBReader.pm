package ZCDBReader;

use strict;
use warnings;
use utf8;

use Carp;
use Compress::Zlib qw/ inflateInit Z_OK Z_STREAM_END /;
use CDB_File;
our @ISA = qw(CDB_File);

sub FETCH {
    my ($self, $k) = @_;

    my $v = $self->SUPER::FETCH($k);
    return $v unless (defined($v));

    my ($i, $buf, $status);
    ($i, $status) = inflateInit( -Bufsize => 4096 );
    unless ($status == Z_OK) {
	croak("zlib initialization error");
    }

    ($buf, $status) = $i->inflate($v);
    unless ($status == Z_STREAM_END) {
	croak("zlib inflate error: '$status'");
    }
    return $buf;
}

1;
