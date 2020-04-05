#!/usr/bin/perl -w
#
use strict;

use FindBin;
use lib $FindBin::Bin;
use Webcmd;

my(%defaults) = (
	ansible => "/root/unix-env",
	client => undef,
	debug => 0,
	ignoredone => 1,
	playbook => undef,
	tag => undef,
);

my(%args) = Webcmd::getopt(\%defaults);

my($webcmd) = new Webcmd( %args );

$webcmd->doit();
