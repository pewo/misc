#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;
use NetAddr::IP;
use Socket;
use File::Copy;

my($debug) = undef;

sub read_db($) {
	my($db) = shift;
	my(%db) = ();
	return() unless ( defined($db) );
	my($backup) = $db . ".backup";
	unless ( -r $db ) {
		print "Restoring from backup $backup\n";
		copy($backup,$db) if ( -r $backup );
	}

	unless ( open(DB,"<",$db) ) {
		print "Unable to open $db: $!\n";
		return();
	}
	foreach ( <DB> ) {
		next if ( m/^#/ );
		s/#.*//;
		chomp;
		my($ip,$time,$cmd) = split(/\t/,$_);
		print "debug ip=[$ip] time=[$time] cmd=[$cmd]\n" if ( $debug );
		$db{$ip}{$cmd}=$time;
	}
	return(%db);
}

sub write_db($;@) {
	my($db) = shift;
	my(%hash) = @_;
	return() unless ( defined($db) );
	my($backup) = $db . ".backup";

	unlink($backup);
	move($db,$backup);
	unlink($db);
	unless ( open(DB,">$db") ) {
		return();
	}
	my($key);
	foreach $key ( sort keys %hash )  {
		my($val) = $hash{$key};
		next unless ( defined($val) );
		foreach ( keys %$val ) {
			print DB "$key\t$val->{$_}\t$_\n";
		}
	}
	close(DB);
}

#
# Main
#
my($network) = undef,
my($cluster) = undef,
my($command) = undef;
my($force) = undef;
my($db) = $0 . ".db";
GetOptions (
         "network=s" => \$network,
         "cluster=s" => \$cluster,
         "debug:i"  => \$debug,
         "command=s" => \$command,
         "force" => \$force,
) or die("Error in command line arguments\n");


my($usage) = "Usage: $0 --network=<network> --cluster=<cluster tag> --command=<command to execute> --force --debug\n";
die "Missing network, " . $usage unless ( $network );
die "Missing cluster, " . $usage unless ( $cluster );
die "Missing command, " . $usage unless ( $command );

my $ip = NetAddr::IP->new($network);
die "Cant create NetAddr::IP object from $network, " . $usage unless ( $ip );

my(%db) = read_db($db);
print Dumper(\%db) if ( $debug );

my($addr);
foreach $addr( $ip->hostenum() ) {
   my $iaddr = $addr->aton();
	my $name  = gethostbyaddr($iaddr, AF_INET);
	next unless ( defined($name) );
   next unless ( $name =~ /(\w+)-$cluster/ );
	my($user) = $1;
	next unless ( defined($user) );
   my $uid = getpwnam($user);
   next unless ( defined($uid) );
	print "ip: $addr name: $name ($user)\n" if ( $debug );

	my($cmd) = $command . " --ip=$addr --name=$name";

	my($time) = $db{$addr}{$command};
	if ( defined($time) and !defined($force) ) {
		print "Error: '$command' was executed on '$addr' on " . localtime($time) . " ($time)\n";
		print "use the force to force the re-execution of this command ( --force )\n";
		next;
	}
	else {
		$db{$addr}{$command}=time;
		write_db($db,%db);

		print $cmd . "\n";
		system($cmd);
	}
}
