#!/bin/env perl
#
# jumanDiffSeq の結果を入力として、評価用の HTML を生成
#
use strict;
use utf8;
use warnings;

use Encode;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { katakana => 0 };
GetOptions ($opt, 'input=s', 'count=i', 'noeval', 'katakana!', 'debug');

die unless ( -f $opt->{input} );

$opt->{input} =~ /([^\/]*)\.html$/;
my $pageID = $1;
die unless (defined ($pageID));

my $stopBlockList = {}; # no katakana
my $stopSentenceList = {}; # no katakana

# 文の数を数える
my $sentenceNum = &countSentences ($opt->{input});

my $selNum = 50;
if ($opt->{count}) {
    $selNum = $opt->{count};
}
# そのなかから 100 文を選択
my $seq = &getRandSequence ($sentenceNum, $selNum);

my ($header, $footer, $sentenceList) = &loadDiff ($opt->{input});

print $header;
print <<__EOF__;
<style>
.sentence-block {
  border: 1px solid gray;
}
.sentence {
    background-color: #efefef;
}
</style>
__EOF__
print ('<form method="POST" action="/~murawaki/cgi-bin/diffEval.cgi">') unless ($opt->{noeval});
print ("<input type=\"hidden\" name=\"pageID\" value=\"$pageID\">") unless ($opt->{noeval});


my $counter = 0;
my $diffCount = 0;
foreach my $i (@$seq) {
    my $sentenceCode = $sentenceList->[$i];
    my @diffList = ($sentenceCode =~ /overlib\(\'([^\']+)\'/g);

    print ("<div class=\"sentence-block\">\n");
    printf ("number: %d (%d)<br>\n", $counter++, $i);
    print ("<div class=\"sentence\">\n");
    printf ("%s\n", $sentenceCode);
    print ("</div>\n");
    for (my $j = 0; $j < scalar (@diffList); $j++) {
	next if (defined ($stopBlockList->{$i}) && $stopBlockList->{$i}->[$j]);

	my $diff = $diffList[$j];
	my $id = "diff" . $diffCount;

	chomp ($diff);
	$diff =~ s/\\n/\n/g;
	$diff =~ s/\&lt;br\/\&gt;//g;
	print <<__EOF__;
<pre>
$diff
</pre>
__EOF__
        unless ($opt->{noeval}) {
	    print <<__EOF__;
分割: $diffCount<br/>
C -\&gt; C: <input type="radio" name="seg$id" value="0"><br/>
C -\&gt; E: <input type="radio" name="seg$id" value="1"><br/>
E -\&gt; C: <input type="radio" name="seg$id" value="2"><br/>
E -\&gt; E: <input type="radio" name="seg$id" value="3"><br/>
品詞込み: $diffCount<br/>
C -\&gt; C: <input type="radio" name="tag$id" value="0"><br/>
C -\&gt; E: <input type="radio" name="tag$id" value="1"><br/>
E -\&gt; C: <input type="radio" name="tag$id" value="2"><br/>
E -\&gt; E: <input type="radio" name="tag$id" value="3"><br/>
__EOF__
        }
        $diffCount++;
    }
    print ("</div>\n");
}

unless ($opt->{noeval}) {
    print <<__EOF__;
<input type="hidden" name="diffNum" value="$diffCount">
<input type="submit" value="Submit">
</form>
__EOF__
}
print $footer;







# 一度読み込んで行数を調べる
sub countSentences {
    my ($path) = @_;

    my $count = 0;
    open (my $file, "<:utf8", $path) or die;
    while (<$file>) {
	my $input = $_;
	if ($input =~ /^\<\/div\>/) { # 閉じるほうで数える
	    $count++;
	    next;
	}

	if (!$opt->{katakana}) {
	    my @diffBlockList = ($input =~ /\>([^\<]+)\<\/a\>/g);
	    next unless (scalar (@diffBlockList) > 0);

	    my $excl = 1;
	    for (my $i = 0; $i < scalar (@diffBlockList); $i++) {
		my $block = $diffBlockList[$i];
		if ($block =~ /^(\p{Katakana}|ー)*$/) {
		    $stopBlockList->{$count}->[$i] = 1;
		} else {
		    $excl = 0;
		}
	    }
	    $stopSentenceList->{$count} = 1 if ($excl);
	}
    }
    close ($file);
    return $count;
}

sub loadDiff {
    my ($path) = @_;

    my $header = '';
    my $footer = '';
    my $sentenceList = [];

    # 0: header
    # 1: 文開始
    # 2: 文終り
    # 3: footer
    my $status = 0;

    open (my $file, "<:utf8", $path) or die;
    while (<$file>) {
	chomp;
	if ($_ =~ /^\<div\>/) {
	    $status = 1;

	} elsif ($_ =~ /^\<\/div\>/) {
	    ;
	} else {
	    if ($status == 0) {
		$header .= "$_\n";
	    } elsif ($status == 1) {
		push (@$sentenceList, $_);
		$status = 2;
	    } else {
		$status = 3;
		$footer .= "$_\n";
	    }
	}
    }
    close ($file);

    return ($header, $footer, $sentenceList);
}

# 0 ... $length - 1 の列からランダムに $num 個とる
sub getRandSequence {
    my ($length, $num) = @_;

    my $seq = {};
    for (my $i = 0; $i < $num; $i++) {
	while (1) {
	    my $rand = int (rand ($length));
	    unless (defined ($seq->{$rand})
		    || $stopSentenceList->{$rand}) {
		$seq->{$rand} = 1;
		last;
	    }
	}
    }
    my @seq2 = sort { $a <=> $b } (keys (%$seq));
    return \@seq2;
}

