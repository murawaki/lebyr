package JumanDictionary;

use strict;
use warnings;
use utf8;

use IO::File;
use IO::Dir;
use Cwd qw/abs_path/;
use File::Basename qw/fileparse/;
use File::Spec;

use Egnee::Logger;
use Egnee::GlobalServices;
use SExpression;
use JumanDictionary::MorphemeEntry;
use JumanDictionary::Rc;

our $updateProgram;
BEGIN {
    # find path of update.sh
    # NOTE: this depends on the package's relative path
    my $myPath = $main::INC{__PACKAGE__ . '.pm'};
    my ($myName, $myDir) = fileparse($myPath);
    $updateProgram = abs_path($myDir . '/../update.sh');
}

# dummy morpheme for an empty dic
our $dummyCode = '(名詞 (普通名詞 ((読み ＬＥＢＹＲダミー)(見出し語 (ＬＥＢＹＲダミー 9.0))(意味情報 "ダミー形態素"))))';


=head1 名前

JumanDictionary - Juman の辞書を読み込む。

=head1 用法

  use JumanDictionary;
  my $jdic = new JumanDictionary ("/home/murawaki/tmp/dic",
                                  { writable => 1, doLoad => 0 });

=head1 説明

Juman の辞書を読み込む。各 entry を JumanDictionary::MorphemeEntry のインスタンスとして形態素リストを作る。続いて、JumanDictionary::MorphemeEntry のインスタンスを見出し語をキーとするハッシュに格納する。

サイズの大きい固定の辞書には JumanDictionary::Static を使う。

=head1 メソッド

=head2 new ($jumanSourceDirectory, $opt)

指定されたディレクトリから dic ファイルを読み込んで初期化。

引数

    $jumanSourceDirectory: Juman の辞書ディレクトリ
    $opt: オプション

      doLoad => 0/1: ファイルをその場で読みにいくか
      annotation => 0/1: JumanDictionary::MorphemeEntry::Annotated か
      writable: 編集可能

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	jumanSourceDirectory => shift,
	midasiList => {},
	meList => [],
	total => 0,     # may decrease (by deletion)
	idCounter => 0, # monotonic increase
	opt => shift
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{opt}->{writable} = 0    unless (defined($self->{opt}->{writable}));
    $self->{opt}->{doLoad} = 1      unless (defined($self->{opt}->{doLoad}));
    $self->{opt}->{annotation} = 0  unless (defined($self->{opt}->{annotation}));
    $self->{opt}->{setDummy} = 1    unless (defined($self->{opt}->{setDummy}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    if ($self->{opt}->{doLoad}) {
	$self->init;
    } elsif ($self->{opt}->{writable} && $self->{opt}->{setDummy}) {
	$self->initWithDummy;
    }
    return $self;
}

sub init {
    my ($self) = @_;

    # annotation
    if ($self->{opt}->{annotation}) {
	my $dicPath = $self->{jumanSourceDirectory} . '/output.dic';

	if ( -f $dicPath ) {
	    use JumanDictionary::MorphemeEntry::Annotated;
	    $self->{mrphList} =
		JumanDictionary::MorphemeEntry::Annotated->readAnnotatedDictionary($dicPath);
	    $self->createMidasiList;
	} else {
	    # fail-safe
	    Egnee::Logger::info("dictionary not found; init with dummy\n");
	    $self->initWithDummy;
	}
    } else {
	$self->loadDictionary($self->{jumanSourceDirectory});
    }
}

sub createMidasiList {
    my ($self) = @_;

    foreach my $me (@{$self->{mrphList}}) {
	my $midasi;
	while (($midasi = each(%{$me->{'見出し語'}}))) {
	    push(@{$self->{midasiList}->{$midasi}}, $me);
	}
	push(@{$self->{meList}}, $me);
	$me->{id} = $self->{idCounter}++ unless ($self->isa('JumanDictionary::Static')); # hack
    }
    $self->{total} += scalar(@{$self->{mrphList}});

    $self->{mrphList} = undef;
}

sub loadDictionary {
    my ($self, $dbasepath) = @_;

    my $dpath = "$dbasepath";
    unless ( -d $dpath ) {
	die("cannot find juman dictionary\n");
    }

    my $d = IO::Dir->new($dpath) or die;
    foreach my $ftmp (sort {$a cmp $b} ($d->read)) {
	next unless ($ftmp =~ /\.dic$/);
	$self->loadEachDictionary("$dpath/$ftmp");
    }
    $d->close;
    $self->{ds} = undef;

    $self->createMidasiList;
}

sub loadEachDictionary {
    my ($self, $dic) = @_;

    Egnee::Logger::info("processing $dic\n");

    unless (defined($self->{ds})) {
	$self->{ds} = SExpression->new({ use_symbol_class => 1, fold_lists => 0 });
	$self->{mrphList} = [];
    }

    my $file = IO::File->new($dic) or die;
    $file->binmode(':utf8');
    # dummy?
    if ($self->isDummyDictionary($file)) {
	$file->close;
	return;
    }

    my $buf = '';
    my $count = 0;
    while ((my $line = $file->getline)) {
	chomp($line);
	$buf .= "$line\n"; $count++;
	my $mspec = $self->evalSExpression($buf);
	next unless ($mspec);

	$buf = ''; # 行数が足りない場合は buffer を flush しない
	push(@{$self->{mrphList}}, @$mspec);
    }
    $file->close;
}

# ファイル一行目が dummyCode かで判別
sub isDummyDictionary {
    my ($self, $fh) = @_;

    my $buf = $fh->getline;
    $fh->seek(0, 0);

    if (index($buf, $dummyCode) >= 0) {
	Egnee::Logger::info("dic is dummy\n");
	return 1;
    }
    return 0;
}

sub evalSExpression {
    my ($self, $buf) = @_;

    my $se;
    eval {
	($se, $buf) = $self->{ds}->read($buf);
    };
    if ($@) {
	return undef;
    }
    my $car = $se->car;
    if (ref($car) eq 'SExpression::Symbol') {
	my $mspec = JumanDictionary::MorphemeEntry->createFromSExpression($se);
	return $mspec;
    }
    return undef;
}

=head2 getMorpheme ($midasi, $constraints)

登録済みの形態素を引く。存在すればリストで返す。なければ undef。

引数
  $midasi: 見出し語
  $constraints (optional): 見出し語以外の制約

=cut
sub getMorpheme {
    my ($self, $midasi, $constraints) = @_;

    my $mes = $self->{midasiList}->{$midasi};
    return undef unless (defined($mes));

    return $mes unless (defined($constraints));

    my $filtered = $self->checkConstraints($mes, $constraints);
    return undef if (scalar(@$filtered) < 0);
    return $filtered;
}

sub checkConstraints {
    my ($self, $mes, $constraints) = @_;

    my @filtered;
  outer:
    foreach my $me (@$mes) {
	# 制約の与え方が微妙
	foreach my $name (keys(%$constraints)) {
	    next outer unless (defined($me->{$name}));
	    # 複数指定
	    if (ref($constraints->{$name}) eq 'HASH') {
		my $flag = 0;
		foreach my $cval (keys(%{$constraints->{$name}})) {
		    if ($me->{$name} eq $cval) {
			$flag = 1;
			last;
		    }
		}
		next outer unless ($flag);
	    } else {
		next outer unless ($me->{$name} eq $constraints->{$name});
	    }
	}
	push(@filtered, $me);
    }
    return \@filtered;
}

=head2 addMorpheme ($me)

形態素を登録する。オプション writable 有効にしている時のみ動作する。
Perl 内部で更新されるだけで、JUMAN の辞書本体には反映されない。

引数
  $me: JumanDictionary::MorphemeEntry のインスタンス

またリストで指定もできる。

=cut
sub addMorpheme {
    my $self = shift(@_);

    unless ($self->{opt}->{writable}) {
	Egnee::Logger::warn("dictionary not writable\n");
	return 0;
    }

    while ((my $me = shift(@_))) {
	Egnee::Logger::dumpValue($me);

	foreach my $midasi (keys (%{$me->{'見出し語'}})) {
	    push(@{$self->{midasiList}->{$midasi}}, $me);
	}
	push(@{$self->{meList}}, $me);
	$me->{id} = $self->{idCounter}++;
	$self->{total}++;
    }
    return 1;
}
=head2 removeMorpheme ($midasi, $constraints)

登録済みの形態素を削除する。削除した個数を返す。

引数
  $midasi: 見出し語
  $constraints (optional): 見出し語以外の制約

=cut
sub removeMorpheme {
    my ($self, $midasi, $constraints) = @_;

    unless ($self->{opt}->{writable}) {
	Egnee::Logger::warn("dictionary not writable\n");
	return 0;
    }

    my $mes = $self->{midasiList}->{$midasi};
    unless (defined($mes)) {
	Egnee::Logger::warn("$midasi not found\n");
	return 0;
    }

    unless (defined($constraints)) {
	foreach my $me (@$mes) {
	    my $id = $me->{id};
	    $self->{meList}->[$id] = undef;
	}
	my $rv = scalar(@$mes);
	delete($self->{midasiList}->{$midasi});

	$self->{total} -= $rv;;
	return $rv;
    }

    my $rv = 0;
  outer:
    for (my $i = 0; $i < scalar(@$mes); $i++) {
	my $me = $mes->[$i];
	my $flag = 1;
	foreach my $name (keys(%$constraints)) {
	    next outer if ($me->{$name} ne $constraints->{$name});
	}
	my $id = $me->{id};
	$self->{meList}->[$id] = undef;
	splice(@$mes, $i, 1);
	$rv++;
    }
    $self->{total} -= $rv;
    return $rv;
}

=head2 clear ()

登録済みの形態素を完全に削除する。

=cut
sub clear {
    my ($self, $midasi, $constraints) = @_;

    unless ($self->{opt}->{writable}) {
	Egnee::Logger::warn("dictionary not writable\n");
	return 0;
    }
    $self->{total} = 0;
    $self->{midasiList} = {};    
    $self->{idCounter} = 0;
    $self->{meList} = [];
}

=head2 saveAsDictionary ()

保持している形態素リストを返す

=cut
sub getAllMorphemes {
    my ($self) = @_;

    my $mrphList = [];
    foreach my $me (@{$self->{meList}}) {
	push(@$mrphList, $me) if (defined ($me)); # 歯抜けの可能性
    }
    return $mrphList;
}

sub getTotal {
    my ($self) = @_;
    return $self->{total};
}

=head2 saveAsDictionary ($fpath)

保持している形態素リストを juman の辞書として書き出す。オプション writable を有効にしている時のみ動作する。

引数
  $fpath: ファイル名 (optional)

=cut
sub saveAsDictionary {
    my ($self, $fpath) = @_;

    return 0 unless ($self->{opt}->{writable});

    # デフォルトの設定
    unless (defined($fpath)) {
	$fpath = $self->{jumanSourceDirectory} . '/output.dic';
    }
    my $mrphList = $self->getAllMorphemes;

    my $file = IO::File->new($fpath, 'w') or die("$!");
    $file->binmode(':utf8');
    if (scalar(@$mrphList) > 0) {
	foreach my $me (@$mrphList) {
	    my $output = $me->serialize;
	    $file->print("$output\n");
	}
    } else {
	$file->print("$dummyCode\n");
    }
    $file->close;
    return 1;
}

=head2 appendSave

形態素の追加。全部を書き換えずにファイル append で対処。
メモリ上で別の MorphemeEntry を書き換えても反映されない。

=cut
sub appendSave {
    my ($self, $me) = @_;

    return 0 unless ($self->{opt}->{writable});

    my $mode = ($self->{total} > 0)? 'a' : 'w'; # dummy が入っている可能性

    $self->addMorpheme($me);

    my $fpath = $self->{jumanSourceDirectory} . '/output.dic';
    my $file = IO::File->new($fpath, $mode) or die("$!");
    $file->binmode(':utf8');
    my $output = $me->serialize;
    $file->print("$output\n");
    $file->close;
    return 1;
}

# 普サナ更新で見出し語が変わる場合の処理
sub updateMidasi {
    my ($self, $me, $updateList) = @_;

    foreach my $tmp (@$updateList) {
	my ($old, $new) = @$tmp;
	my $flag = 0;
	for (my $i = 0; $i < scalar(@{$self->{midasiList}->{$old}}); $i++) {
	    my $me2 = $self->{midasiList}->{$old}->[$i];
	    if ($me == $me2) {
		splice(@{$self->{midasiList}->{$old}}, $i, 1);
		$flag = 1;
		last;
	    }
	}
	unless ($flag) {
	    Egnee::Logger::warn(sprintf("no morpheme entry found: %s (-> %s)\n", $old, $new));
	}
	push(@{$self->{midasiList}->{$new}}, $me);
    }
}

=head2 update

辞書をコンパイルする。
analyzer が登録されている場合には JUMAN も更新。

=cut
sub update {
    my ($self) = @_;

    my $cmd = "$updateProgram -d " . $self->{jumanSourceDirectory};
    my $out = ($self->{opt}->{debug})? '' : '>/dev/null';

    my $output = `$cmd $out 2>&1`;
    Egnee::Logger::info($output);

    # renew Juman
    my $analyzerRegistry = Egnee::GlobalServices::get('analyzer registry');
    if (defined($analyzerRegistry)) {
	my $jumanAdapter = $analyzerRegistry->get('juman');
	if (defined($jumanAdapter)) {
	    $jumanAdapter->update();
	}
    } else {
	Egnee::Logger::warn("analayzer registry not found\n");
    }
}

# 辞書の中身が空だと Juman がエラーを吐くので、ダミーコードで初期化
sub initWithDummy () {
    my ($self) = @_;

    my $fpath = $self->{jumanSourceDirectory} . '/output.dic';
    my $file = IO::File->new($fpath, 'w') or die("$!");
    $file->binmode(':utf8');
    $file->print("$dummyCode\n");
    $file->close;
    $self->update;
}


=head2 makeJumanrc ($baseRcPath, $fpath, $dicDir)

指定された辞書パスを追加した jumanrc をファイルに出力する

    # 辞書のパスを指定
    JumanDictionary->makeJumanrc
    ("/home/murawaki/.jumanrc",
     "/home/murawaki/research/test/dic2/.jumanrc",
     "/home/murawaki/research/test/dic2");

=cut
sub makeJumanrc {
    my ($this, $baseRcPath, $fpath, $dicDir) = @_;

    my $self = (ref($this))? $this : undef;
    unless (defined($dicDir)) {
	return 0 unless (defined($self));
	$dicDir = $self->{jumanSourceDirectory};
    }
    my $absPath = File::Spec->rel2abs($dicDir);

    my $rc = JumanDictionary::Rc->new($baseRcPath);
    $rc->addDic($absPath);
    $rc->saveAs($fpath);
}

1;

