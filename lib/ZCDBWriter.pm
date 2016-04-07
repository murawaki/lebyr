package ZCDBWriter;

use strict;
use warnings;
use utf8;

use Carp;
use Compress::Zlib qw/ deflateInit Z_OK Z_BEST_SPEED /;
use CDB_File;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	path => shift,
    };
    bless($self, $class);
    $self->{cdb} = CDB_File->new($self->{path}, $self->{path} . ".$$");
    return $self;
}

sub insert {
    my ($self, $k, $v) = @_;

    my ($d, $out, $rem, $status);
    ($d, $status) = deflateInit( -Bufsize => 4096, -Level => Z_BEST_SPEED );
    unless ($status == Z_OK) {
	croak("zlib initialization error");
    }

    ($out, $status) = $d->deflate($v);
    unless ($status == Z_OK) {
	croak("zlib deflate error: '$status'");
    }
    ($rem, $status) = $d->flush();
    unless ($status == Z_OK) {
	croak("zlib flush error: '$status'");
    }
    $out .= $rem;
    $self->{cdb}->insert($k, $out);
}

sub finish {
    my ($self) = @_;
    $self->{cdb}->finish or croak("$0 CDB_File finish failed");
}

1;
