#!/usr/bin/perl -w

use strict;
use IO::Socket;
use XML::Simple;
use Digest::SHA1;
use POSIX;


sub main {
	my($hostname, $port) = @_;
	
	$port ||= 4871;

	if(!$hostname) {
		print "Usage: wiredclient.pl hostname [port]\n";
		
		exit(2);
	}
	
	my $socket = p7connect($hostname, $port);
	
	print "Performing Wired handshake...\n";
	
	my($os_name, undef, $os_version, undef, $arch) = uname();

	p7sendmessage($socket, "wired.client_info",
		{ name => "wired.info.application.name", content => "$0", type => "string" },
		{ name => "wired.info.application.version", content => "1.0", type => "string" },
		{ name => "wired.info.os.name", content => $os_name, type => "string" },
		{ name => "wired.info.os.version", content => $os_version, type => "string" },
		{ name => "wired.info.arch", content => $arch, type => "string" },
	);
	
	my $message = p7readmessage($socket);
	
	print "Connected to \"$message->{'p7:field'}->{'wired.info.name'}->{'content'}\"\n";
	print "Logging in as guest...\n";
	
	p7sendmessage($socket, "wired.send_login",
		{ name => "wired.user.login", content => "guest", type => "string" },
		{ name => "wired.user.password", content => Digest::SHA1::sha1_hex(""), type => "string" }
	);
	
	$message = p7readmessage($socket);
	
	print "Logged in with user ID $message->{'p7:field'}->{'content'}\n";

	$message = p7readmessage($socket);
	
	print "Listing files at /...\n";
	
	p7sendmessage($socket, "wired.file.list_directory",
		{ name => "wired.file.path", content => "/", type => "string" }
	);
	
	while(($message = p7readmessage($socket))) {
		if($message->{"name"} eq "wired.file.list") {
			print "\t$message->{'p7:field'}->{'wired.file.path'}->{'content'}\n";
		} else {
			last;
		}
	}
	
	print "Exiting\n";
}


sub p7connect {
	my($hostname, $port) = @_;
	
	print "Connecting to $hostname:$port...\n";
	
	my $socket = IO::Socket::INET->new(
		PeerAddr => $hostname,
		PeerPort => $port,
		Proto => "tcp"
	) || die "$!\n";
	
	print "Connected, performing P7 handshake...\n";
	
	p7sendmessage($socket, "p7.handshake.client_handshake",
		{ name => "p7.handshake.version", content => "1.0", type => "string" },
		{ name => "p7.handshake.protocol.name", content => "Wired", type => "string" },
		{ name => "p7.handshake.protocol.version", content => "2.0", type => "string" },
	);
	
	my $message = p7readmessage($socket);
	
	if($message->{"name"} ne "p7.handshake.server_handshake") {
		die "Unexpected message from server\n";
	}
	
	print "Connected to P7 server with protocol $message->{'p7:field'}->{'p7.handshake.protocol.name'}->{'content'} $message->{'p7:field'}->{'p7.handshake.protocol.version'}->{'content'}\n";

	p7sendmessage($socket, "p7.handshake.acknowledge");
	
	return $socket;
}


sub p7sendmessage {
	my $socket = shift;
	my $name = shift;
	
	my $tree;
	$tree->{"name"} = $name;
	$tree->{"xmlns:p7"} = "http://www.zankasoftware.com/P7/Message";
	$tree->{"p7:field"} = \@_;
	
	my $xml = XMLout($tree, "RootName" => "p7:message", XMLDecl => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
	
	print $socket $xml;
}


sub p7readmessage {
	my($socket) = @_;
	
	my $xml;
	my $message;
	
	while(<$socket>) {
		$xml .= $_;
		
		if($xml =~ /<\/p7:message>$/) {
			$message = XMLin($_);
			
			last;
		}
	}
	
	if(!$message) {
		die "No message received from server\n";
	}
	elsif($message->{"name"} eq "wired.error") {
		die "Received Wired error $message->{'p7:field'}->{'content'}\n";
	}
	
	return $message;
}


main($ARGV[0], $ARGV[1]);
