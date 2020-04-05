#!/usr/bin/perl -w

use strict;
use File::Temp;
use Fcntl qw(:flock SEEK_END);

my($template) = "webcmd";
my($tempdir) = "/tmp/webcmd";
my($extension) = "log";

sub writer($) {
	my($msg) = shift;

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

sub cgi() {
	print "Content-type: text/html\n\n";
	print "<PRE>\n";
	my($rec) = 0;
	foreach ( <$tempdir/$template.*.$extension> ) {
		$rec++;
		my $mtime = (stat($_))[9] || "unknown";
		print "REC=$rec FILE=$_ MTIME=$mtime ";
		unless ( open(IN,"<$_") ) {
			print "ERROR=$!\n";
			next;
		}

		my($line);
		$line = <IN>;
		chomp($line);
		print "DATA=$line\n";
		close(IN);
		unlink($_);
	}
	print "</PRE>\n";
}

sub parser($) {
	my($error_log) = shift;
	#
	# Wait here until there is an error file
	#
	while ( ! -r $error_log ) {
		sleep(10);
	}

	#
	# Open a tail to read from log
	#
	unless ( open(POPEN,"/usr/bin/tail -f $error_log|") ) {
		die "could not start tail on $error_log: $!";
	}
	while ( <POPEN> ) {
		#2020/04/04 17:45:59 [error] 19#19: *1 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall HTTP/1.1", host: "smurf.xname.se:8080"
		print "GOT: $_";
		writer($_);
	}
	close(POPEN);
	return(0);
}

mkdir($tempdir) unless ( -d $tempdir );
my $mode = 0777;
chmod($mode, $tempdir);

my($GATEWAY_INTERFACE) = $ENV{GATEWAY_INTERFACE};
if ( defined($GATEWAY_INTERFACE) && $GATEWAY_INTERFACE =~ /CGI/ ) {
	cgi();
	exit(0);
}
else {
	my $pid = fork;

	if (!defined $pid) {
    		die "Cannot fork: $!";
	}
	elsif ($pid == 0) {
    		# client process
		my($error_log) = "/tmp/webcmd.log";
		parser($error_log);
    		exit 0;
	}
	else {
		exit(0);
	}
}

