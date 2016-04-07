package Egnee::Util;

use strict;
use utf8;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw /dynamic_use/;

sub dynamic_use {
    my $classname = shift (@_);

    unless ($classname) {
	my @caller = caller (0);
	die ("Dynamic use called from $caller[1] (line $caller[2]) with no classname parameter\n");
    }
    my ($parent_namespace, $module) = ($classname =~ /^(.*::)(.*)$/ ? ($1, $2) : ('::', $classname));
    no strict 'refs';
    # skip if already used
    unless ($parent_namespace->{$module . '::'} &&
	%{$parent_namespace->{$module . '::'} || {} }) {
	eval ("require $classname");
	die ("$@\n") if($@);
    }
    $classname->import (@_);
    return 1;
}

1;
