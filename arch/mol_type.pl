#!/usr/bin/perl -w
use strict;
use sigtrap;
my @ls = `ls $ENV{MYGENBANK_DATA}/GenBank`;
chomp @ls;
my %MOL_TYPE;
foreach my $file (@ls) {
	print STDERR ".";
	open(FILE, "$MYGB/$file") or die;
	while(<FILE>) {
		my @field = split;
		if (not defined $field[3]) {print "ERR $file>> @field\n"}
		$MOL_TYPE{$field[3]}++;
	}
	close FILE;
}
print "\n";
foreach my $kind (sort keys %MOL_TYPE) {
	print "$kind\n";
}
