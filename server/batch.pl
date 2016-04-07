#!/bin/env perl
#; -*- Mode: perl; -*-
use utf8;
use strict;
use warnings;

use Egnee::GlobalConf;
use Encode qw/encode/;
use IO::Socket::INET;
use IO::File;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# DEFAULT SETTINGS
my $confPath = "/home/murawaki/research/lebyr/server/prefs";
my $batchPath = "/home/murawaki/public_html/egnee/data/batch";

Egnee::GlobalConf::loadFile($confPath);
my $host = Egnee::GlobalConf::get('egnee.host') or die;
my $port = Egnee::GlobalConf::get('egnee.port') or die;

my $EOD = "__EOD__";
my $interval = 0.3;
my $largeInterval = 10;

my $file = IO::File->new($batchPath) or die;
$file->binmode('utf8');

my $socket = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $host, PeerPort => $port)
    or die("Cannot connect to $host:$port: $!)");

my $count = 0;
$socket->autoflush(1);
$socket->print("BATCH\n");
while ((my $line = $file->getline)) {
    $socket->print(encode_utf8($line));
    sleep($interval);
    sleep($largeInterval) unless ($count++ % 500);
}
$socket->print("$EOD\n");
$socket->flush;
$socket->close;

$file->close;

1;
