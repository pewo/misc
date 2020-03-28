#!/usr/bin/perl -w

use strict;
use JSON; # imports encode_json, decode_json, to_json and from_json.
use Data::Dumper;

my($json) = JSON->new();
my($tc) = 700;

my(@res) = qw(ok nok assigned old_ok old_nok unknown skipped disabled);

#{"id":"tc003","status":"assigned"},

my(@arr) = ();
my($i) = 0;
while( $tc-- ) {
	my(%hash);
	$hash{id}= sprintf("tc%03.3d",$i);
	my($rand) = int(rand(1+$#res));
	$hash{status}=$res[$rand];
	push(@arr,\%hash);
	$i++;
}
	
print $json->pretty->encode( \@arr );


