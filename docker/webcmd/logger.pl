#!/usr/bin/perl -w

use strict;
use File::Temp;
use CGI;

sub fixbool($) {
	my($var) = shift;
	if ( defined($var) ) {
		if ( $var ) {
			$var = 1;
		}
		else {
			$var = 0;
		}
	}
	return($var);
}

sub cgi() {
	my($q) = CGI->new;
	print $q->header();

	my($template) = "webcmd";
	my($tempdir) = "/tmp/webcmd";
	my($extension) = "log";

	mkdir($tempdir) unless ( -d $tempdir );
	my $mode = 0777;
	chmod($mode, $tempdir);

	my $command  = $q->param("command");
	exit(0) unless ( defined($command) );
	exit(0) unless ( $command =~ /^\w+$/ );

	my $keep = fixbool($q->param("keep"));
	my $ignoredone  = fixbool($q->param("ignoredone"));

	if ( $command eq "list" ) {
		my($rec) = 0;
		foreach ( <$tempdir/$template.*.$extension> ) {
			$rec++;
			print "REC=$rec FILE=$_ ";
			unless ( open(IN,"<$_") ) {
				print "ERROR=$!\n";
				next;
			}

			my($line);
			$line = <IN>;
			chomp($line);
			print "DATA=$line\n";
			close(IN);
			unless ( $keep ) {
				unlink($_);
			}
		}
	}
	else {
		my($client) = $q->remote_addr();
		exit(0) unless ( defined($client) );
		exit(0) unless ( $client =~ /^\d+\.\d+\.\d+\.\d+$/ );
		my($msg) = "command=$command;client=$client;time=" . time;
		$msg .= ";ignoredone=$ignoredone" if ( defined($ignoredone) );

		my $log = File::Temp->new(
			TEMPLATE => $template . ".XXXXX",
			DIR => $tempdir,
			SUFFIX => ".$extension",
			UNLINK => 0,
		);
	
		chomp($msg);
		print $log $msg . "\n";
		close($log);
		my $mode = 0666;
		chmod($mode, $log->filename);
		return(0);
	}
}


my($GATEWAY_INTERFACE) = $ENV{GATEWAY_INTERFACE};
if ( defined($GATEWAY_INTERFACE) && $GATEWAY_INTERFACE =~ /CGI/ ) {
	exit(cgi());
}
exit(0);
