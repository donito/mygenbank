#!/usr/bin/perl -w
use strict;
use sigtrap;
my @files = `ls $ENV{MYGENBANK_DATA}/GenBank/*`;
chomp @files;
my %H;
foreach my $file (@files) {
	print STDERR $file, "\n";
	open(FILE, $file) or die;
	while(<FILE>) {
		next unless /^KEYWORDS/;
		$_ =~ s/\W+/ /g;
		my @f = split;
		foreach my $f (@f) {
			$H{$f}++;
		}
	}
}

print "KEYWORDS\n";
delete $H{KEYWORDS};
foreach my $key (sort {$H{$b} <=> $H{$a}} keys %H) {
	print "$key\t$H{$key}\n";
}

