#!/bin/env perl
#
# extract from a document set various features that will be used to classify nouns
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Scalar::Util qw/refaddr/;

use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
use Egnee::AnalyzerRegistryFactory;
use AnalysisObserverRegistry;
use JumanDictionary;
# use MorphemeUtilities;
use CaseFrameExtractor;
use NounCategorySpec;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {
    conf => "/home/murawaki/research/lebyr/prefs",
    probcase => 0, filter => 1 };
GetOptions($opt,
	   'conf=s',
	   Egnee::DocumentPoolFactory::optionList,
	   'debug', 'probcase', 'both', 'acquired', 'filter!');
#
# both: 自動獲得語彙と基本語彙の両方を収集
#       自動獲得語彙には * を付ける
# acquired: 1: 自動獲得語彙のみ, 0: 基本語彙のみ
#

my $targetBunrui = {
    '普通名詞' => 1,
    'サ変名詞' => 2,
    '人名' => 3,
    '地名' => 4,
    '組織名' => 5,
    '固有名詞' => 6,
    # 数詞などを排除
};

# 形態素の意味情報に付与されている末尾成分のリスト
my $entityTagList = {
    '人名' => 1,
    '地名' => 2,
    '住所' => 3,
    '組織名' => 4
};
my $callStopList = {
    # '他/ほか', 'ところ/ところ': <形副名詞>
    '程/ほど' => 2,
    '事/こと?事/じ' => 3, # 'こと/こと' => 3 # <形副名詞>
    '時/とき' => 4,
    '方/かた' => 5, # 人を表す場合もあるが、比較と曖昧性があるので捨てる
    '訳/やく?訳/わけ' => 6,
    '割に/わりに' => 7,

    # メタな用法 # 「名前」,「名称」は固有名詞っぽいので採用
    '言葉/ことば' => 100, '単語/たんご' => 100, '言い/いいv+方/かた' => 100,
    '意味/いみ' => 100,    
    '漢字/かんじ' => 100, '字/あざ?字/じ' => 100, '文字/もじ' => 100,
    '話/はなし' => 100, '噂/うわさ' => 100,
    '感じ/かんじv' => 100, '気/き' => 100, '実感/じっかん' => 100, '気持ち/きもち' => 100,
    '意見/いけん' => 100, '声/こえ' => 100, '認識/にんしき' => 100,
    '点/てん' => 100, '面/おもて?面/つら?面/めん' => 100, '観点/かんてん' => 100,
};
my $personalSuffixList = {
    'さん' => 1,
    '君' => 2, 'くん' => 2,
    '様' => 3, 'さま' => 3,
    '殿' => 4,
    '氏' => 5,
    'ちゃん' => 6, 'チャン' => 6,
};
my $nouncat = NounCategorySpec->new;

##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

my $sentenceBasedAnalysisObserverRegistry;
my $cfExtractor;
&init;

my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    my $documentID = $document->getAnnotation('documentID');
    my $domain = $document->getAnnotation('domain');
    unless ($domain) {
	$document->can('url') and $document->url =~ /^(?:https?:\/\/)?([^\/]+)/xi and $domain = $1;
    }
    printf("#document\t%s\t%s\n", $documentID, $domain);

    $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}

sub onDataAvailable {
    my ($sentence) = @_;

    # 格要素のペアを取り出す
    my $knpResult = $sentence->get('knp');
    $cfExtractor->prepare($knpResult);

    # 人名疑い
    if ($opt->{filter}) {
	my $personList = &extractPersonalNames($knpResult);
	foreach my $p (keys(%$personList)) {
	    printf("\$ %s\n", $p);
	}
    }

    my $cfList = &extractCaseFrames($knpResult);
    my $ncfList = &extractNounCaseFrames($knpResult);
    # my $demoList = &extractDemoModifiee($knpResult);
    my $callList = &extractToIuPattern($knpResult);
    $cfExtractor->clean($knpResult);    

    my @mrphListSentence = $knpResult->mrph;
    my $bnstIndex = 0;
    foreach my $bnst ($knpResult->bnst) {
	my @mrphList = $bnst->mrph;
	for (my $i = $#mrphList; $i >= 0; $i--) {
	    my $mrph = $mrphList[$i];
	    next unless ($mrph->hinsi eq '名詞' && $targetBunrui->{$mrph->bunrui});
	    next if ($mrph->fstring =~ /\<品詞変更\:/); # a や v もまとめて排除
	    # next if (&MorphemeUtilities::isUndefined($mrph));

	    # 自動獲得のみを集めるか、自動獲得以外を集めるか
	    next if (!$opt->{both} && ($mrph->imis =~ /自動獲得/ xor $opt->{acquired}));

	    my $classString = $mrph->genkei;
	    if ($opt->{both} && $mrph->imis =~ /自動獲得/) {
		$classString .= '*';
	    }
	    $classString .= "\t" . $nouncat->getIDFromMrph($mrph);

	    # connection features
	    my $mrphIndex = $bnstIndex + $i;
	    if ($mrphIndex > 0) {
		my $mrphP = $mrphListSentence[$mrphIndex - 1];
		printf("%s\tprev\t%s\n", $classString, $mrphP->genkei);
	    }
	    if ($mrphIndex + 1 < scalar(@mrphListSentence)) {
		my $mrphN = $mrphListSentence[$mrphIndex + 1];
		printf("%s\tnext\t%s\n", $classString, $mrphN->genkei);
	    }

	    my $refaddr = refaddr($mrph);
	    if (defined($callList->{$refaddr})) {
		my $struct = $callList->{$refaddr};
		printf("%s\tcall\t%s\n", $classString, $struct->{feature});
		next; # make sure that no other features are extracted
	    }
	    if (defined($cfList->{$refaddr})) {
		foreach my $struct (@{$cfList->{$refaddr}}) {
		    printf("%s\tcf\t%s\n", $classString, $struct->{cf});
		}
	    }
	    if (defined($ncfList->{$refaddr})) {
		my $struct = $ncfList->{$refaddr};
		printf("%s\t%s\t%s\n", $classString, $struct->{type}, $struct->{feature});
	    }
# 	    if (defined($demoList->{$refaddr})) {
# 		my $struct = $demoList->{$refaddr};
# 		printf("%s\t%s\t%s\n", $classString, $struct->{type}, $struct->{feature});
# 	    }

# 	    # X + suffix
# 	    if ($i == 0 && $i < $#mrphList) {
# 		my $mrphP = $mrphList[$i + 1];

# 		if ($mrphP->bunrui eq '名詞性特殊接尾辞' || $mrphP->bunrui eq '名詞性名詞接尾辞') {
# 		    printf("%s\tsuf\t%s\n", $classString, $mrphP->genkei);
# 		} elsif ($mrphP->imis =~ /(\w+)末尾(外)?[\s\"]/ && index($mrphP->fstring, '<文節主辞>') >= 0) {
# 		    # 「首相」など、一部の末尾要素についても候補を列挙する
# 		    my $entityTag = $1;
# 		    if ($entityTagList->{$entityTag}) {
# 			printf("%s\tsuf\t%s\n", $classString, $mrphP->genkei);
# 		    }
# 		}
# 	    }
	}
	$bnstIndex += scalar(@mrphList);
    }
}

sub extractCaseFrames {
    my ($knpResult) = @_;
    my $cfList = $cfExtractor->extract($knpResult);

    my $list = {};
    foreach my $cfStruct (@$cfList) {
	my $verb = $cfStruct->{verb};

	# 除外する条件群
	next unless ($verb); # 何かの事故
	next if ($verb eq 'の/の'); # 既知のバグ; 河原さんの修正待ち

	foreach my $struct (@{$cfStruct->{caseList}}) {
	    # formation (GENERALIZED_opt : ) NOUN : CASE %_opt *_opt
	    my @list = split(/\:/, $struct->{string});
	    pop(@list) =~ /^([^\%\*]+)/ and my $case = $1;
	    my $noun = pop(@list);
	    if ($noun && $case) {

		# 除外する条件群
		next if ($case eq 'ノ格');
		next if ($case eq '未格');
		next if ($case eq '修飾');
		next if ($case eq '時間');
		next if ($noun =~ /^\<.+\>$/); # <時間>, <補文> など
		next if ($noun =~ /(a|v)$/); # 名詞化
		next if (index ($noun, '+') >= 0); # 複合語

		my $caseMrph = &grepMrphFromString($noun, $struct->{bnst});
		unless (defined($caseMrph)) { # ASSERT
		    printf STDERR ("something wrong, %s %s\n", $verb, $struct->{string});
		    print STDERR ($struct->{bnst}->spec, "\n");
		    next;
		}

		# 格解析をやった場合には、
		# 一つの形態素が複数の格スロットに入ることがある
		push(@{$list->{refaddr ($caseMrph)}}, {
		    cf => "$verb:$case",
		    bnst => $struct->{bnst},
		    mrph => $caseMrph,
		});
	    }
	}
    }
    return $list;
}

sub extractNounCaseFrames {
    my ($knpResult) = @_;

    my $ncfList = {};
    foreach my $bnst (reverse($knpResult->bnst)) {
	# Ｂの条件
        #
        # 1. 係:ガ格、係:ヲ格、係:ニ格、係:デ格、係:ヘ格、係:マデ格 or
        #    係:未格、かつ、<ハ>はたは<モ>
        next unless ($bnst->fstring =~ /<係:(?:ガ|ヲ|ニ|デ|ヘ|マデ)格>/ ||
                     ($bnst->fstring =~ /<係:未格>/ &&
                      $bnst->fstring =~ /<(?:ハ|モ)>/));
        # 2. 「名詞相当語(形式名詞は除く)+助詞」となる文節
	my $mrph = $bnst->mrph(-2);
	next unless (defined($mrph)); # 文節内に格要素だけの変なデータがある
        next if ($mrph->fstring !~ /<名詞相当語>/ ||
                 $mrph->bunrui eq "形式名詞");
        
        # next unless ($bnst->fstring =~ /<正規化代表表記:(.*?)>/);
        # my $b = $1;

        # ＡのＢの場合
	my $bnstP = $bnst->{_prev};
        next unless (defined($bnstP) && $bnstP->fstring =~ /<係:ノ格>/);
	next if ($bnstP->fstring =~ /<指示詞>/);
	# 追加制約: 文節の途中に閉じ括弧があるゴミを除外
	next if ($bnstP->fstring =~ /\<括弧終\>/
		 && (grep { $_->fstring =~ /\<括弧終\>/  } ($bnstP->tag (-1)->mrph)) <= 0);

	my $a = $cfExtractor->getCaseComponentsContent($bnst, $bnstP, undef, 0);
	next unless ($a);
	next if ($a eq '<補文>');
	my $b = $cfExtractor->getCaseComponentsContent($bnst, $bnst, undef, 0);
	next unless ($b);
        
        printf("*%s %s:名 %s:ノ格\n", $knpResult->id, $b, $a) if ($opt->{debug});

	unless (index ($a, '+') >= 0) {
	    $b = &getGeneralizedNoun($b, $bnst);
	    my $caseMrph = &grepMrphFromString($a, $bnstP);
	    if ($b && $caseMrph) {
		$ncfList->{refaddr($caseMrph)} = {
		    type => 'ncf1',
		    noun => $a,
		    feature => $b
		};
	    }
	}
	unless (index($b, '+') >= 0) {
	    $a = &getGeneralizedNoun($a, $bnstP);
	    my $caseMrph = &grepMrphFromString($b, $bnst);
	    if ($a && $caseMrph) {
		$ncfList->{refaddr($caseMrph)} = {
		    type => 'ncf2',
		    noun => $b,
		    feature => $a
		};
	    }
	}
    }
    return $ncfList;

}

# 指示詞に連体修飾された要素
sub extractDemoModifiee {
    my ($knpResult) = @_;

    my $demoList = {};
    foreach my $bnst ($knpResult->bnst) {
	my $fstring = $bnst->fstring;
	next unless ($fstring =~ /\<連体詞形態指示詞\>/);
	next unless ($fstring =~ /\<主辞代表表記\:([^\>]+)\>/);
	my $feature = $1;

	# 間に要素が挟まる場合はとりあえず除外
	my $bnstN = $bnst->{_next};
        next unless (defined($bnstN) && $bnst->parent == $bnstN);

	my $nounString = $cfExtractor->getCaseComponentsContent($bnst, $bnstN, undef, 0);
	next unless ($nounString);
	next if (index($nounString, '+') >= 0);

	if ($opt->{debug}) {
	    printf("## demo %s %s %s\n", $knpResult->id,
		   join ('+', map { $_->midasi } ($bnst->mrph)),
		   join ('+', map { $_->midasi } ($bnstN->mrph)));
	}

	my $caseMrph = &grepMrphFromString($nounString, $bnstN);
	if ($caseMrph) {
	    $demoList->{refaddr($caseMrph)} = {
		type => 'demo',
		noun => $nounString,
		feature => $feature
		};
	}
    }
    return $demoList;
}

# AというB, AといわれるB, AといったB, AといったようなB, etc
sub extractToIuPattern {
    my ($knpResult) = @_;

    my $callList = {};
    foreach my $bnst (reverse($knpResult->bnst)) {
	# やっつけの blacklist
	# 本当は white list にすべき

	my $fstring = $bnst->fstring;
	next unless ($fstring =~ /\<係\:ト格\>/);
	# とは, とも を排除
	next unless ($bnst->mrph(-1)->genkei eq 'と');
	next if ($fstring =~ /\<引用内文末\>/ || $fstring =~ /\<補文\>/
		 || $fstring =~ /\<用言\:/
		 || $fstring =~ /\指示詞\>/ || $fstring =~ /\<形副名詞\>/);
	next unless (scalar($bnst->child) <= 0); # 修飾されていない

	my $bnstN = $bnst->{_next};
        next unless (defined($bnstN));
	my $fstringN = $bnstN->fstring;
	next unless (index($fstringN, '<正規化代表表記:言う/いう>') >= 0);
	next unless (index($fstringN, '<連体修飾>') >= 0); # 「言われ」、「といえば」などは連用修飾
	next if (index($fstringN, '<形副名詞>') >= 0); # という__の__
	next if (index($fstringN, '<助詞>') >= 0); # という__か__, という__より__
	next if (index($fstringN, '<否定表現>') >= 0); # といわない
	next if (index($fstringN, '<態:使役>') >= 0); # といわせる
	next if (index($fstringN, '<引用内文末>') >= 0);

	my $bnstNN = $bnstN->{_next};
        next unless (defined($bnstNN) && $bnstN->parent == $bnstNN);
	my $fstringNN = $bnstNN->fstring;
	next unless (index($fstringNN, '<体言>') >= 0);
	next if (index($fstringNN, '<形副名詞>') >= 0); # という他
	next if ($fstringNN =~ /\<係\:ノ格\>/ || $bnst->mrph(-1)->genkei eq 'の'); # 係り先曖昧

	my $a = $cfExtractor->getCaseComponentsContent($bnst, $bnst, undef, 0);
	next unless ($a);
	my $b = $cfExtractor->getCaseComponentsContent($bnst, $bnstNN, undef, 0);
	next unless ($b);
	next if ($a eq $b); # idiom: XというX
	next if (defined($callStopList->{$b})); # stopword

	if ($opt->{debug}) {
	    printf("## %s %s %s %s\n", $knpResult->id,
		   join('+', map { $_->midasi } ($bnst->mrph)),
		   join('+', map { $_->midasi } ($bnstN->mrph)),
		   join('+', map { $_->midasi } ($bnstNN->mrph)));
	}

	unless (index($a, '+') >= 0) {
	    my $caseMrph = &grepMrphFromString($a, $bnst);
	    $b = &getGeneralizedNoun($b, $bnstNN);
	    # BUG: 機能してない JUMAN のバグ: 「。）」などを未定義語にする
	    $b = undef if ($b && $b =~ /[。．、，\）\」\』\＞\］\｝\】]/);
	    if ($b && $caseMrph) {
		$callList->{refaddr($caseMrph)} = {
		    type => 'call',
		    noun => $a,
		    feature => $b
		};
	    }
	}
    }
    return $callList;
}

# 汎化された格要素の処理
sub getGeneralizedNoun {
    my ($str, $bnst) = @_;
    return $str unless (index($str, ':') >= 0);

    my ($generalized, $content) = split(/\:/, $str);
    if ($generalized =~ /^\<数量\>(.*)/) {
	return $generalized if ($1); # <数量> + counter word の場合

	# TODO: 「千１００」など複数個に分離される数詞が汎化されない

	# <数量> のみでも「多数」などは汎化しない
	my $mrph = &grepMrphFromString($content, $bnst);
	return $content unless (defined($mrph)); # ASSERT
	return ($mrph->bunrui eq '数詞')? '<数量>' : $content;
    } elsif ($generalized eq '<時間>' && $bnst->fstring =~ /\<数量\>/) {
	# 「１時間後」などのみ汎化
	my $counter = $cfExtractor->getMrphCounter($bnst);
	if ($counter) {
	    return '<数量>' . $counter;
	}
    } else {
	return $content;
    }
}

sub grepMrphFromString {
    my ($noun, $bnst) = @_;
    for my $mrph (reverse($bnst->mrph)) {
	my $repname = &CaseFrameExtractor::getRepname($mrph);
	if (scalar(grep { $_ eq $repname } split(/\?/, $noun)) > 0) {
	    return $mrph;
	}
    }
    return undef;
}

# 品詞として人名が候補になくても
# 名字 + 名前 + 人名接尾辞 というパターンに合致したら怪しい
sub extractPersonalNames {
    my ($knpResult) = @_;

    my $rv = {};
    foreach my $bnst ($knpResult->bnst) {
	my @mrph = $bnst->mrph;
	next unless (scalar(@mrph) >= 3);
	next unless (($mrph[0])->hinsi eq '名詞'
		     && ($mrph[1])->hinsi eq '名詞'
		     && ($mrph[2])->hinsi eq '接尾辞');
	next unless ($personalSuffixList->{($mrph[2])->midasi});
	my $m0 = &matchMrphDoukei($mrph[0], { imis => '人名:日本:姓:' });
	my $m1 = &matchMrphDoukei($mrph[1], { imis => '人名:日本:名:' });
	if (!$m0 && $m1) {
	    $rv->{$mrph[1]->midasi}++;
	    printf('$ %s\n', '!' . $mrph[0]->midasi . $m1->midasi . $mrph[2]->midasi . "\n")
		if ($opt->{debug});
	} elsif ($m0 && !$m1) {
	    $rv->{$mrph[1]->midasi}++;
	    printf('$ %s\n', $m0->midasi . '!' . $mrph[1]->midasi . $mrph[2]->midasi . "\n")
		if ($opt->{debug});
	}
    }
    return $rv;
}

sub matchMrphDoukei {
    my ($mrph, $cond) = @_;

    my @mrphList = ($mrph);
    push(@mrphList, $mrph->doukei);
    foreach my $mrph (@mrphList) {
	my $ok = 1;
	foreach my $key (keys(%$cond)) {
	    unless (index($mrph->{$key}, $cond->{$key}) >= 0) {
		$ok = 0;
		last;
	    }
	}
	return $mrph if ($ok);
    }
    return undef;
}

##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});

    # debug
    Egnee::GlobalConf::set('standardformat-document.use-knp-annotation', 1);

    if ($opt->{both} || $opt->{acquired}) {
	Egnee::GlobalConf::set('juman.rcfile', Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic'));
    }
    Egnee::GlobalConf::set('knp.options', ($opt->{probcase}? '-tab -check' : '-tab -check -dpnd'));
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    use SentenceBasedAnalysisObserverRegistry;
    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;

    $sentenceBasedAnalysisObserverRegistry->addHook(\&onDataAvailable, { getUnique => 1 });

    $cfExtractor = CaseFrameExtractor->new({ probcase => $opt->{probcase}, useRepname => 1, useCompoundNoun => 2, generalize => 1, discardAmbiguity => 1, dump => $opt->{debug} });
}

1;
