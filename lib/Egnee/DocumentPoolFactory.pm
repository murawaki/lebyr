package Egnee::DocumentPoolFactory;
#
# create document pool using command-line options
#
use strict;
use warnings;
use utf8;

use IO::File;
use Encode qw/decode_utf8/;

use Egnee::Util qw/dynamic_use/;

# usage: GetOptions($opt, Egnee::DocumentPoolFactory::optionList)
sub optionList {
    return (
	'docdir=s',      # read files in the specified directory
	'tgzfile=s',     # (for backward compatibility)
	'spec=s',        # search result of TSUBAKI (path to perl code)
	'bitext=s',      # Japanese portion of the specified parallel corpus (xml or sorted)
	'kyotocorpus=s', # specify the root path at which 'org' and 'knp' are located
	'rawdata=s',     # raw file
	'knpdata=s',     # knp file

	'tsubakiQuery=s',
	'tsubakiBase=s', # TSUBAKI base URL

	'compressed',    # for rawdata and knpdara
	);
}

sub processSpec {
    my ($opt) = @_;

    # specify query spec by a file
    # NOTE: the perl code override $dictionaryDir, $querySpec and $tsubakiOption
    my ($querySpec, $tsubakiOption, $dictionaryDir);
    my $file = IO::File->new($opt->{spec})
	or die("spec cannot be opened: $opt->{spec}\n");
    $file->binmode(':utf8');
    my $data = join('', $file->getlines);
    $file->close;
    eval($data);
    die if ($@);

    $opt->{dicdir} = $dictionaryDir unless (defined($opt->{dicdir}));
    $opt->{querySpec} = $querySpec;
    $opt->{tsubakiOption} = $tsubakiOption;
}

sub createDocumentPool {
    my ($opt) = @_;

    # backward-compatibility
    $opt->{docdir} = $opt->{tgzfile} if (!defined($opt->{docdir}) && defined($opt->{tgzfile}));

    if ($opt->{docdir}) {
	dynamic_use('DocumentPool::DirectoryBased');
    return DocumentPool::DirectoryBased->new($opt->{docdir}, { debug => $opt->{debug} , tmpdir => $opt->{tmpdir} });
    }
    if ($opt->{spec}) {
	dynamic_use('DocumentPool::Tsubaki');
	return DocumentPool::Tsubaki->new($opt->{querySpec}, $opt->{tsubakiOption});
    }
    if ($opt->{tsubakiQuery}) {
	dynamic_use('DocumentPool::Tsubaki');
	my $query = {}; 
	foreach my $kv (split(/\&/, decode_utf8($opt->{tsubakiQuery}))) {
	    my ($k, $v) = split(/\=/, $kv);
	    $query->{$k} = $v;
	}
	my $topt = { debug => $opt->{debug} };
	$topt->{urlBase} = $opt->{tsubakiBase} if (defined($opt->{tsubakiBase}));
	return DocumentPool::Tsubaki->new($query, $topt);
    }
    if ($opt->{bitext}) {
	dynamic_use('DocumentPool::Bitext');
	return DocumentPool::Bitext->new($opt->{bitext}, { debug => $opt->{debug} });
    }
    if ($opt->{kyotocorpus}) {
	dynamic_use('DocumentPool::KyotoCorpus');
	return DocumentPool::KyotoCorpus->new($opt->{kyotocorpus}, { fullKNPFeatures => 1, debug => $opt->{debug} });
    }
    if ($opt->{rawdata}) {
	dynamic_use('DocumentPool::RawData');
	return DocumentPool::RawData->new($opt->{rawdata}, { debug => 0, compressed => ($opt->{compressed} || 0) });
    }
    if ($opt->{knpdata}) {
	dynamic_use('DocumentPool::KNPData');
	return DocumentPool::KNPData->new($opt->{knpdata}, { debug => 0, compressed => ($opt->{compressed} || 0) });
    }
    return undef;
}

1;
