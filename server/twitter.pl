#!/bin/env perl
#
# twitter のテスト
#
use strict;
use warnings;
use utf8;

use Egnee::GlobalConf;
use Encode qw/encode_utf8/;
use Net::Twitter::Lite;
use IO::Socket::INET;
use Unicode::Japanese;
use Dumpvalue;
use Storable qw/retrieve nstore/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {
    debug => 1
};

my $confPath = "/home/murawaki/research/lebyr/server/prefs";
Egnee::Logger::loadFile($confPath);
my $host = Egnee::Logger::get('egnee.host') or die;
my $port = Egnee::Logger::get('egnee.port') or die;

my $myname = 'zeregtsegch';
my $statusFilePath = "/home/murawaki/research/lebyr/data/twitterStatus";
my $EOD = "__EOD__";
my $logBase = '/home/murawaki/public_html/egnee/log';

# follow them even if they do not follow me
my $myFollow = {
    'hazuma' => 1,
    'hiroyuki_ni' => 2,
    'tsuda' => 3,
    'sasakitoshinao' => 4,
    'masanork' => 5,
    'hamano_satoshi' => 6,
    'kaokaokaokao' => 7,
    'kirik' => 8,
    'yto' => 9,
    'dankogai' => 10,
    'kazuyo_k' => 11,
    'kawango' => 12,
    'kohmi' => 13,
    'nojiri_h' => 14,
    'yuzuruu' => 15,
    'danshou' => 16,
    'donguri' => 17,
    'jienotsu' => 18,
    'SamFURUKAWA' => 19,
    'hmikitani' => 20,
    'ToshioOkada' => 21,
    'hirasawa' => 22,
    'takapon_jp' => 23,
    'yukatan' => 24,
    'NHK_PR' => 25,
    'joshigeyuki' => 26,
};

my $API_INTERVAL = 10;
my $BOT_INTERVAL = 5 * 60;

print ("type password:\n"); my $passwd = <STDIN>; chomp($passwd);
my $nt = Net::Twitter::Lite->new
    ( username => $myname,
      password => $passwd,
      source => '',
    );
print STDERR ("started\n") if ($opt->{debug});

my $status = &initStatus($statusFilePath);
my $tweetsProcessed = {};
my $count = 0;
while (1) {
    &processMentions($status, $tweetsProcessed);
    &processTimeline($status, $tweetsProcessed) unless ($count % 2);
    &processFriendChange($status, $tweetsProcessed) unless ($count % 12);

    nstore($status, $statusFilePath);

    $count++;
    print STDERR ("sleep...\n") if ($opt->{debug});
    sleep($BOT_INTERVAL);
}

1;

sub initStatus {
    my ($statusFilePath) = @_;

    my $status;
    eval {
	$status = retrieve($statusFilePath);
    };
    if ($status) {
	return $status;
    } else {
	return {
	    friends => {},
	    followers => {},
	    mentions_since_id => 5040585181, # debug
	};
    }
}

sub processMentions {
    my ($status, $tweetsProcessed) = @_;

    my $sinceId = $status->{mentions_since_id};
    my $mentionsOpt = ($sinceId)? { 'since_id' => $sinceId } : {};

    print STDERR ("collecting mentions\n") if ($opt->{debug});
    print STDERR ("since id is $sinceId\n") if ($sinceId && $opt->{debug});

    my $list;
    eval {
	sleep ($API_INTERVAL);
	$list = $nt->mentions($mentionsOpt);
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return 0;
    }

    if (!$list or scalar(@$list) <= 0) {
	print STDERR ("no new mention found\n") if ($opt->{debug});
	return 1;
    }

    foreach my $struct (sort { $a->{id} <=> $b->{id} } (@$list)) {
	my $text = $struct->{text};
	my $statusId = $struct->{id};
	my $user = $struct->{user}->{'screen_name'};
	next if ($sinceId && $statusId <= $sinceId);

	print STDERR ("got text ($statusId): $text\n") if ($opt->{debug});

	if (!defined($tweetsProcessed->{$statusId})) {
	    &processText($text, { type => 'mention', screenName => $user, userId => $struct->{user}->{id}, statusId => $statusId });
	    $tweetsProcessed->{$statusId} = 1;
	}
    }
    $status->{mentions_since_id} = $list->[0]->{id};
    return 1;
}

sub processTimeline {
    my ($status, $tweetsProcessed) = @_;

    my $sinceId = $status->{timeline_since_id};
    my $timelineOpt = { count => 50 };
    $timelineOpt->{'since_id'} = $sinceId if ($sinceId);

    print STDERR ("collecting new tweets\n") if ($opt->{debug});
    print STDERR ("since id is $sinceId\n") if ($sinceId && $opt->{debug});

    my $list;
    eval {
	sleep($API_INTERVAL);
	$list = $nt->friends_timeline($timelineOpt);
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return 0;
    }

    if (!$list or scalar (@$list) <= 0) {
	print STDERR ("no new tweet found\n") if ($opt->{debug});
	return 1;
    }

    foreach my $struct (sort { $a->{id} <=> $b->{id} } (@$list)) {
	my $text = $struct->{text};
	my $statusId = $struct->{id};
	my $user = $struct->{user}->{'screen_name'};
	next if ($sinceId && $statusId <= $sinceId);
	next if ($user eq $myname);

	print STDERR ("got text ($statusId): $text\n") if ($opt->{debug});

	if (!defined($tweetsProcessed->{$statusId})) {
	    &processText($text, { type => 'new', screenName => $user, userId => $struct->{user}->{id}, statusId => $statusId });
	    $tweetsProcessed->{$statusId} = 1;
	}
    }
    $status->{timeline_since_id} = $list->[0]->{id};
    return 1;
}

sub processFriendChange {
    my ($status, $tweetsProcessed) = @_;

    print STDERR ("updating friends\n") if ($opt->{debug});

    my ($added, $deleted) = &updateFollowers($status);
    return 0 unless (defined ($added));
    my ($toFollow, $toUnfollow) = &updateFriends($status, $added, $deleted);
    return 0 unless (defined($toFollow));

    foreach my $id (keys(%$toUnfollow)) {
	print STDERR ("unfollow $id\n") if ($opt->{debug});
	&unfollow($id);
    }
    foreach my $id (keys (%$toFollow)) {
	print STDERR ("follow $id\n") if ($opt->{debug});
	next unless (&follow($id));

	print STDERR ("check old tweets by $id\n") if ($opt->{debug});
	&processNewFriend($id, $tweetsProcessed);
    }
}

sub processNewFriend {
    my ($userId, $tweetsProcessed) = @_;

    my $list;
    eval {
	sleep($API_INTERVAL);
	$list = $nt->user_timeline({ user_id => $userId, count => 50 });
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return 0;
    }

    if (!$list or scalar (@$list) <= 0) {
	print STDERR ("no old tweet by $userId found\n") if ($opt->{debug});
	return 1;
    }

    foreach my $struct (sort { $a->{id} <=> $b->{id} } (@$list)) {
	my $text = $struct->{text};
	my $statusId = $struct->{id};
	my $user = $struct->{user}->{'screen_name'};

	print STDERR ("got text ($statusId): $text\n") if ($opt->{debug});

	if (!defined($tweetsProcessed->{$statusId})) {
	    &processText($text, { type => 'newFriend', userId => $userId, statusId => $statusId });
	    $tweetsProcessed->{$statusId} = 1;
	}
    }
}

sub processText {
    my ($text, $uopt) = @_;
    $uopt = {} unless (defined($uopt));

    my $textList = &formatInput($text);
    my $rv = '';
    if ($textList) {
	foreach my $formatted (@$textList) {
	    $rv .= &sendText($formatted, $uopt);
	}
    }
    unless ($rv) {
	print STDERR ("nothing to responce\n") if ($opt->{debug});
	if ($uopt->{type} eq 'mention') {
	    $rv = '新しい単語はないと思う。';
	} else {
	    return; # do nothing
	}
    }

    if ($uopt->{type} eq 'mention') {
	my $statusId = $uopt->{statusId};
	my $user = $uopt->{screenName};
	my $reply = sprintf("@%s %s", $user, $rv);
	print STDERR ("sending reply to $user at $statusId: $reply\n") if ($opt->{debug});

	eval {
	    sleep($API_INTERVAL);
	    $nt->update({ status => $reply, 'in_reply_to_status_id' => $statusId });
	};
	if ( $@ ) {
	    print STDERR $@->error, "\n";
	    return 0;
	}
    } else {
	eval {
	    sleep($API_INTERVAL);
	    $nt->update({ status => $rv });
	};
	if ( $@ ) {
	    print STDERR $@->error, "\n";
	    return 0;
	}
    }
    return 1;
}

sub sendText {
    my ($formatted, $uopt) = @_;

    my $data = encode_utf8("$formatted\n");
    print STDERR ("send text to server: $formatted\n") if ($opt->{debug});

    my $socket = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $host, PeerPort => $port);
    unless (defined($socket)) {
	die "cannot send socket\n";
    }

    $socket->autoflush(1);
    $socket->print("TEXT\n");
    $socket->print($data);
    $socket->print("$EOD\n");
    $socket->flush;

    my $id;
    while (my $line = $socket->getline) {
	chomp($line);
	my @args = split(/\s+/, $line);
	my $command = shift(@args);
	if ($command eq 'SET_ID') {
	    $id = $args[0];
	} elsif ($command eq 'ERROR') {
	    $socket->close;
	    return;
	}
    }
    $socket->close;

    my $path = "$logBase/$id";
    my $responce;
    my $count = 1;
    while (1) {
	unless ( -f $path ) {
	    print STDERR ("$path not found...wait for a second\n") if ($opt->{debug});
	    sleep($count++);
	    next;
	}

	my $f = IO::File->new($path, 'r') or die "Cannot open log";
	$f->binmode('utf8');
	while ((my $line = $f->getline)) {
	    $responce .= $line;
	}
	$f->close;
	last;
    }
    print STDERR ("got server responce: $responce\n") if ($opt->{debug});

    return &formatResponce($responce, $uopt);
}

sub formatInput {
    my ($text) = @_;

    return undef unless (&isJapaneseText($text));

    $text =~ s/\@[A-Za-z0-9_]+\:?//g; # username
    $text =~ s/\#[A-Za-z0-9_]+\:?//g; # hashkey
    $text =~ s/s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%\#]+//g; # URL
    $text =~ s/\&amp\;/＆/g; $text =~ s/\&lt\;/＞/g; $text =~ s/\&gt\;/＜/g;
    $text =~ s/^\s+//; $text =~ s/\s+$//; # 先頭と末尾のスペースを除去
    $text =~ s/\s+/　/g; # 全角スペース
    $text = Unicode::Japanese->new($text)->h2z->getu;

    my @tmp = split(/\n+/, $text); # 改行で分割
    my $list = [];
    # RT/QT は後ろから先に
    # TODO: RT/QT の前にスペースを書かない人がいる。
    map { push (@$list, reverse(split(/(?:^|\s+)(?:Ｑ|Ｒ)Ｔ\：?\s+/, $_)) ) } (@tmp);
    for (my $i = 0; $i < scalar(@$list); $i++) {
	my $text = $list->[$i];
	unless ($text) {
	    splice(@$list, $i, 1);
	    $i--;
	}
	if ((my $pos = index($text, '　')) >= 0) {
	    # スペースが適切か
	    my $p = substr($text, $pos - 1, 1) || '';
	    # my $q = substr($text, $pos + 1, 1) || '';
	    if ($p =~ /[。．、，・\！\？\」\』\》\）\］\｝]/) { # || ($p =~ /[Ａ-Ｚａ-ｚ０-９]/ && $q =~ /[Ａ-Ｚａ-ｚ０-９]/)) {
	        my $textA = substr($text, 0, $pos);
	        my $textB = substr($text, $pos + 1);
	        splice(@$list, $i, 1, $textA, $textB);
		# $i will be incremented and $textB will be checked as $text
	    }
	}
    }
    return $list;
}

sub isJapaneseText {
    my ($text) = @_;
    unless ($text =~ /(\p{Hiragana}|\p{Katakana}|\p{Han}|ー)/) {
	# 日本語を含んでいないと駄目
	print STDERR ("no Japanese\n") if ($opt->{debug});	
	return 0;
    }
    return 1;
}

sub formatResponce {
    my ($responce, $uopt) = @_;

    # mention の場合のみ詳細な情報を返す 

    $responce =~ s/\<br\>//g;
    my @lines = split(/\n/, $responce);
    my $first = shift(@lines);
    if ($first =~ /^\|/) { # 解析結果
	my $tmp = [];
	if ($uopt->{type} eq 'mention') {
	    $tmp = \@lines;
	} else {
	    foreach my $line (@lines) {
		next if ($line =~ /怪しいと思う/);
		push(@$tmp, $line);
	    }
	}
	return join('', @$tmp); # 余計な情報
    } else {
	# 怪しい文章
	return ($uopt->{type} eq 'mention')? $first : '';
    }
}

##################################################
#                                                #
#            user-related procedures             #
#                                                #
##################################################
sub updateFollowers {
    my ($status) = @_;

    my $list;
    sleep($API_INTERVAL);
    eval {
	$list = $nt->followers;
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return;
    }

    my $deleted = $status->{followers}; # remainders are those who no longer follow me
    my $new = {};
    my $added = {};
    foreach my $user (@$list) {
	if (&isSpammer($user)) {
	    printf STDERR ("%s (%s) is a spammer; ignored\n", $user->{screen_name}, $user->{id}) if ($opt->{debug});
	    next;
	}

	my $id = $user->{id};
	$new->{$id} = 1;
	if (defined ($deleted->{$id})) {
	    delete ($deleted->{$id});
	} else {
	    $added->{$id} = 1;
	}
    }
    $status->{followers} = $new;
    return ($added, $deleted);
}

sub updateFriends {
    my ($status, $added, $deleted) = @_;

    my $list;
    sleep($API_INTERVAL);
    eval {
	$list = $nt->friends;
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return;
    }

    my $toFollow = $added;
    my $toUnfollow = {};
    my $current = $status->{friends};
    my $new = {};
    foreach my $user (@$list) {
	my $id = $user->{id};
	my $name = $user->{screen_name};
	$new->{$id} = 1;

	if (defined($toFollow->{$id})) {
	    print STDERR "something wrong: $id is to be followed, but is already my friend\n";
	    delete($toFollow->{$id});
	}
	if (defined($deleted->{$id}) && !$myFollow->{$name}) {
	    $toUnfollow->{$id} = 1;
	    delete($deleted->{$id});
	}
    }
    $status->{friends} = $new;
    foreach my $id (keys (%$deleted)) {
	print STDERR "something wrong: $id is to be unfollowed, but is not my friend\n";
    }
    return ($toFollow, $toUnfollow);
}

sub isSpammer {
    my ($user) = @_;

    return 1 if ($user->{followers_count} * 100 < $user->{friends_count});
    return 1 if ($user->{statuses_count} < 2);
    return 0;
}

sub unfollow {
    my ($id) = @_;

    sleep($API_INTERVAL);
    eval {
	$nt->destroy_friend($id);
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return 0;
    }
    return 1;
}

sub follow {
    my ($id) = @_;

    sleep($API_INTERVAL);
    eval {
	$nt->create_friend($id);
    };
    if ( $@ ) {
	print STDERR $@->error, "\n";
	return 0;
    }
    return 1;
}
