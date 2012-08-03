#!/usr/bin/perl -w
use strict;
use sigtrap;

my $count=0;
while ( my $file=<$ENV{MYGENBANK_DATA}/GenBank/*>) {
	print STDERR $file, "\n";
	open(FILE, $file) or die;
	while(<FILE>) {
		$count++ if /^LOCUS/;
	}
}

print "$count GB records\n";

