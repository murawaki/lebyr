package Egnee::Logger;
#
# common logger
#   log level per package
#
use strict;
use warnings;
use utf8;

use Dumpvalue;

our $log;
our $dv;
our $logLevel = {};

BEGIN {
    $log = \*STDERR;
    $dv = Dumpvalue->new;
}

# logging methods
# should implement class-dependent behavior
sub setLogger {
    my ($val, $package) = @_;
    $val = 1 unless (defined($val));
    $package = caller unless (defined($package));

    $logLevel->{$package} = $val;
}

sub info {
    my $package = caller;
    my $level = $logLevel->{$package} || 0;
    print $log ($package . ': ' . $_[0]) if ($level > 0);
}

sub warn {
    my $package = caller;
    my $level = $logLevel->{$package} || 0;
    printf $log ("WARNING: %s: %s", $package, $_[0]);
}

sub dumpValue {
    my ($val) = @_;
    my $package = caller;
    my $level = $logLevel->{$package} || 0;

    if ($level > 0) {
	my $doSelect = (\*STDOUT == $log)? 1 : 0;
	my $fh = select($log) if ($doSelect);
	$dv->dumpValue($val);
	select($fh) if ($doSelect);
	print $log ("\n");
    }
}

sub setLogOutput {
    my ($this, $fh) = @_;

    $log = $fh;
}

1;
