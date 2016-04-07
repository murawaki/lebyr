package Egnee::GlobalConf;

use strict;
use warnings;
use utf8;

use IO::File;

our $conf = {};

sub loadFile {
    $conf->{file} = $_[0];

    my $file = IO::File->new($conf->{file}) or die("$!");
    $file->binmode(':utf8');
    my $buf = join('', $file->getlines);
    $file->close;

    my $hash = eval($buf);
    $conf->{_opt} = $hash;
}

sub get {
    return $conf->{_opt}->{$_[0]};
}

sub set {
    return $conf->{_opt}->{$_[0]} = $_[1];
}

sub save {
    my ($fpath) = @_;

    $fpath = $conf->{file} unless (defined($fpath));
    my $file = IO::File->new($conf->{file}, 'w') or die("$!");
    $file->binmode(':utf8');
    $file->prin("+{\n");
    my @list = sort { $a cmp $b } (keys(%{$conf->{_opt}}));
    for (my $i = 0; $i < scalar(@list); $i++) {
	my $name = $list[$i];
	$file->printf("    '%s' => '%s'%s", $name, $conf->{_opt}->{$name}, (($i >= $#list)? "\n" : ",\n"));

    }
    $file->print("}\n");
    $file->close;
}

1;
