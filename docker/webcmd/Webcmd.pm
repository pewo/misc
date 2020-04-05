package Object;

use strict;
use Carp;

our $VERSION = 'v0.0.1';

sub set($$$) {
        my($self) = shift;
        my($what) = shift;
        my($value) = shift;

        $what =~ tr/a-z/A-Z/;

        $self->{ $what }=$value;
        return($value);
}

sub get($$) {
        my($self) = shift;
        my($what) = shift;

        $what =~ tr/a-z/A-Z/;
        my $value = $self->{ $what };

        return($self->{ $what });
}

sub new {
        my $proto  = shift;
        my $class  = ref($proto) || $proto;
        my $self   = {};

        bless($self,$class);

        my(%args) = @_;

        my($key,$value);
        while( ($key, $value) = each %args ) {
                $key =~ tr/a-z/A-Z/;
                $self->set($key,$value);
        }

        return($self);
}



package Webcmd;

use strict;
use Carp;
use Data::Dumper;
use File::Path qw(make_path);
use File::Copy;
use File::Basename;
use File::Temp;
use Getopt::Long;

our $VERSION = 'v0.0.1';
our @ISA = qw(Object);
our $debug = 0;

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = {};
        bless($self,$class);

	my($jobtype) = basename($0);
	$jobtype =~ s/\.pl//;

	my(%defaults) = ( 
		jobtype		=> $jobtype,
		ansible		=> "ansible-playbook",
		playbook	=> $jobtype . ".yml",
		tag		=> undef,
		jobdir		=> "/var/tmp/job.d",
		tmpdir		=> "/tmp/job.d",
		ignoredone	=> 0,
		debug		=> $debug,
	);
        my(%hash) = ( %defaults, @_) ;
	$self->set("debug",$hash{debug});
        while ( my($key,$val) = each(%hash) ) {
		my($textval) = $val;
		$textval = "undef" unless ( $val );
		$self->debug(1,"setting $key=[$textval]");
                $self->set($key,$val);
        }

	{
		my($value);
		$value = $self->get("jobtype");
		unless ( defined($value) ) {
			croak("You need to specify 'jobtype' at least...");
		}
		unless ( $value =~ /^\w+$/ ) {
			croak("Bad value for jobtype: $value\n");
		}

		#
		# donedir includes jobdir 
		#
		my($donedir) = $self->get("jobdir") . "/done";
		if ( ! -d $donedir ) {
			make_path($donedir, { verbose => 1, mode => 0755, });
		}
		unless ( -d $donedir ) {
			croak("Can't create donedir $donedir\n");
		}
		$self->set("donedir",$donedir);

		# 
		# check for tmpdir
		#
		$value = $self->get("tmpdir");
		if ( ! -d $value ) {
			make_path($value, { verbose => 1, mode => 0755, });
		}
		if ( ! -d $value ) {
			croak("Can't create tmpdir $value\n");
		}


	}

        return($self);
}

sub debug() {
	my($self) = shift;
	my($level) = shift;
	my($msg) = shift;

	return unless ( defined($level) );
	unless ( $level =~ /^\d$/ ) {
		$msg = $level;
		$level = 1;
	}
	my($debug) = $self->get("debug");
	my ($package0, $filename0, $line0, $subroutine0 ) = caller(0);
	my ($package1, $filename1, $line1, $subroutine1 ) = caller(1);

	if ( $debug >= $level ) {
		chomp($msg);
		my($str) = "DEBUG($level,$debug,$subroutine1:$line0): $msg";
		print $str . "\n";
		return($str);
	}
	else {
		return(undef);
	}
}

sub dojob() {
	my($self) = shift;
	my($jobtype) = $self->get("jobtype");
	my($tmpdir) = $self->get("tmpdir");

	my($log) = $self->get("log");
	my($fh) = undef;
	if ( defined($log) ) {
		if ( open($fh,">",$log) ) {
			$self->debug(1,"Created log at $log");
		}
		else {
			$self->debug(1,"Writing to $log: $!");
		}
	}
	my $inv = File::Temp->new(
                TEMPLATE => "$jobtype.XXXXX",
                DIR => $tmpdir,
                SUFFIX => ".inventory",
                UNLINK => 1,
        );
	my($inventory) = $inv->filename;

	my($start) = time;
	print $fh "Starting $0 at " . localtime($start) . "\n" if ( $fh );

	$self->debug(1,"Creating inventory at $inventory\n");

	print $inv "[$jobtype]\n";

	if ( $fh ) {
		print $fh "\nInventory at $inventory\n";
		print $fh "[$jobtype]\n";
	}
	foreach ( @_ ) {
		chomp;
		print $inv $_ . "\n";
		print $fh $_ . "\n" if ( $fh );
	}
	close($inv);

	my($ansible) = $self->get("ansible");
	my($playbook) = $self->get("playbook");
	my($tag) = $self->get("tag");
	my($cmd) = "$ansible $playbook -i $inventory";
	$cmd .= " -t $tag" if ( defined($tag) );

	if ( $fh ) {
		print $fh "\nCommand:\n";
		print $fh $cmd . "\n";
	}
	$self->debug(1,$cmd);

	#
	# Save STDOUT and STDERR
	# 
	open (my $OLD_STDOUT, '>&', STDOUT);	
	open (my $OLD_STDERR, '>&', STDERR);	

	if ( $fh ) {
		print $fh "\n--- Output start ---\n\n";
		close($fh);
		# reassign STDOUT, STDERR
		open (STDOUT, '>>', $log);
		open (STDERR, '>>', $log);
	}

	# ... 
	# run some other code. STDOUT/STDERR are now redirected to log file
	# ...

	system($cmd);

	# done, restore STDOUT/STDERR
	open (STDOUT, '>&', $OLD_STDOUT);
	open (STDERR, '>&', $OLD_STDERR);

	if ( defined($log) ) {
		if ( open($fh,">>",$log) ) {
			$self->debug(1,"Appending log at $log");
		}
		else {
			$self->debug(1,"Writing to $log: $!");
		}
	}

	if ( $fh ) {
		print $fh "\n--- Output end ---\n";
		my($runtime) = time - $start;
		print $fh "\nRuntime: $runtime seconds\n";
		print $fh "\nDone $0 at " . localtime(time) . "\n";
		close($fh);
	}
	exit(0);
}

sub checkjob() {
	my($self) = shift;
	my($jobdir) = $self->get("jobdir");
	my($jobtype) = $self->get("jobtype");
	my($client) = $self->get("client");
	return(undef) unless ( $client );

	my($job) = $jobdir . "/cmd." . $client . "." . $jobtype;
	$self->debug(1, "Check if there is a $jobtype job for $client in $jobdir");
	if ( -r $job ) {
		$self->debug(1,"Found job $job");
	}
	else {
		$self->debug(1,"Could not find job $job");
	}
	return( -r $job );
}



sub getjob() {
	my($self) = shift;

	my($jobdir) = $self->get("jobdir");
	my($jobtype) = $self->get("jobtype");
	my($donedir) = $self->get("donedir");
	my($ignoredone) = $self->get("ignoredone");
	my($client) = $self->get("client");

	unless ( defined($client) ) {
		$client = "*";
	}

	$self->debug(1,"Searching for jobs: $jobdir/cmd.$client.$jobtype");
	my($job);
	foreach $job ( <$jobdir/cmd.$client.$jobtype> ) {
		$self->debug(1,"job: $job");

		my($done) = $donedir . "/" . basename($job);
		$self->debug(1, "done: $done");
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
			$self->debug(1,"move($job, $done)");
			move($job,$done);
		}
		my($cmd) = $job{command};
		unless ( $cmd ) {
			print "Missing command in $job\n";
			next;
		}
		unless ( $cmd eq $jobtype ) {
			print "This is $cmd which is not an $jobtype job\n";
			next;
		}
		$self->debug(1, "cmd: $cmd");
	
		my($client) = $job{client};
		unless ( $client ) {
			print "Missing client in $job\n";
			next;
		}

		my($log) = $done . ".log";
		$self->set("log",$log);
		$self->debug(1, "client: $client");
	
		$self->dojob($client);
	}
}

sub getopt {
	my($defaults) = shift;
	return(undef) unless ( defined($defaults) );

	my($localdebug) = undef;
	GetOptions (
        	"ansible=s" => \$defaults->{ansible},
        	"client=s" => \$defaults->{client},
        	"debug:i"  => \$localdebug,
        	"ignoredone" => \$defaults->{ignoredone},
        	"playbook=s" => \$defaults->{playbook},
        	"tag=s" => \$defaults->{tag},
	) or die("Error in command line arguments\n");

	if ( defined($localdebug) ) {
        	if ( $localdebug < 1 ) {
	                $localdebug++;
		}
        	$defaults->{debug} = $localdebug;
        }
	else {
        	$defaults->{debug} = 0;
	}

	my(%args) = ();
	foreach ( keys(%$defaults) ) {
		my($val) = $defaults->{$_};
		next unless ( defined($val) );
		$args{$_}=$val;
	}
	return(%args);
}

sub doit() {
	my($self) = shift;
	my($rc) = 0;
	my($client) = $self->get("client");
	if ( defined($client) ) {
		if ( $self->checkjob() ) {
			$rc = $self->getjob();
		}
	}
	else {
		$rc = $self->getjob();
	}
	return($rc);
}
	

1;
