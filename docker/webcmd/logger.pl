#!/usr/bin/perl -wT

use strict;
use File::Temp;
use File::Basename;
use JSON;
use CGI;
use Digest::SHA qw(sha1_hex);
use Digest::MD5 qw(md5_hex);

my(@encryption_methods) = ( "sha1", "md5" );

my($debug) = 0;
{
	my $fh = undef;

	sub debug($) {
		return() unless ( $debug );
		my($str) = shift;
		return(undef) unless(defined($str));
		chomp($str);
		unless ( $fh ) {
			my($log) = "/tmp/debug.log";
			unlink($log);
			open($fh,">>",$log);
		}

		if ( $fh ) {
			print $fh "DEBUG: $str\n"
		}
	}
}


sub cgi() {
	my($q) = CGI->new;
	print $q->header();

	my $newlevel = File::Temp->safe_level( File::Temp::HIGH );
	die "Could not change to high security" if $newlevel != File::Temp::HIGH;

	my($template) = "webcmd";
	my($tempdir) = "/tmp/webcmd";
	my($extension) = "log";

	mkdir($tempdir) unless ( -d $tempdir );
	my $mode = 0700;
	chmod($mode, $tempdir);

	my($script) = $ENV{SCRIPT_NAME};
	debug("script=$script");
	next unless ( defined($script) );
	$script =~ s/\W/_/g;

	my(@names);
	@names = $q->param;
	my(%names) = ();
	my($key) = undef;
	my($size) = 0;
	foreach $key ( @names ) {
		next unless ( defined($key) );
		next unless ( $key =~ /^\w+$/ );
		$size += length($key);

		my($val);
		$val = $q->param($key);
		next unless ( defined($val) );
		next unless ( $val =~ /^\w+$/ );
		$size += length($val);

		exit(1) if ( $size > 10000 );
		$names{lc($key)} = lc($val);

		debug("setting [$key] to [$val]");
	}
	
	if ( $script =~ /^_digest_pl$/ ) {
		print "<PRE>\n";
		my(%res) = ();
		foreach ( @encryption_methods ) {
			my $text = $q->param("$_");
			next unless ( defined($text) );
			$res{$_}=$text;
			my($encrypted) = undef;
			if ( $_ eq "sha1" ) {
				$res{"sha1_hex"}= sha1_hex($text);
			}
			elsif ( $_ eq "md5" ) {
				$res{"md5_hex"}= md5_hex($text);
			}
		}
		my $json = JSON->new->allow_nonref;
		print $json->pretty->encode( \%res );
		print "</PRE>\n";
	}
	elsif ( $script =~ /^_lister_pl$/ ) {
		debug("we are doing lister");
		my $keep = $q->param("keep");
		my $remove = 1;
		if ( defined($keep) ) {
			if ( $keep ) {
				$remove = 1;
			}
			else {
				$remove = 0;
			}
		}
		debug("remove=$remove");

		print "<PRE>\n";
		my($rec) = 0;


		my($dh) = undef;
		unless ( opendir($dh, $tempdir)) {
       			die "Can't open $tempdir $!";
		}


		my(@files) = ();
		while ( my $file = readdir $dh) {
			next unless ( defined($file) );
			next if ( $file eq "." or $file eq ".." );
			if ( $file =~ /(^$template\.\w+\.$extension)/ ) {
				push(@files,$tempdir . "/" . $1);
			}
		}
		closedir $dh;



		foreach ( @files ) {
			my $json = JSON->new->allow_nonref;
			$rec++;
			if ( open(IN,"<$_") ) {
				my($line);
				$line = <IN>;
				close(IN);
				chomp($line);
				my($perl_scalar);
				$perl_scalar = $json->decode( $line );
				if ( defined($perl_scalar) ) {
					my($key);
					my($send) = 0;
					#
					# Loop over argument and match in saved file
					# if we dont find, let the file be...
					#
					foreach $key ( keys %names ) {
						next unless ( defined($key) );
						my($val) = $names{$key};
						next unless ( defined($val) );
						my($comp) = $perl_scalar->{$key};
						unless ( defined($comp) ) {
							$send = 0;
							last;
						}
						if ( lc($val) eq lc($comp) ) {
							$send = 1;
						}
						else {
							$send = 0;
							last;
						}
					}

					#
					# Check for required clear text passwords
					# 
					foreach $key ( "secret","password" ) {
						my($val) = $perl_scalar->{$key};
						next unless ( defined($val) );

						my($comp) = $names{$key};
						unless ( defined($comp) ) {
							$send = 0;
							last;
						}

						if ( lc($val) eq lc($comp) ) {
							$send = 1;
						}
						else {
							$send = 0;
							last;
						}
					}

					#
					# Check for required encrypted password
					#
					foreach $key ( "sha1", "md5" ) {
						my($val) = $perl_scalar->{$key};
						next unless ( defined($val) );

						my($comp) = $names{$key};
						unless ( defined($comp) ) {
							$send = 0;
							last;
						}

						my($digest) = undef;
						if ( $key eq "sha1" ) {
							$digest = sha1_hex($comp);
						}
						elsif ( $key eq "md5" ) {
							$digest = md5_hex($comp);
						}
						if ( $val eq $digest ) {
							$send = 1;
						}
						else {
							$send = 0;
							last;
						}
					}

					unless ( $send ) {
						#
						# skipping removing file, since we dont need this file...
						#
						debug("skipping send...");
					}
					next unless ( $send );
					
					$perl_scalar->{record}=$rec;
					my($json_text);
					$json_text   = $json->encode( $perl_scalar );
					print $json_text . "\n";
				}
			}
			unless ( $keep ) {
				unlink($_);
			}
		}
		print "</PRE>\n";
	}
	elsif ( $script =~ /^_logger_pl$/ ) {
		debug("we are doing logger");

		my($client) = $q->remote_addr();
		exit(0) unless ( defined($client) );
		exit(0) unless ( $client =~ /^\d+\.\d+\.\d+\.\d+$/ );
		$names{client}=$client;
		$names{time}=time;

		my $log = File::Temp->new(
			TEMPLATE => $template . ".XXXXX",
			DIR => $tempdir,
			SUFFIX => ".$extension",
			UNLINK => 0,
		);

		my $json = JSON->new->allow_nonref;
		my $json_text   = $json->encode( \%names );

		print $log $json_text . "\n";
		close($log);
		my $mode = 0666;
		#chmod($mode, $log->filename);
		chmod($mode, $log);
		print "<PRE>\n";
		print $json->pretty->encode( \%names );
		print "</PRE>\n";

		return(0);
	}
	else {
		print "<PRE>\n";
		print "Please try again later\n";
		print "</PRE>\n";
	}
}


#foreach ( sort keys %ENV ) {
#debug( sprintf("%30.30s -> %s",$_,$ENV{$_}) );
#}




delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};   # Make %ENV safer
my($GATEWAY_INTERFACE) = $ENV{GATEWAY_INTERFACE};
if ( defined($GATEWAY_INTERFACE) && $GATEWAY_INTERFACE =~ /CGI/ ) {
	exit(cgi());
}
exit(1);
