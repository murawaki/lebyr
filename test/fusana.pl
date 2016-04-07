use strict;
use warnings;
use utf8;

use Getopt::Long;
use Storable qw/retrieve/;

use JumanDictionary;
use SuffixList;
use SuffixExtractor;
use MultiClassClassifier;
use MorphemeUsageMonitor;

sub main {
    binmode(STDIN,  ':utf8');
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    my $opt = { rcpath => '/home/murawaki/.jumanrc.bare',
		monitorMin => 100, monitorMax => 500,
		debug => 0 };
    GetOptions($opt,
	       'dicdir=s', # dir at which dic to be augmented is located
	       'rcpath=s', # base jumanrc file
	       'suffix=s', # dir at which suffix database is located
	       'fusana=s', # fusana model
	       'monitorMin=n',
	       'monitorMax=n',
	       'debug');
    die("no dicdir specified\n") unless ( -d $opt->{dicdir} );
    die("no jumanrc specified\n") unless ( -f $opt->{rcpath} );
    die("no suffixdir specified\n") unless ( -d $opt->{suffix} );
    die("no fusana model specified\n") unless ( -f $opt->{fusana} );

    printf("start\n") if ($opt->{debug});
    my $jumanrcPath = $opt->{dicdir} . "/.jumanrc";
    JumanDictionary->makeJumanrc($opt->{rcpath}, $jumanrcPath, $opt->{dicdir});
    my $workingDictionary = JumanDictionary->new($opt->{dicdir},
						 { writable => 1, annotation => 1, doLoad => 1 });
    $workingDictionary->update; # compile juman dic
    printf("dictionary loading done\n") if ($opt->{debug});

    my $suffixList = SuffixList->new($opt->{suffix});
    my $se = SuffixExtractor->new({ markAcquired => 0, excludeDoukei => 0 });
    my $fusanaModel = retrieve($opt->{fusana}) or die;
    my $monitor = MorphemeUsageMonitor->new($workingDictionary, $suffixList,
					    { monitorMax => $opt->{monitorMax}, monitorMin => $opt->{monitorMin},
					      fusanaModel => $fusanaModel, counter => 0, suffix => 1,
					      update => 0, reset => 1,
					      debug => $opt->{debug} });

    use KNP;
    my $knp = KNP->new( -Option => '-tab -assignf', -JumanRcfile => $jumanrcPath );
    while ((my $line = <STDIN>)) {
	chomp($line);
	last unless ($line);

	my $knpResult = $knp->parse($line);
	printf("%s\n", join(' ', map { $_->midasi } ($knpResult->mrph))) if ($opt->{debug});

	$monitor->processKNPResult($knpResult);
    }
    $monitor->onFinished;
    $workingDictionary->saveAsDictionary;
    $workingDictionary->update; # recompile juman dic; need to re-initialize juman
}

unless (caller) {
    &main;
}

1;
