#!/usr/bin/perl -w
use strict;
use sigtrap;
die unless defined $ENV{MYGENBANK_DATA};

#########################################
# a script for building blast databases #
#########################################

my $TESTING = 0; # internal switch

my @db = (
	
	##################
	# test databases #
	##################
	{
		-n => "",
		-t => "\"test nucleotide database\"",
		-o => "test_nt",
		-s => "taxid = 9606 and find_in_set('CDS', features) limit 100"
	},
	{
		-p => "",
		-t => "\"test protein database\"",
		-o => "test_aa",
		-s => "taxid = 9606 and mol_type = 'AA' limit 100"
	},


	########################
	# transcript databases #
	########################
	{
		-n => "",
		-t => "\"human transcripts\"",
		-o => "human_tx",
		-s => "taxid = 9606 and mol_type = 'mRNA'"
	},
	{
		-n => "",
		-t => "\"non-human transcripts\"",
		-o => "non_human_tx",
		-s => "taxid != 9606 and mol_type = 'mRNA'"
	},
	{
		-n => "",
		-t => "\"mouse transcripts\"",
		-o => "mouse_tx",
		-s => "taxid = 10090 and mol_type = 'mRNA'"
	},
	{
		-n => "",
		-t => "\"non-mouse transcripts\"",
		-o => "non_mouse_tx",
		-s => "taxid != 10090 and mol_type = 'mRNA'"
	},
	
	{
		-n => "",
		-t => "\"elegans transcripts\"",
		-o => "worm_tx",
		-s => "taxid = 6239 and mol_type = 'mRNA'"
	},
	

	####################
	# genome databases #
	####################
	{
		-n => "",
		-t => "\"finished human genome\"",
		-o => "human_genome_finished",
		-s => "taxid = 9606 and mol_type = 'DNA' and division = 'pri' and find_in_set('HTG', keywords)"
	},
	{
		-n => "",
		-t => "\"draft human genome\"",
		-o => "human_genome_draft",
		-s => "taxid = 9606 and mol_type = 'DNA' and division = 'htg'"
	},
	{
		-n => "",
		-t => "\"finished mouse genome\"",
		-o => "mouse_genome_finished",
		-s => "taxid = 10090 and mol_type = 'DNA' and division = 'rod' and find_in_set('HTG', keywords)"
	},
	{
		-n => "",
		-t => "\"draft mouse genome\"",
		-o => "mouse_genome_draft",
		-s => "taxid = 10090 and mol_type = 'DNA' and division = 'rod'"
	},

	#####################
	# protein databases #
	#####################
	{
		-p => "",
		-t => "\"human proteins\"",
		-o => "human_protein",
		-s => "taxid = 9606 and mol_type = 'AA'"
	},
	{
		-p => "",
		-t => "\"non-human proteins\"",
		-o => "non_human_protein",
		-s => "taxid != 9606 and mol_type = 'AA'"
	},
	{
		-p => "",
		-t => "\"mouse proteins\"",
		-o => "mouse_protein",
		-s => "taxid = 10090 and mol_type = 'AA'"
	},
	{
		-p => "",
		-t => "\"non-mouse proteins\"",
		-o => "non_mouse_protein",
		-s => "taxid != 10090 and mol_type = 'AA'"
	},
	{
		-p => "",
		-t => "\"non-drosophila melanogaster proteins\"",
		-o => "non_fly_protein",
		-s => "taxid != 7227 and mol_type = 'AA'"
	},
	{
		-p => "",
		-t => "\"elegans proteins\"",
		-o => "worm_protein",
		-s => "taxid = 6239 and mol_type = 'AA'"
	},
);

chdir("$ENV{MYGENBANK_DATA}/Blast");
my $mygb_fetch = "$ENV{MYGENBANK_CODE}/bin/mygb_fetch";

foreach my $i (@db) {
	my %p = %$i;
	my $sql = $p{-s};
	delete($p{-s});
	my $db = $p{-o};

	if ($TESTING) {next unless $db =~ /^test/}

	if (-e "$db.xns" or -e "$db.xps") {
		print "$db already exists, skipping\n";
		next;
	}
	else {
		print "processing $db\n";
	}

	# create the fasta database
	print "\tfetching sequences with mygb_fetch\n";
	system("time $mygb_fetch -u \"$sql\" > $db") == 0 or die;

	# create the blast database
	print "\tformatting blast database with xdformat\n";
	my @p = %p;
	system("time xdformat @p $db") == 0 or die;

	# remove the fasta database
	unlink($db);

}
