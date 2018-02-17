#!/usr/bin/perl
#
#
# NMDC Redirector.
# Just an easy way to redirect users away..
#
# Vlz 2014 / dc.sutemos.lt:9999
# This is free software, free as beer and as freedom
#
#

use strict;
use warnings;
use IO::Socket::INET;
my $scriptVersion = "0.2.2";      # softo versija, hublistu pingeriai sita irgi mato
my $softwareName  = 'redirector'; # kaip hublistu pingeriai identifikuos softa
# auto-flush on socket
$| = 1;
my $hubKey 	  = 'version' . $scriptVersion; #pagal 'rakta' hublistas atpazista softo versija. Sito nekeisti.

# hub'u sarasas, i kuriuos redirektinsim, adresas bus parenkamas atsitiktinai

my @hublist =	(
		'gelmes.net:6666',
		'dc.sutemos.lt:9999',
		'salvija.eu:6666'
		);

# kurio porto klausysis softas
my $listenPort = '4111';
my $redirectIfDataReceived = 0; # 1 - Siusti $ForceMove tik tada, jei gaunamas nors vienas duomenu paketas, 0 - Siusti visuomet.
my $fixNickNames = 1;		# 1 - "pataisyti" nick'us, pvz taskus ir dvitaskius nick'e pakeisti i bruksnius, "dchub://" pakeisti i "lamer", ir pan.

#my $redirectTo = 'gelmes.net:6666';
#my ($host,$port) = split/:/,$redirectTo;
#my $ip = host2ip($host);

# hub name, as hublists see it and topic
my $hubName	= 'redirectorHub';
my $hubTopic	= 'hub has moved!';

######################### GREETING MESSAGE ###################################
my $greetingMessage = '<Redirector>



Sorry, there is no hub, try one from this list:

';
my $address;
foreach $address (@hublist) {
    $greetingMessage .= "             dchub://$address\n";
}
$greetingMessage .= "\n\n|";	# simbolis | gale butinas

##############################################################################

print 
"
DC Redirector script, version: $scriptVersion
Listening port is: $listenPort
Our \"HUB\" name is: '$hubName'
";

print "Our greeting message is:\n'$greetingMessage'\n";

my $socket = new IO::Socket::INET (
    LocalHost => '0.0.0.0',
    LocalPort => $listenPort,
    Proto => 'tcp',
    Listen => 5,
    TimeOut => 2,
    Reuse => 1
);
die "cannot create socket $!\n" unless $socket;
print "server waiting for client connection on port $listenPort\n";

my $counter = 0;
my %attempts;
while(1)
{
# randomize hub 
my  $redirectTo = $hublist[sprintf( "%0.f", rand(@hublist-1) )];

    # waiting for a new client connection
    my $client_socket = $socket->accept();
 
    # get information about a newly connected client
    my $client_address = $client_socket->peerhost();
    my $client_port = $client_socket->peerport();
    my $client_attempt = ++$attempts{"$client_address"};
    print &timestamp();
    printf (" [%04d/%04d] [$client_address:$client_port]", ++$counter, $client_attempt);
 
    # read up to 1024 characters from the connected client
    my $data = '';
    $client_socket->send('$Lock EXTENDEDPROTOCOL_' . $softwareName . ' Pk=' . $hubKey . '|');
#    $client_socket->send('$Lock EXTENDEDPROTOCOL_fakehub Pk=version0.1|');
    my $aborted = 0;
    my $tmp_data = '';
# read timeout...
#	vieni klientai duomenis siuncia vienam pakete, kiti keliuose.. mum reikalingas $nick, jis buna antram pakete (microdc2)
#	taigi, cikla kartojam 2 kartus, su 2 sek. timeout.

#pradziai testas, ar klientas issiunte koki duomenu paketa

    eval {
	local $SIG{ALRM} = sub { $aborted = 1; die 'Did not receive any data in 2 sec.. Aborting';};
	alarm 2;
        $client_socket->recv($tmp_data,1024);
        $data .= $tmp_data;
        alarm 0;
    };
    alarm 0;

# jei pirmu bandymu negavom jokiu duomenu - antru bandymu irgi ju nebus
    if ($aborted != 1) {
	eval {
	    local $SIG{ALRM} = sub { die 'No more data';};
	    alarm 1;
	    for (1..2) {
    		$client_socket->recv($tmp_data,1024);
    		$data .= $tmp_data;
    	    }
	    alarm 0;
	};
    }
    alarm 0;
    
##################

    if ($redirectIfDataReceived != 1) {$aborted = 0};	# siusti $ForceMove visiems ar tik tiems, kurie atsiuncia nors viena duomenu paketa..
    if ($aborted == 0) {

    my @received = split/\|/,$data;
    my @supports;
    my $key;
    my $nick = '';# = "IP:$client_address";
    my $line;
    foreach $line (@received){
	if ($line =~ m/^\$Supports/) {
	    @supports = split/ /,$line;
	    shift @supports;
	}
	if ($line =~ m/^\$ValidateNick/) {
	    ($_,$nick) = split/ /,$line;
	}
	if ($line =~ m/^\$Key/) {
	    $key = substr($line,5);
	}
    }

    if ($nick eq '') { $nick = "IP:$client_address"; $nick =~ tr/\./\-/;}
    elsif ($fixNickNames == 1) {
	$nick =~ s/dchub|https|http/spammer/ig;

	$nick =~ tr/\.:/--/;
    }
    $client_socket->send($greetingMessage);
if ($hubName  ne '') { $client_socket->send('$HubName '  . $hubName  . '|'); };
if ($hubTopic ne '') { $client_socket->send('$HubTopic ' . $hubTopic . '|'); };

    $client_socket->send('$Supports OpPlus NoGetINFO NoHello UserIP2 HubINFO|');
    sleep .1;
    $client_socket->send('$ForceMove ' . "$redirectTo|");
    print " <$nick> \$ForceMove $redirectTo\n";
    } else { 
	print "Disconnected.."; };
	shutdown($client_socket, 1);
    }

$socket->close();

sub host2ip{
    my $address= shift;
    # grab the data using gethostbyname()
    my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname $address;
    my ($a,$b,$c,$d) =  unpack('C4',$addrs[0]);
    return("$a.$b.$c.$d");
}

sub timestamp
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    my $stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
    return ($stamp);
}
