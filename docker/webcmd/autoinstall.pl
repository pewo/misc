#!/usr/bin/perl -w
#
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use File::Temp;

my($jobtype) = "";
my($jobdir) = "/var/tmp/job.d";
my($debug) = 0;
my($ignoredone) = 0;

sub job {
	my $inv = File::Temp->new(
                TEMPLATE => "$jobtype.XXXXX",
                DIR => "/tmp",
                SUFFIX => ".inventory",
                UNLINK => 1,
        );
	my($inventory) = $inv->filename;

	print "Creating inventory at $inventory\n";

	print $inv "[$jobtype]\n";
	foreach ( @_ ) {
		chomp;
		print $inv $_ . "\n";
	}
	close($inv);

	my($playbook) = $jobtype . ".yml";

	my($cmd) = "ansible-playbook $playbook -i $inventory";
	print $cmd . "\n";
	exit(0);
}


GetOptions (
	"jobtype=s"   => \$jobtype,
	"jobdir=s"   => \$jobdir,
	"ignoredone" => \$ignoredone,
        "debug"  => \$debug
) or die("Error in command line arguments\n");

my($usage) = "Usage: $0 --jobtype=<jobtype> --jobdir=<directory> --ignoredone --debug\n";

unless ( $jobtype ) {
	die "Missing jobtype\n$usage\n";
}
unless ( $jobtype =~ /^\w+$/ ) {
	die "Bad jobtype\n$usage\n";
}
unless ( $jobdir ) {
	die "Missing jobdir\n$usage\n";
}
unless ( -d $jobdir ) {
	chdir($jobdir);
	die "$jobdir: $!\n";
}

my($donedir) = $jobdir . "/done/$jobtype";
unless ( -d $donedir ) {
	make_path($donedir, { verbose => 1, mode => 0755, });
}

my($job);
foreach $job ( <$jobdir/cmd.*.$jobtype> ) {
	print "job: $job\n";

	my($done) = $donedir . "/" . basename($job);
	print "done: $done\n";
	unless ( $ignoredone ) {
		if ( -r $done ) {
			print "Client has already initiated an $jobtype\n";
			unlink($job);
			next;
		}
	}

	my(%job) = ();
	if ( open(my $fh,"<",$job) ) {
		foreach ( <$fh> ) {
			chomp;
			my($cmd,$arg) = split(/=/,$_);
			$job{$cmd}=$arg;
		}
		close($fh);
		move($job,$done);
	}
	my($cmd) = $job{COMMAND};
	unless ( $cmd ) {
		print "Missing COMMAND in $job\n";
		next;
	}
	unless ( $cmd eq "$jobtype" ) {
		print "This is not an $jobtype job\n";
		next;
	}
	print "cmd: $cmd\n";

	my($client) = $job{CLIENT};
	unless ( $client ) {
		print "Missing CLIENT in $job\n";
		next;
	}
	print "client: $client\n";


	job($client);
}
		
