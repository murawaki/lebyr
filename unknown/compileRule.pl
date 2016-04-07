#!/bin/env perl
#
# 未知語検出ルールをコンパイルする
#

use strict;
use utf8;

use Encode;
use Getopt::Long;

use Storable qw /nstore/;
use UndefRule::Parser;
use Carp qw(croak);

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $lineMax = 5; # 1ルールは最大5行で記述

my %opt;
GetOptions (\%opt, 'debug', 'input=s', 'output=s');
die unless ( -f $opt{input} );
# die unless (defined ($opt{output}));

use Dumpvalue;

my $ruleList = [];
my $parser = UndefRule::Parser->new;
open (my $file, "<:utf8", $opt{input});
my $line = 0;
my $buf = '';
while (<$file>) {
    chomp;
    $buf .= "$_\n";
    my $rule;
    $line++;
    my $bufTMP;
    eval {
	($rule, $bufTMP) = &read ($parser, $buf);
    };
    if ($@) {
	# print STDERR ("$@\n");
	next;
    }
    # skip comment # 挙動の確認が必要
    unless (defined ($rule)) {
	$line = 0;
	$buf = '';
	next;
    }
    if ($line > $lineMax) {
	print STDERR ("$@\n");
	exit 1;
    }
    $buf = $bufTMP;
    $line = 0;
    Dumpvalue->new->dumpValue ($rule) if ($opt{debug});

    push (@$ruleList, $rule);
}
close ($file);

if ($opt{output}) {
    nstore ($ruleList, $opt{output}) or die;
}


sub read {
    my ($parser, $string) = @_;

    $parser->set_input($string);
    my $value = $parser->parse;

    unless (defined($value)) {
	my $errorNum = $parser->YYNberr();
	croak("SExp Parse error") if ($errorNum > 0);
	return undef;
    }

    my $unparsed = $parser->unparsed_input;
    return wantarray ? ($value, $unparsed) : $value;
}


1;
