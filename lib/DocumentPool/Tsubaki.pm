package DocumentPool::Tsubaki;

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use URI::Escape;
use HTTP::Request;
use XML::LibXML;
use IO::File;
use Encode qw/encode_utf8 decode_utf8/;

use Egnee::Logger;
use Document::StandardFormat;

our $tsubakiURLBase = 'http://tsubaki.ixnlp.nii.ac.jp/api.cgi';
our $tsubakiCounter = 0;
our $resultFileName = "result.xml";

=head1 名前

Tsubaki - TSUBAKI で検索した結果を DocumentPool として扱う

=head1 用法

  use Tsubaki;

  # キーワードを入力して検索結果のリストを取得
  my $tsubaki = Tsubaki->new ({
    query => '捕鯨'
    results => 5,
    start => 1
    });
  my $document = $tsubaki->get;

=head1 説明

検索エンジン TSUBAKI にクエリを与えて、検索結果を得る。
また、文書 ID を与えて、該当文書を得る。

とりあえず自分で使うために作ったもので、TSUBAKI を使いこなす上でも汎用化されていない。
例えば、ファイルを作るディレクトリに自由がない。

とうぜん、他の検索エンジンと共通化するようなことは行なっていない。

=head1 メソッド

=head2 new ($query, $opt)

オブジェクトを作成する。

引数
    $query: TSUBAKI にそのまま与える (hash ref)
    $opt: オプション (hash ref)

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	query => shift,
	opt => shift,
	indexStatus => 0 # 0: not yet; 1: available, -1: failed
    };
    # default settings
    $self->{opt}->{urlBase} = $tsubakiURLBase
        unless (defined($self->{opt}->{urlBase}));
    $self->{opt}->{workingDirectory} = "/tmp/tsubaki_${$}_" . $tsubakiCounter++
	unless (defined ($self->{opt}->{workingDirectory}));
    $self->{opt}->{useCache} = 0        unless (defined($self->{opt}->{useCache}));
    $self->{opt}->{cacheData} = 0       unless (defined($self->{opt}->{cacheData}));
    $self->{opt}->{saveData} = 0        unless (defined($self->{opt}->{saveData}));
    $self->{opt}->{lazyEvaluation} = 0  unless (defined($self->{opt}->{lazyEvalutation}));
    $self->{opt}->{retryGet} = 3        unless (defined($self->{opt}->{retryGet}));
    $self->{opt}->{debug} = 0           unless (defined($self->{opt}->{debug}));

    if ($self->{opt}->{cacheData}) {
	`mkdir -p $self->{opt}->{workingDirectory}`;
    }

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    if ($self->{opt}->{useCache}) {
	# use disk cache instead of using real TSUBAKI
	# Note: no self-identity test
	my $file = IO::File->new($self->{opt}->{workingDirectory} . "/$resultFileName")
	    or return ($self->{indexStatus} = -1 && $self);
	my $content = join('', $file->getlines);
	$file->close;
	$self->readIndex($content);
    } elsif (!$self->{opt}->{lazyEvaluation}) {
	$self->getIndex;
    }
    return $self;
}

sub DESTROY {
    my ($self) = @_;

    delete($self->{dom});
    if ($self->{opt}->{cacheData} && !$self->{opt}->{saveData}) {
	`rm -rf $self->{opt}->{workingDirectory}`;
    }
}

# pass query to TSUBAKI to create a document list
# returns indexStatus
sub getIndex {
    my ($self) = @_;

    my $query = $self->{query};
    if (!defined($query->{query})) {
	Egnee::Logger::warn("no keyword specified\n");

	return $self->{indexStatus} = -1;
    }
    my $keyword = encode_utf8($query->{query});
    my $requestString = sprintf("%s?query=%s", $self->{opt}->{urlBase}, uri_escape($keyword));
    while ((my ($key, $val) = each (%$query))) {
	next if ($key eq 'query');
	$requestString .= sprintf("&%s=%s", $key, $val);
    }

    # create UserAgent
    my $ua = LWP::UserAgent->new;
    $ua->timeout(3600);
    $ua->env_proxy;     # specify proxy by ENV
    my $request = HTTP::Request->new(GET => $requestString);
    $request->header('Accept' => 'text/xml');
    my $response = $ua->request($request);

    if (!$response->is_success) {
	Egnee::Logger::warn("request failed\n");

	return $self->{indexStatus} = -1;
    }

    if ($self->{opt}->{cacheData}) {
	my $file = IO::File->new($self->{opt}->{workingDirectory} . "/$resultFileName", 'w');
	$file->print($response->content);
	$file->close;
    }
    return $self->readIndex($response->content);
}

# returns indexStatus
sub readIndex {
    my ($self, $content) = @_;

    my $parser = XML::LibXML->new;
    eval {
	$self->{dom} = $parser->parse_string($content);
    };
    if ($@) {
	Egnee::Logger::warn($@);

	$self->{dom} = undef;
	return $self->{indexStatus} = -1;
    }

    my $resultSetList = $self->{dom}->getElementsByTagName('ResultSet');
    return $self->{indexStatus} = 1 unless (defined($resultSetList));
    $self->{hitCount} = (($resultSetList->get_nodelist)[0])->getAttribute('totalResultsAvailable');

    $self->{idList} = [];
    my $resultList = $self->{dom}->getElementsByTagName('Result');
    return $self->{indexStatus} = 1 unless (defined($resultList));
    foreach my $result ($resultList->get_nodelist) {
	push(@{$self->{idList}}, [$result->getAttribute('Id'), $result->getAttribute('Rank')]);
    }
    return $self->{indexStatus} = 1;
}

sub getHitCount {
    my ($self) = @_;

    return $self->{hitCount} if (defined($self->{hitCount}));
    if ($self->{indexStatus} == 0) {
	$self->getIndex;
    }
    return -1 if ($self->{indexStatus} < 0);
    return $self->{hitCount};
}

# returns a new document
sub get {
    my ($self) = @_;

    if ($self->{indexStatus} == 0) {
	$self->getIndex;
    }
    return $self->{currentID} = undef if ($self->{indexStatus} < 0);

    my $tmp = shift(@{$self->{idList}});
    return $self->{currentID} = undef unless (defined($tmp));
    my ($id, $rank) = @$tmp;

    my $document;
    if ($self->{opt}->{useCache}) {
	$document = Document::StandardFormat->new($self->{opt}->{workingDirectory} . "/$id.xml");
    } else {
	my $requestString = sprintf("%s?format=xml&id=%s", $self->{opt}->{urlBase}, $id);
	# create UserAgent
	my $ua = LWP::UserAgent->new;
	$ua->timeout(3600);
	$ua->env_proxy;     # specify proxy by ENV

	my $retryCount = $self->{opt}->{retryGet};
	my $isSuccess = 0;
	my $response;

	while ($retryCount-- > 0) {
	    my $request = HTTP::Request->new(GET => $requestString);
	    $request->header('Accept' => 'text/xml');
	    $response = $ua->request($request);

	    if ($response->is_success) {
		$isSuccess = 1;
		last;
	    } else {
		Egnee::Logger::warn("get: request failed\n");
	    }
	}
	if (!$isSuccess) {
	    Egnee::Logger::warn("get: requests failed\n");

	    return $self->{currentID} = undef;
	}
	if ($self->{opt}->{cacheData}) {
	    my $file = IO::File->new($self->{opt}->{workingDirectory} . "/$id.xml", 'w');
	    $file->print($response->content);
	    $file->close;
	}
	$self->{currentID} = $id;
	$document = Document::StandardFormat->new(decode_utf8($response->content), { inputType => 'data' });
    }
    $document->setAnnotation('documentID', $id);
    $document->setAnnotation('rank', $rank);
    return $document;
}

sub isEmpty {
    my ($self) = @_;

    return $self->getIndex if ($self->{indexStatus} == 0);
    return 1 if ($self->{indexStatus} < 0);

    return (scalar(@{$self->{idList}}) > 0)? 0 : 1;
}

1;
