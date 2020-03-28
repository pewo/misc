#!/usr/bin/perl -w

use strict;
use JSON; # imports encode_json, decode_json, to_json and from_json.
use Data::Dumper;

my($json) = JSON->new();
my($in) = $0 . ".json";
my($html) = "";
my($maxcol) = 20;


unless ( open(IN,"<$in") ) {
	die "Reading $in: $!\n";
}

my($mtime);
$mtime = (stat($in))[9];
my($diff) = time - $mtime;
my($min) = int($diff / 60);
my($sec) = $diff - $min * 60;
my($age) = sprintf("%dm%ds",$min,$sec);
my($class) = "ok";
if ( $diff > 3600 ) {
	$class = "nok";
}

my($text) = "";
foreach ( <IN> ) {
	$text .= $_;
}

$html .= "<!DOCTYPE html>\n";
$html .= "<html>\n";
$html .= "<head>\n";
$html .= "<title>Page Title</title>\n";
$html .= "<style>\n";
$html .= "body {background-color: powderblue;}\n";
$html .= "h1   {color: blue;}\n";
$html .= "p    {color: red;}\n";
$html .= "table.header { width: 95%; height: 50px; margin-left:auto; margin-right:auto;}\n";
$html .= "table.data   { width: 95%; margin-left:auto; margin-right:auto;}\n";
$html .= "table, th, td { border: 1px solid black;}\n";
$html .= "td { text-align: center;}\n";
$html .= "td.ok       { background-color: rgb(146, 208, 80);  color: rgb(32, 56, 100); }\n";
$html .= "td.nok      { background-color: rgb(255, 0, 0);     color: rgb(32, 56, 100); }\n";
$html .= "td.assigned { background-color: rgb(0, 176, 240);   color: rgb(32, 56, 100); }\n";
$html .= "td.old_ok   { background-color: rgb(32, 56, 100);   color: rgb(146, 208, 80); }\n";
$html .= "td.old_nok  { background-color: rgb(32, 56, 100);   color: rgb(255, 0, 0); }\n";
$html .= "td.unknown  { background-color: rgb(32, 56, 100);   color: rgb(0, 176, 240); }\n";
$html .= "td.skipped  { background-color: rgb(32, 56, 100);   color: rgb(127, 127, 127); }\n";
$html .= "td.disabled { background-color: rgb(127, 127, 127); color: rgb(32, 56, 100); }\n";
$html .= "</style>\n";
$html .= "</head>\n";
$html .= "<body>\n";

my(@status) = qw(ok nok assigned old_ok old_nok unknown skipped disabled);


my($data);
$data = $json->decode($text);

my($row) = 1;
my($col) = 0;
my($newrow) = 1;

my($testcases) = "";
my(%sum);
#$testcases .= '<table style="width:100%" "hight:50%">';
#$testcases .= '<table style="height:50%; width:80%">';
$testcases .= '<table class="data">';
my($hp);
foreach $hp ( @$data ) {
	if ( $newrow ) {
		$testcases .= "<tr>\n";
		$newrow = 0;
		$col = 0;
	}
	

	$col++;
	
	my($status) = $hp->{status};
	$sum{$status}++;
	$sum{totalt}++;
	$testcases .= "<td class=\"$status\">\n";
	$testcases .= $hp->{id};
	$testcases .= "</td>\n";

	unless ( $col % $maxcol ) {
		$testcases .= "</tr>\n";
		$newrow = 1;
	}
}

while( $col < $maxcol ) {
	$testcases .= "<td></td>\n";
	$col++;
}
$testcases .= "</tr>\n";
$testcases .= "</table>\n";

my($header) = "<tr>";
$col = 0;
my($totalt) = $sum{totalt};
foreach ( @status ) {
	my($val) = $sum{$_};
	my($proc) = sprintf("%d%%",int((100*$val)/$totalt));
	$col++;
	$header .= "<td width=\"10%\" class=\"" . $_ . "\"> $_ <br> $val($proc) </td>\n";
}

$header .= "<td width=\"10%\" class=\"ok\"> Totalt: $totalt</td>\n";
$header .= "<td width=\"10%\" class=\"$class\"> " . localtime($mtime) . " ($age) </td>\n";
$header .= "</tr>\n";

#my($descr) = '<table style="width:100%">';
my($descr) = '<table class="header">';
$descr .= $header . "\n</table>\n";

#my($stats) = '<table style="width:100%"><tr>';
#my($totalt) = $sum{totalt};
#foreach ( @status ) {
#	my($val) = $sum{$_};
#	my($proc) = sprintf("%d%%",int((100*$val)/$totalt));
#	$stats .= "<td width=\"10%\" class=\"$_\"> $_: $val($proc) </td>\n";
#}
#$stats .= "<td width=\"10%\" class=\"ok\"> totalt: $sum{totalt} </td>\n";
#$stats .= "</tr></table>\n";
	

$html .= $descr;
#$html .= $stats;
$html .= $testcases;

$html .= "</body>\n";
$html .= "</html>\n";

print $html;

