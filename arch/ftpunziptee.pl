#!/usr/bin/perl -w
use strict;
use sigtrap;
use Net::FTP;
use Getopt::Std;
use vars qw($opt_u);
die unless defined $ENV{MYGENBANK_DATA};
getopts('u');
my ($file) = @ARGV;
die "$0 [u] <genbank file>\n" unless @ARGV == 1;
my $ftp = new Net::FTP("ncbi.nlm.nih.gov", Timeout => 3600);
$ftp->login("anonymous", "$ENV{USER}\@$ENV{HOST}");
$ftp->cwd("genbank");

my ($INFILE, $OUTFILE);

# updating?
if ($opt_u) {
	$ftp->cwd("daily-nc");
	$INFILE = "$file.flat.gz";
}
else {
	$INFILE = "$file.seq.gz";
}
open(GZIP, "| gunzip - | tee $ENV{MYGENBANK_DATA}/GenBank/$file.seq") or die;
$ftp->get($INFILE, \*GZIP);
close GZIP;
exit(0);
