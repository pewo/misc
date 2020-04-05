#!/usr/bin/perl -w
#
use strict;
use LWP::Simple;
use Data::Dumper;
use URI;
use Getopt::Long;
use File::Path qw(make_path);

my($url) = 'http://smurf.xname.se:8080/logger.pl';
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
my($content) = get("http://smurf.xname.se:8080/logger.pl");
#my($content) = 'REC=1 FILE=/tmp/webcmd/webcmd.47cBh.log MTIME=1586038323 DATA=2020/04/04 22:12:03 [error] 20#20: *50 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"' . "\n";

#$content .= 'REC=1 FILE=/tmp/webcmd/webcmd.3AQiU.log MTIME=1586039202 DATA=2020/04/04 22:26:41 [error] 20#20: *57 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/postinstall/../bepa/?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"';
my($line);
foreach $line ( split(/\n|\r/,$content ) ) {
	next unless ( $line );
	next unless ( $line =~ /^REC=\d/ );
	chomp($line);

	#
	# get everythin after DATA=
	# Before:
	# REC=1 FILE=/tmp/webcmd/webcmd.47cBh.log MTIME=1586038323 DATA=2020/04/04 22:12:03 [error] 20#20: *50 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"
	# $data = 2020/04/04 22:12:03 [error] 20#20: *50 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"
	#
	my($data) = undef;
	if ( $line =~ /DATA=(.*)/ ) {
		$data = $1;
	}
	next unless ( $data );
	print "data:$data\n" if ( $debug );

	#
	# get everythin after client: in $data
	# $data = 2020/04/04 22:12:03 [error] 20#20: *50 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"
	# $client = 31.209.59.5
	#
	my($client) = undef;
	if ( $data =~ /client:\s+(\d+\.\d+\.\d+\.\d+)/ ) {
		$client = $1;
	}
	next unless ( $client );
	print "client:$client\n" if ( $debug );


	#
	# get URI after /webcmd
	# $data = 2020/04/04 22:12:03 [error] 20#20: *50 access forbidden by rule, client: 31.209.59.5, server: , request: "GET /webcmd/autopostinstall?ip=1.2.3.4&name=bepa HTTP/1.1", host: "smurf.xname.se:8080"
	# $cmd = autopostinstall?ip=1.2.3.4&name=bepa
	#
	my($webcmd) = undef;
	if ( $data =~ /GET\s+\/webcmd\/(.*?)\s/ ) {
		$webcmd = $1;
	}
	next unless ( $webcmd );
	print "webcmd: $webcmd\n" if ( $debug );

	#
	# Get the arguments from the URI
	# $cmd = autopostinstall?ip=1.2.3.4&name=bepa
	# %query = {
	#          'name' => 'bepa',
	#          'ip' => '1.2.3.4'
	# };

	#
	my $abs   = URI->new("http://127.0.0.1/$webcmd")->canonical();
	my $cmd = $abs->path();
	$cmd =~ s/\W//g;
	print "cmd $cmd\n" if ( $debug );

	my %query = $abs->query_form;
	my(%args);
	foreach ( keys %query ) {
		$args{uc($_)}=$query{$_};
	}
	print "args: " . Dumper \%args if ( $debug );

	unless ( -d $jobdir ) {
		make_path($jobdir, { verbose => 1, mode => 0755, });
	}
	my($donedir) = $jobdir . "/done";
	unless ( -d $donedir ) {
		make_path($donedir, { verbose => 1, mode => 0755, });
	}
	my($cmdfile) = "cmd." . $client . "." . $cmd ;
	my($jobfile) = $jobdir . "/" . $cmdfile;

	print "jobfile $jobfile\n" if ( $debug );
	if ( -r $jobfile ) {
		print "Client has already initated a $cmd ($jobfile exists)\n";
		next;
	}

	unlink($jobfile);
	delete($args{CLIENT});
	delete($args{COMMAND});
	delete($args{TIME});
	if ( open(my $fh,">>",$jobfile) ) {
		print $fh "CLIENT=$client\n";
		print $fh "COMMAND=$cmd\n";
		print $fh "TIME=" . time . "\n";
		foreach ( sort keys %args ) {
			print $fh "ARG_$_=$args{$_}\n";
		}
		close($fh);
	}
}
		
