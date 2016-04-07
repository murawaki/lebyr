#!/bin/env perl
#
# 普通の N-gram から表記揺れ N-gram に変換
#
# 抽象化まわりで超絶バグがわきやすいプログラムになっているので注意が必要
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

my %opt = ( bnst => 1 );
GetOptions (\%opt, 'input=s', 'output=s', 'notri', 'bnst!', 'debug');


my $repnamesFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameList = retrieve ($repnamesFile) or die;
&Ngram::initRepnameList ($repnameList);
my $mrphInfo = retrieve ($opt{input}) or die;
&Ngram::setTable ($mrphInfo->{table});

# ここで始めて抽象化クラスを用意する
&Ngram::initAbstractClasses;

if ($opt{notri}) {
    delete ($mrphInfo->{ngram}->{TN});
}

my $repnameNgram = &makeRepnameNgram ($mrphInfo->{ngram});
$repnameNgram->{table} = &Ngram::getTable;
nstore ($repnameNgram, $opt{output}) or die;

1;


sub makeRepnameNgram {
    my ($ngram) = @_;

    my $repnameNgram = {};
    my $boundaryMidasiID = (&Ngram::boundaryID)->[0];

    # uni: unigram
    # fbi: 前向き bigram
    # bbi: 後向き bigram

#     # initialization
#     while ((my $repname = each (%$repnameList))) {
# 	$repnameNgram->{$repname} = { uni => {}, fbi => {}, bbi => {} };
#     }

    # unigram (== bigram denominator)
    my $struct = $ngram->{BD};
    my $uni = {};
    $repnameNgram->{uni} = $uni;
    while ((my $key = each (%$struct))) {
	my $val = $struct->{$key};
	my $id = &Ngram::uncompressID ($key, 1);
	next unless ($id->[1] >= 1); # repname がなければ無視

	my ($midasi, $repname, $class) = split (/-/, &Ngram::id2word ($id));
	next unless (defined ($repnameList->{$repname}));

	# $uni->{$key} += $val; # 一応 +=

	# repname を抜いた形で登録
	# KNP が -dpnd オプションなら同形は辞書順で格納されるが、
	# 格解析を行なうと適当な同形を選択して順番が破られるから。
	# e.g. う-鵜/う-<普通名詞> => う--<普通名詞>
	#
	# 別の問題:
	# そら -> そら-空/そら-<普通名詞> だが、
	# 異表記側の 空-空/そら-<普通名詞> は
	# 空-空/から-<普通名詞> に負けて出現頻度が 0 になる
	# この問題も、 空--<普通名詞> とすることで対処される
	my $idM = &Ngram::getMidasiID ($id);
	$uni->{&Ngram::compressID ($idM)} += $val;

	# 動詞や形容詞は活用形を抜いた class でも登録
	# e.g. <動詞:基本連用形> => <動詞>
	# X--<動詞>
	my $idMA = &Ngram::getAbstractClassID ($idM);
	if ($idM->[2] != $idMA->[2]) {
	    $uni->{&Ngram::compressID ($idMA)} += $val;
	}
    }

    # bigram (== trigram denominator)
    # w1 w2 について足し併せてつくる
    $struct = $ngram->{TD};
    my $fbi = {};
    my $bbi = {};
    $repnameNgram->{fbi} = $fbi;
    $repnameNgram->{bbi} = $bbi;
    while ((my $key = each (%$struct))) {
	my $val = $struct->{$key};
	my ($id1, $id2) = &Ngram::uncompressID ($key, 2);

	# いずれかが repname でなければいけない
	next unless ($id1->[1] >= 1 || $id2->[1] >= 1);
	# boundary は無視
	next if ($id1->[0] == $boundaryMidasiID || $id2->[0] == $boundaryMidasiID);

	my ($midasi1, $repname1, $class1) = split (/-/, &Ngram::id2word ($id1));
	my ($midasi2, $repname2, $class2) = split (/-/, &Ngram::id2word ($id2));

	# w2 の活用形は w1 との連接にあまり関係しないので区別しない
	my $id2A = &Ngram::getAbstractClassID ($id2);

	# w1 がチェック対象なら forward bigram を更新
	if ($repname1 && defined ($repnameList->{$repname1})) {
	    my $id1M = &Ngram::getMidasiID ($id1);
	    my $id2R = &Ngram::getRepnameID ($id2A);

	    my $k1 = &Ngram::compressID ($id1M);
	    my $k2 = &Ngram::compressID ($id2R);
	    $fbi->{$k1}->{$k2} += $val;
	}

	# w2 がチェック対象なら backward bigram を更新
	if ($repname2 && defined ($repnameList->{$repname2})) {
	    my $id1R = &Ngram::getRepnameID ($id1);
	    my $id2AM = &Ngram::getMidasiID ($id2A);

	    my $k1 = &Ngram::compressID ($id1R);
	    my $k2 = &Ngram::compressID ($id2AM);
	    $bbi->{$k2}->{$k1} += $val;
	}
    }

    return $repnameNgram unless ($opt{bnst});    

    # boundary count (unigram)
    $repnameNgram->{Bu} = $ngram->{BD}->{&Ngram::compressID (&Ngram::boundaryID)};
    my $f = {}; # w, B の連鎖
    my $b = {}; # B, w の連鎖

    $struct = $ngram->{TD};
    while ((my $key = each (%$struct))) {
	my $val = $struct->{$key};
	my ($id1, $id2) = &Ngram::uncompressID ($key, 2);

	if ($id1->[0] == $boundaryMidasiID) {
	    # forward bigram の f(B, r1)
	    #   abstractClass + repname
	    # backward bigram の f(B, w0)
	    #   abstractClass + 代表表記除去
	    my $id2A = &Ngram::getAbstractClassID ($id2);
	    my $id2R = &Ngram::getRepnameID ($id2A);
	    $b->{&Ngram::compressID ($id2R)} += $val; # forward

	    my ($midasi2, $repname2, $class2) = split (/-/, &Ngram::id2word ($id2));
	    if ($repname2 && defined ($repnameList->{$repname2})) {
		# id2R not eq id2AM
		my $id2AM = &Ngram::getMidasiID ($id2A);
		my $k2A = &Ngram::compressID ($id2AM);
		$b->{$k2A} += $val;		      # backward
	    }
	} elsif ($id2->[0] == $boundaryMidasiID) {
	    # forward bigram の f(w0, B)
	    #   代表表記除去
	    # backward bigram の f(r-1, B)
	    #   repname
	    my $id1R = &Ngram::getRepnameID ($id1);
	    $f->{&Ngram::compressID ($id1R)} += $val; # backward

	    my ($midasi1, $repname1, $class1) = split (/-/, &Ngram::id2word ($id1));
	    if ($repname1 && defined ($repnameList->{$repname1})) {
		# id1R not eq id1M
		my $id1M = &Ngram::getMidasiID ($id1);
		my $k1 = &Ngram::compressID ($id1M);  # forward
		$f->{$k1} += $val;
	    }
	}
    }
    $repnameNgram->{Bf} = $f;
    $repnameNgram->{Bb} = $b;

    return $repnameNgram;
}
