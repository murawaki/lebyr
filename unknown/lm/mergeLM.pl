#!/bin/env perl
#
# 言語モデル同士をマージ
#

use strict;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw /retrieve nstore/;

use Ngram;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt,
	    'dir=s',            # 読み込み対象ディレクトリ
	    'start=i', 'end=i', # 読み込みファイルの制限
	    'output=s',         # 出力ファイル
	    'debug',
	    'all', 'fuzoku', 'verb', 'noun', 'multi', 'class', 'ngram', # legacy
	    'notri',            # trigram を削除
	    'thres=i',          # 入力言語モデルに対する足きり (出力ではない!)
	    'compact'           # 使われていない番号を埋めてテーブルを小さく
	    );

die unless ( -d $opt->{dir} );

if($opt->{all}) {
    $opt->{fuzoku} =
	$opt->{noun} =
	$opt->{verb} =
	$opt->{noun} =
	$opt->{verb} =
	$opt->{multi} =
	$opt->{class} =
	$opt->{ngram} = 1;
}
my $thres = (defined ($opt->{thres}))? $opt->{thres} : 0;

my $limited;
if (defined ($opt->{start}) || defined ($opt->{end})) {
    $limited = 1;
    $opt->{start} = -1 unless (defined ($opt->{start}));
    $opt->{end} = 0xFFFFFFFF unless (defined ($opt->{end}));
} else {
    $limited = 0;
}

my $mrphInfo;

my $counter = 0;
opendir (my $dirh, $opt->{dir}) or die;
foreach my $ftmp (sort {$a cmp $b} (readdir ($dirh))) {
    next if ($ftmp =~ /^\./);
    # next unless ($ftmp =~ /\.out$/);

    if ($limited) {
	if ($ftmp =~ /(\d+)/) {
	    my $num = $1;
	    next if ($num < $opt->{start} || $num > $opt->{end});
	} else {
	    next;
	}
    }
    print STDERR ("examine $ftmp\n") if ($opt->{debug});

    my $mrphInfo2 = retrieve ("$opt->{dir}/$ftmp") or die;
    if (defined ($mrphInfo)) {
	&mergeMrphInfo ($mrphInfo2);
    } else {
	foreach my $type (keys (%$mrphInfo2)) {
	    next if ($type eq 'table');
	    unless ($opt->{$type}) {
		delete ($mrphInfo2->{$type});
	    }

	    if ($type eq 'ngram') {
		&initNgram ($mrphInfo2);
	    } else {
		$mrphInfo->{$type} = $mrphInfo2->{$type};
	    }
	} 
    }
    undef ($mrphInfo2);

    $counter++;
}

if ($opt->{compact}) {
    print STDERR ("compacting the table...\n") if ($opt->{debug});
    $mrphInfo->{ngram} = &compactTable ($mrphInfo->{ngram});
}

$mrphInfo->{table} = &Ngram::getTable;
nstore ($mrphInfo, $opt->{output}) or die;


sub initNgram {
    my ($mrphInfo2) = @_;

    &Ngram::setTable ($mrphInfo2->{table});
    $mrphInfo->{ngram} = $mrphInfo2->{ngram};

    # 閾値によるあしきり
    if ($thres > 0) {
	for my $type ('BD', 'TD', 'TN') {
	    my $struct = $mrphInfo->{ngram}->{$type};
	    next unless (defined ($struct));

	    while ((my $key = each (%$struct))) {
		unless ($struct->{$key} > $thres) {
		    delete ($struct->{$key});
		}
	    }
	}
    }
    if ($opt->{notri}) {
	delete ($mrphInfo->{ngram}->{TN});
    }
}

sub mergeNgram {
    my ($ngram1, $ngram2, $ct) = @_;

    $ngram1->{UD} += $ngram2->{UD};

    my $struct1 = $ngram1->{BD};
    my $struct2 = $ngram2->{BD};
    while ((my $key2 = each (%$struct2))) {
	my @list = &Ngram::uncompressID ($key2, 1);
	my $key1 = &Ngram::compressID ([$ct->{midasi}->[$list[0]->[0]],
					$ct->{repname}->[$list[0]->[1]],
					$ct->{class}->[$list[0]->[2]]]);
	$struct1->{$key1} += $struct2->{$key2};
    }

    $struct1 = $ngram1->{TD};
    $struct2 = $ngram2->{TD};
    while ((my $key2 = each (%$struct2))) {
	my @list = &Ngram::uncompressID ($key2, 2);
	my $key1 = &Ngram::compressID ([$ct->{midasi}->[$list[0]->[0]],
					$ct->{repname}->[$list[0]->[1]],
					$ct->{class}->[$list[0]->[2]]],
				       [$ct->{midasi}->[$list[1]->[0]],
					$ct->{repname}->[$list[1]->[1]],
					$ct->{class}->[$list[1]->[2]]]);
	if (defined ($struct1->{$key1}) || $struct2->{$key2} > $thres) {
	    $struct1->{$key1} += $struct2->{$key2};
	}
    }

    return if ($opt->{notri});

    $struct1 = $ngram1->{TN};
    $struct2 = $ngram2->{TN};
    while ((my $key2 = each (%$struct2))) {
	my @list = &Ngram::uncompressID ($key2, 3);
	my $key1 = &Ngram::compressID ([$ct->{midasi}->[$list[0]->[0]],
					$ct->{repname}->[$list[0]->[1]],
					$ct->{class}->[$list[0]->[2]]],
				       [$ct->{midasi}->[$list[1]->[0]],
					$ct->{repname}->[$list[1]->[1]],
					$ct->{class}->[$list[1]->[2]]],
				       [$ct->{midasi}->[$list[2]->[0]],
					$ct->{repname}->[$list[2]->[1]],
					$ct->{class}->[$list[2]->[2]]]);
	if (defined ($struct1->{$key1}) || $struct2->{$key2} > $thres) {
	    $struct1->{$key1} += $struct2->{$key2};
	}
    }
}

sub mergeMrphInfo {
    my ($mrphInfo2) = @_;

    foreach my $type (keys (%$mrphInfo2)) {
	next if ($type eq 'table');
	unless ($opt->{$type}) {
	    delete ($mrphInfo2->{$type});
	}

	if ($type eq 'ngram') {
	    my $ct = &Ngram::convertTable ($mrphInfo2->{'table'});
	    delete ($mrphInfo2->{'table'});
	    &mergeNgram ($mrphInfo->{ngram}, $mrphInfo2->{ngram}, $ct);
	} else {
	    &mergeStruct ($mrphInfo->{$type}, $mrphInfo2->{$type});
	}
    } 
}

sub mergeStruct {
    my ($s1, $s2) = @_;

    my $key;
    while (($key = each (%$s2))) {
	if (ref ($s2->{$key})) {
	    $s1->{$key} = {} unless (defined ($s1->{$key}));
	    &mergeStruct ($s1->{$key}, $s2->{$key});
	} else {
	    if (defined ($s1->{$key})) {
		$s1->{$key} += $s2->{$key};
	    } else {
		$s1->{$key} = $s2->{$key};
	    }
	}
    }
}

sub compactTable {
    my ($ngram) = @_;

    my $table = &Ngram::getTable;
    my $midasi2id = $table->{'midasi2id'};
    my $id2midasi = $table->{'id2midasi'};
    my $repname2id = $table->{'repname2id'};
    my $id2repname = $table->{'id2repname'};
    my $class2id = $table->{'class2id'};
    my $id2class = $table->{'id2class'};

    my $lList = {
	'BD' => 1, 'TD' => 2, 'TN' => 3
    };

    # 0 番目は Ngram に現れないのであらかじめ代入しておく
    my $id2midasiUsed = [1];
    my $id2repnameUsed = [1];

    # 実際に使われている midasi と repname を調べる
    for my $type ('BD', 'TD', 'TN') {
	my $struct = $ngram->{$type};
	next unless (defined ($struct));

	my $l = $lList->{$type};
	while ((my $key = each (%$struct))) {
	    my @idList = &Ngram::uncompressID ($key, $l);
	    while ((my $id = shift (@idList))) {
		$id2midasiUsed->[$id->[0]]++;
		$id2repnameUsed->[$id->[1]]++;
	    }
	}
    }

    my $midasiCT = [];
    my $id2midasi2 = [];
    my $cur = 0;
    for (my $i = 0, my $l = scalar (@$id2midasi); $i < $l; $i++) {
	my $midasi = $id2midasi->[$i];
	if (defined ($id2midasiUsed->[$i])) {
	    $id2midasi2->[$cur] = $midasi;
	    $midasiCT->[$i] = $midasi2id->{$midasi} = $cur;
	    $cur++;
	} else {
	    delete ($midasi2id->{$midasi});
	}
    }
    if ($opt->{debug}) {
	my $diff = scalar (@$id2midasi) - $cur;
	printf STDERR ("will delete %d midasi (%f\% reduction)\n",
		       $diff, $diff * 100 / scalar (@$id2midasi));
    }
    $id2midasiUsed = $id2midasi = undef;

    my $repnameCT = [];
    my $id2repname2 = [];
    $cur = 0;
    for (my $i = 0, my $l = scalar (@$id2repname); $i < $l; $i++) {
	my $repname = $id2repname->[$i];
	if (defined ($id2repnameUsed->[$i])) {
	    $id2repname2->[$cur] = $repname;
	    $repnameCT->[$i] = $repname2id->{$repname} = $cur;
	    $cur++;
	} else {
	    delete ($repname2id->{$repname});
	}
    }
    if ($opt->{debug}) {
	my $diff = scalar (@$id2repname) - $cur;
	printf STDERR ("will delete %d repname (%f\% reduction)\n",
		       $diff, $diff * 100 / scalar (@$id2repname));
    }
    $id2repnameUsed = $id2repname = undef;

    my $classCT = [];
    for (my $i = 0, my $l = scalar (@$id2class); $i < $l; $i++) {
	$classCT->[$i] = $i;
    }

    &Ngram::setTable ({
	'midasi2id' => $midasi2id,
	'id2midasi' => $id2midasi2,
	'repname2id' => $repname2id,
	'id2repname' => $id2repname2,
	'class2id' => $class2id,
	'id2class' => $id2class
    });
    my $ct = {
	midasi => $midasiCT,
	repname => $repnameCT,
	class => $classCT
    };
    my $ngram2 = {
	UD => 0,
	BD => {},
	TD => {},
    };
    $ngram2->{TN} = {} unless ($opt->{notri});

    print STDERR ("converting N-gram...\n") if ($opt->{debug});
    &mergeNgram ($ngram2, $ngram, $ct);
    return $ngram2;
}

1;
