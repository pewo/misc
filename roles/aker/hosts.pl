#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use JSON;

my($debug) = 0;

my($in) = $0 . ".in";
unless ( open(IN,"<$in") ) {
	die "Reading $in: $!\n";
}

my(%hosts);
my(%users);
foreach ( <IN> ) {
	chomp;
	if ( m/^users:/ ) {
		s/^users:\s*//;
		foreach ( split(/\s+/,$_) ) {
			my($user,$hosts) = split(/\s*=\s*/,$_);
			$users{$user}=$hosts
		}
	}
	elsif ( m/^hosts:/ ) {
		s/^hosts:\s*//;
		foreach ( split(/\s+/,$_) ) {
			my($host,$group) = split(/\s*=\s*/,$_);
			$group = "nogroup" unless ( $group );
			$hosts{$host}=$group
		}
	}
}



if ( $debug ) {
	foreach ( sort keys %users ) {
		print "user: $_ ($users{$_})\n";
	}
	
	foreach ( sort keys %hosts ) {
		print "host: $_\n";
	}
}

my(%json);

$json{usergroups}=[];
foreach ( sort keys %hosts ) {
	push($json{usergroups},$_ . "_usr");
}

$json{users}=[];
foreach ( sort keys %users ) {
	my(%u);
	$u{username}=$_;
	$u{keyfile}="~/.ssh/id_rsa";
	$u{usergroup}=[];
	foreach ( split(/\W/,$users{$_}) ) {
		push($u{usergroup},$_ . "_usr");
	}
	push($json{users},\%u);
}

$json{hosts}=[];
foreach ( sort keys %hosts ) {
	my(%h);
	$h{name} = $_;
	$h{hostname} = $_;
	$h{port} = "22";
	$h{usergroups}=[];
	push($h{usergroups},$_ . "_usr");

	$h{hostgroup}=[];
	foreach ( split(/\W/,$hosts{$_}) ) {
		push($h{hostgroup},$_);
	}
	push($json{hosts},\%h);
}

my $json = new JSON;
print $json->pretty->encode( \%json ); 

