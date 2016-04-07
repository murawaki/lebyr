package Egnee::GlobalServices;

use strict;
use warnings;
use utf8;

our $services = {};

sub get {
    return $services->{$_[0]};
}

sub set {
    return $services->{$_[0]} = $_[1];
}

1;
