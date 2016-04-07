#!/bin/env perl
#
# divergence 計算用の instance 毎のファイルを merge
# 品詞ごとに行う
#
use strict;
use utf8;

use Getopt::Long;
use Storable qw (retrieve nstore);

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'index=i', 'dir=s', 'output=s', 'start=i', 'end=i', 'debug');

die unless ( -d $opt->{dir} );
die unless (defined ($opt->{output}));

my $posList = [
	       '母音動詞',
	       '子音動詞カ行',
	       '子音動詞ガ行',
	       '子音動詞サ行', # 3
	       '子音動詞タ行',
	       '子音動詞バ行',
	       '子音動詞マ行', # 6
	       '子音動詞ラ行',
	       '子音動詞ワ行',
	       'サ変動詞',     # 9
	       'ザ変動詞',
	       'イ形容詞',
	       '普通名詞',    # 12
	       'ナ形容詞',    # 13

	       # 2階層目を使う場合
	       'サ変名詞',         # 14
	       'イ形容詞アウオ段', # 15
	       'イ形容詞イ段',     # 16
	       'ナノ形容詞',       # 17
	       ];
# サ変以外の名詞
my $posGroup = {
    '普通名詞' => 1,
    '固有名詞' => 2,
    '人名' => 3,
    '地名' => 4,
    '組織名' => 5,
    # 副詞的名詞
    # 時相名詞
    # 形式名詞
};

my $targetPOS;
die unless ($opt->{index} < scalar (@$posList));
if ($opt->{index} >= 0) {
    $targetPOS->{$posList->[$opt->{index}]} = 1;
} else {
    $targetPOS = $posGroup;
}

$opt->{start} = -1 unless (defined ($opt->{start}));
$opt->{end} = 0xFFFFFFFF unless (defined ($opt->{end}));

my $counter = 0;
my $rv = {};
opendir (my $dirh, $opt->{dir}) or die;
foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
    # next unless ($ftmp =~ /\.storable$/);
    next unless ( -f "$opt->{dir}/$ftmp" );

    if ($ftmp =~ /^(\d+)/) {
	my $num = $1;
	next if ($num < $opt->{start} || $num > $opt->{end});
    }

    print STDERR ("examine $ftmp\n") if ($opt->{debug});

    my $tmp = retrieve ("$opt->{dir}/$ftmp");
    foreach my $pos (keys (%$targetPOS)) {
	my $mlist = $tmp->{$pos};
	my $genkei;
	while (($genkei = each (%$mlist))) {
	    foreach my $suffix (keys (%{$mlist->{$genkei}})) {
		$rv->{$genkei}->{$suffix} += $mlist->{$genkei}->{$suffix};
	    }
	    $counter++;
	}
    }
}
printf STDERR ("%d morphemes processed\n", $counter) if ($opt->{debug});

nstore ($rv, $opt->{output}) or die;

1;

