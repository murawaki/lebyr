#!/bin/env perl
#
# &MorphemeUtilities::isEUCConvertible の実験
#
use strict;
use utf8;

use Encode;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');
# binmode (STDOUT, ':encoding (enc-jp)');
# binmode (STDERR, ':encoding (enc-jp)');

my %opt;
GetOptions (\%opt, 'debug');

my $midasi = "대한";
print STDERR ("hangul: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "ｱｸｱﾄﾞﾗｲ";
print STDERR ("hankaku: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "アクアドライ®";
print STDERR ("bad simbol: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "アクアドライ";
print STDERR ("norm: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "ABCD";
print STDERR ("alphabet: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "ＡＢ";
print STDERR ("fullwidth alphabet: $midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "颭顇";
print STDERR ("$midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "монгол";
print STDERR ("$midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "алтан";
print STDERR ("$midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

my $midasi = "长白";
print STDERR ("$midasi\n");
&checkMapping ($midasi);
print STDERR ("----------\n");

# use Juman;
# my $result = Juman->new->analysis ("$midasi\n");
# print $result->spec;

# 変換のチェック
# 問題があれば 1
sub checkMapping {
    my ($str) = @_;

    my $enc;
    # 実際に変換してチェック
    eval {
	# 失敗したら死ぬ
	$enc = encode ('euc-jp', $str, Encode::FB_CROAK);
    };
    if ($@) {
	print STDERR ($@);
	return 1;
    }
    {
        use bytes;
	                #  ASCII        HALF KANA         3 byte KANJI
	while ($enc =~ /([\x00-\x7F]|\x8e[\xa1-\xdf]|\x8f[\xa1-\xfe][\xa1-\xfe])/) {
	    print STDERR ("1 byte?\n");
	    return 1;
	}
# 	foreach my $c (split (//, $enc)) {
# 	    if ($c < 0x80) {
# 		print STDERR ("1 byte?\n");
# 		return 1;
# 	    }
# 	}
    }
    return 0;

    # TODO
    # EUC-JP で 3 byte になる漢字の排除

    # 1 byte になりそうなものを排除
    # 範囲指定は、encode で失敗しそうなものも含めて広めに
    if ($str =~ /([\x{0000}-\x{2E7F}])/) {
	print STDERR ("contains malformed character\n");
	return 1;
    }

    # Halfwidth and Fullwidth Forms 中の半角カナの部分
    if ($str =~ /[\x{FF61}-\x{FF9F}]/) {
	print STDERR ("contains hankaku character\n");
	return 1;
    }

#     my $flag = 1;
#     my $enc = encode ('euc-jp', $str, sub {
# 	'〓'
# #	$flag = 0;
# #	sprintf "<U+%04X>", shift
#     });
#     my $orig = decode ('euc-jp', $enc);
#     print STDERR ("orig: $orig\n");
#     return 0 unless ($flag);

#     foreach my $c (split (//, $str)) {
# 	my $enc = encode ('euc-jp', $str, sub {'〓'});
# 	print ord ($enc), "\n";
#     }

#     while ($enc =~ /([\x00-\x80])/g) {
# 	my $c = $1;
# 	return 1;
#     }

    my $enc;
    # 実際に変換してチェック
    eval {
	# 失敗したら死ぬ
	$enc = encode ('euc-jp', $str, Encode::FB_CROAK);
    };
    if ($@) {
	print STDERR ($@);
	return 1;
    }
    {
        use bytes;
	if ($enc =~ /\x8f[\xa1-\xfe][\xa1-\xfe]/) {
# 	while ($enc =~ /([^\x80-\xfe]|[\x80-\x8e\x90-\xfe][\x80-\xfe]|\x8f[\x80-\xfe][\x80-\xfe])/g) {
# 	    my $c = $1;
# 	    if ($c =~ /^\x8f/) { # 3byte code (JISX0212)
	    print STDERR ("3 byte character\n");
		return 1;
#	    }
	}
    }
    return 0;
}



1;
