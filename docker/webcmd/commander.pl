#!/usr/bin/perl -w
#
use strict;
use LWP::Simple;
use Data::Dumper;
use URI;
use Getopt::Long;
use File::Path qw(make_path);

my($url) = 'http://smurf.xname.se:8080/logger.pl?command=list';
my($jobdir) = "/var/tmp/job.d";
my($debug) = 0;

GetOptions (
	"url=s" => \$url,    
	"jobdir=s"   => \$jobdir,
        "debug"  => \$debug
) or die("Error in command line arguments\n");

my($usage) = "Usage: $0 --url=<url> --jobdir=<directory> --debug\n";

unless ( $url ) {
	die "Missing url\n$usage\n";
}
unless ( $jobdir ) {
	die "Missing jobdir\n$usage\n";
}

#get("http://smurf.xname.se:8080/webcmd/postinstall");

my($content) = get($url);

#
#REC=1 FILE=/tmp/webcmd/webcmd.G9XCG.log DATA=command=autopostinstall;ignoredone=1;client=172.18.0.1;host=172.18.0.1;time=1586091378
#REC=2 FILE=/tmp/webcmd/webcmd.OHh8Y.log DATA=command=autoprodinstall;ignoredone=1;client=31.209.59.5;host=31.209.59.5;time=1586091399
#

my($line);
my($added) = 0;
foreach $line ( split(/\n|\r/,$content ) ) {
	next unless ( $line );
	next unless ( $line =~ /^REC=\d/ );
	chomp($line);

	print "Parsing $line\n";

	#
	# get everythin after DATA=
	# Before:
	#REC=1 FILE=/tmp/webcmd/webcmd.G9XCG.log DATA=command=autopostinstall;ignoredone=1;client=172.18.0.1;host=172.18.0.1;time=1586091378
	# $data = command=autopostinstall;ignoredone=1;client=172.18.0.1;host=172.18.0.1;time=1586091378
	#
	my($data) = undef;
	if ( $line =~ /DATA=(.*)/ ) {
		$data = $1;
	}
	next unless ( $data );
	print "data:$data\n" if ( $debug );

	#
	# split data to get a key/value hash
	#
	my(%args) = ();
	my($arg);
	foreach $arg ( split(/;/,$data) ) {
		next unless ( defined($arg) );
		next unless ( $arg =~ /=/ );
		my($key,$value) = split(/=/,$arg);
		next unless ( defined($key) );
		next unless ( defined($value) );
		$args{lc($key)}=lc($value);
	}
	
	my($client) = $args{client};
	next unless ( defined($client) );
	next unless ( $client =~ /^\d+\.\d+\.\d+\.\d+$/ );
	print "client:$client\n" if ( $debug );

	my($command) = $args{command};
	next unless ( defined($command) );
	next unless ( $command =~ /^\w+$/ );
	print "command:$command\n" if ( $debug );

	unless ( -d $jobdir ) {
		make_path($jobdir, { verbose => 1, mode => 0755, });
	}
	my($donedir) = $jobdir . "/done";
	unless ( -d $donedir ) {
		make_path($donedir, { verbose => 1, mode => 0755, });
	}
	my($cmdfile) = "cmd." . $client . "." . $command ;
	my($jobfile) = $jobdir . "/" . $cmdfile;

	print "jobfile $jobfile\n" if ( $debug );
	if ( -r $jobfile ) {
		print "Client has already initated a $command ($jobfile exists)\n";
		next;
	}

	unlink($jobfile);
	delete($args{client});
	delete($args{command});
	if ( open(my $fh,">>",$jobfile) ) {
		print $fh "client=$client\n";
		print $fh "command=$command\n";
		print $fh "now=" . time . "\n";
		foreach ( sort keys %args ) {
			print $fh "arg_$_=$args{$_}\n";
		}
		close($fh);
	}
	$added++;
}
		
if ( $added ) {
	exit(0);
}
exit(1);
