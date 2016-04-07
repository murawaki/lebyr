#!/bin/env perl
#
# 訓練データからノイズを除去
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use ExampleList;
use NounCategorySpec;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1, ngword => 1, stopNEthres => 40, freqTop => 100 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'fDB=s', 'compressed',
	    'ngword!', # marked with $
	    'stopNE=s', 'stopNEthres=i', # those captured by NE tagger
	    'freqList=s', 'freqTop=i',   # frequent words would be irrelevant
    );

my $stopwordList = {
    '人' => 1,
    '事' => 1,
    # '国' => 1,
    '多く' => 1,
    # '家' => 1, '会社' => 1, '企業' => 1, '世界' => 1, '地域' => 1, '場所' => 1, '土地' => 1, '海' => 1,
    'キャラ' => 6,
    'キャラクター' => 7,

    # 'うち' => 1,
    'ひより' => 2,
    '愛' => 3,
    'さくら' => 4,
    # 'サイト' => 5,
    'レイ' => 1,
    # 'バンド' => 1,
    # 'モデル' => 1,
    # '県' => 1,
    # '村' => 1,
    # '市町村' => 1,
};

&initStopNE if ($opt->{stopNE});
&initTopFreqStop if ($opt->{freqList});

my $total = 0;
my $survive = 0;

# initialize
my $input;
if (defined($opt->{input})) {
    my $filepath = $opt->{input};
    if ($opt->{compressed}) {
	$input = IO::File->new("bzip2 -dc $filepath |") or die;
    } else {
	$input = IO::File->new($filepath) or die;
    }
    $input->binmode(':utf8');
} else {
    $input = *STDIN;
}
my $exampleList = ExampleList->new ($input);
$exampleList->setOStream (\*STDOUT);
outer:
while ((my $example = $exampleList->readNext)) {
    next if (index ($example->{id}, '?') > 0);
    if (!defined ($example->{id}) || ($example->{id} - 0) ne $example->{id}) {
	# 文字化け check
	printf STDERR ("broken input %s: %s\n", $example->{name}, $example->{id});
	next;
    }

    $total++;
    if ($opt->{ngword} && $example->{name} =~ /^\$/) {
	printf STDERR ("NG word: %s\n", $example->{name}) if ($opt->{debug});
	next;
    }
    if ($stopwordList->{$example->{name}}) {
	printf STDERR ("stop word: %s\n", $example->{name}) if ($opt->{debug});
	next;
    }
    if ($opt->{ngword} && $example->{name} =~ /^(?:\p{Hiragana}|\p{Katakana}|)$/) {
	printf STDERR ("bad word: %s\n", $example->{name}) if ($opt->{debug});
	next;
    }

    foreach my $f (@{$example->{featureList}}) {
	# 文字化け check
	if (($f->[0] - 0) ne $f->[0] || ($f->[1] - 0) ne $f->[1]) {
	    # 文字化け check
	    printf STDERR ("broken feature: %s:%s\n", $f->[0], $f->[1]);
	    next outer;
	}
    }
    $survive++;
    $exampleList->writeNext ($example);
}
$exampleList->readClose;

printf STDERR ("%f (%d / %d); %d deleted\n", $survive / $total, $survive, $total, $total - $survive);


sub initStopNE {
    my $input = IO::File->new ($opt->{stopNE}, 'r') or die;
    $input->binmode (':utf8');
    while ((my $line = $input->getline)) {
	chomp ($line);
	my ($name, $df) = split (/\s+/, $line);
	next unless ($df >= $opt->{stopNEthres});
	$stopwordList->{$name} = $df;
    }
    $input->close;
}

sub initTopFreqStop {
    my $input = IO::File->new ($opt->{freqList}, 'r') or die;
    $input->binmode (':utf8');
    my $c = 0;
    while ((my $line = $input->getline)) {
	last unless (++$c < $opt->{freqTop});

	chomp ($line);
	my ($freq, $name) = split (/\s+/, $line);
	$stopwordList->{$name} = $freq;
    }
    $input->close;
}

1;
