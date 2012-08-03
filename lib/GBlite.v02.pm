################################################################################
# GBlite
################################################################################
package GBlite;
use strict;
use DataBrowser;

###################
# Package globals #
###################

# Month - for converting GenBank date format to numeric format
my %Month = (
	JAN=>'01',
	FEB=>'02',
	MAR=>'03',
	APR=>'04',
	MAY=>'05',
	JUN=>'06',
	JUL=>'07',
	AUG=>'08',
	SEP=>'09',
	OCT=>'10',
	NOV=>'11',
	DEC=>'12'
);

sub new {
	my ($class, $fh) = @_;
	if (ref $fh !~ /GLOB/)
		{die "GBlite error: new expects a GLOB reference not $fh\n"}
	my $this = bless {};
	$this->{FH} = $fh;
	$this->{LASTLINE} = "";
	$this->{DONE} = 0;
	return $this;
}

sub nextEntry {
	my ($this) = @_;
	$this->_fastForward or return 0;
	my $FH = $this->{FH};
	
	# These are the fields that will be kept
	my ($locus, $mol_type, $division, $date, $definition, $accession, $version,
	$gi, $keywords, $organism, $features, $sequence);
	
	# get LOCUS, MOL_TYPE, DIVISION, DATE from LOCUS line
	my $locus_line = $this->{LASTLINE};
	my @field = split(/\s+/, $locus_line);
	$date = $field[@field -1];
	my ($day, $month, $year) = split(/\-/, $date);
	$locus    = $field[1];
	$date     = "$year-$Month{$month}-$day";
	$mol_type = $field[4];
	$division = $field[@field -2];

	# get DEFINITION, which may span several lines
	my @def_line;
	while(<$FH>) {
		if (/^ACCESSION/) {
			$this->{LASTLINE} = $_;
			last;
		}
		else {
			push @def_line, $_;
		}
	}
	$definition = join("", @def_line);
	$definition =~ s/\s+/ /g;
	$definition = substr($definition, 11);
	
	# get ACCESSION, VERSION, and GI from the VERSION line
	while(<$FH>) {last if /^VERSION/}
	my $versionline = $_;
	($accession, $version, $gi) =
		$versionline =~ /^\S+\s+(\w+)\.(\d+)\s+GI:(\d+)/;
	if (not defined $gi) {die ">>> $versionline"}
	if (not defined $accession) {die "acc>> $versionline"}
	if (not defined $version)   {die "ver>> $versionline"}
	
	# parse the KEYWORDS, which may span several lines
	my %keyword;
	while(<$FH>) {
		if (/^SOURCE/) {
			$this->{LASTLINE} = $_;
			last;
		}
		else {
			$_ =~ s/[\.;]//g; # remove punctuation
			my @words = split;
			foreach my $word (@words) {
				$keyword{$word}++;
			}
		}
	}
	delete $keyword{KEYWORDS};
	$keywords = [keys %keyword];
	
	# parse the ORGANISM
	while(<$FH>) {last if /^\s+ORGANISM/}
	my $orgline = $_;
	($organism) = $orgline =~ /ORGANISM\s+(.+)/;
	
	# parse the FEATURES
	while(<$FH>) {last if /^FEATURES/} # skip ahead
	my @lines;
	$features = [];
	while(<$FH>) {
		chomp;
		last if /^BASE COUNT|^ORIGIN/;
		next if /^\s*$/;
		if (substr($_, 5, 1) ne ' ' and @lines) {
			push @$features, GBlite::Feature::new(\@lines);
			@lines = ($_);
		}
		else {
			push @lines, $_;
		}
	}
	push @$features, GBlite::Feature::new(\@lines);
	if (@$features == 0) {die "unexpected fatal parsing error\n"}
	
	# parse the SEQUENCE
	<$FH> unless /^ORIGIN/; # throw away origin line
	my @seq;
	while(<$FH>) {
		last if /^\/\//;
		$_ =~ s/\d+//g;
		$_ =~ s/\s+//g;
		push @seq, $_;
	}
	$sequence = join("", @seq);
	$sequence = uc $sequence;
	
	$this->{LASTLINE} = $_;
	
	my $entry = GBlite::Entry::new($locus, $mol_type, $division, $date,
		$definition, $accession, $version, $gi, $keywords, $organism,
		$features, $sequence);

	return $entry;
}

sub _fastForward {
	my ($this) = @_;
	return 0 if $this->{DONE};
	return 1 if $this->{LASTLINE} =~ /^LOCUS/;
	my $FH = $this->{FH};
	while(<$FH>) {
		if ($_ =~ /^LOCUS/) {
			$this->{LASTLINE} = $_;
			return 1;
		}
	}
	return 0 if not defined $_;
	warn "Possible parse error in _fastForward in GBlite.pm\n", $_;
}



################################################################################
# GBlite::Entry
################################################################################
package GBlite::Entry;
use strict;
use DataBrowser;

# Field - these are the fields that will be parsed for every GenBank entry

my @Field = qw(
	LOCUS
	MOL_TYPE
	DIVISION
	DATE
	DEFINITION
	ACCESSION
	VERSION
	GI
	KEYWORDS
	ORGANISM
	FEATURES
	SEQUENCE
);

sub new {
	my $entry = bless {};
	
	($entry->{LOCUS}, $entry->{MOL_TYPE}, $entry->{DIVISION}, $entry->{DATE},
		$entry->{DEFINITION}, $entry->{ACCESSION}, $entry->{VERSION},
		$entry->{GI}, $entry->{KEYWORDS}, $entry->{ORGANISM},
		$entry->{FEATURES}, $entry->{SEQUENCE}) = @_;
	
	my $CONSTRUCTOR_ERROR = 0;
	foreach my $name (@Field) {
		if (not defined $entry->{$name}) {
			$CONSTRUCTOR_ERROR++;
			warn "GBlite::Entry constructor error, $name undefined\n";
		}
	}
	if ($CONSTRUCTOR_ERROR) {browse($entry); exit(1)}

	return $entry;
}

sub locus      {shift->{LOCUS}}
sub mol_type   {shift->{MOL_TYPE}}
sub division   {shift->{DIVISION}}
sub date       {shift->{DATE}}
sub definition {shift->{DEFINITION}}
sub accession  {shift->{ACCESSION}}
sub version    {shift->{VERSION}}
sub gi         {shift->{GI}}
sub keywords   {shift->{KEYWORDS}}
sub organism   {shift->{ORGANISM}}
sub features   {shift->{FEATURES}}
sub sequence   {shift->{SEQUENCE}}
sub length     {length(shift->{SEQUENCE})}

################################################################################
# GBlite::Feature
################################################################################
package GBlite::Feature;
use strict;
use DataBrowser;

sub new {
	my $feature = bless {};
	my ($lines) = @_;
	my $string = join("", @$lines);  # join all lines
	my @part;
	my $last = 0;
	while ($string =~ /(\/\w+=")/g) {
		my $idx = pos($string) - length($1);
		push @part, substr($string, $last, $idx - $last -1);
		$last = $idx;
	}
	push @part, substr($string, $last);
		
	my $key_loc = shift @part;
	my ($key, $location) = $key_loc =~ /^\s+(\S+)\s+(.+)/;
	$location =~ s/\s+//g;
	my $qualifiers;
	foreach my $qual (@part) {
		if ($qual =~ /\S=\S/) {
			my ($key, $value) = $qual =~ /^(\S+)=(.+)/;
			$value =~ s/"//g;
			$value =~ s/\s+$//g;
			$value =~ s/\s+/ /g;
			if (not defined $key) {
				print "$key --> $qual\n";
				print "@$lines\n";
				die "GBlite::Feature constructor error\n";
			}
			if ($key eq 'translation') {$value =~ s/\s+//g}
			$qualifiers->{$key} .= "$value ";
		}
		else {
			$qualifiers->{$key} = "";
		}
	}
	
	$feature->{KEY}        = $key;
	$feature->{LOCATION}   = $location;
	$feature->{QUALIFIERS} = $qualifiers;
	return $feature;
}

sub key        {shift->{KEY}}
sub location   {shift->{LOCATION}}
sub qualifiers {shift->{QUALIFIERS}}

1;


__END__

=head1 NAME

GBlite.pm

=head1 SYNOPSIS

 use GBlite;
 my $genbank = new GBlite(\*STDIN);
 while(my $entry = $genbank->nextEntry) {
   $entry->locus;
   $entry->mol_type;
   $entry->division;
   $entry->date;           # yyyy-mm-dd
   $entry->definition;
   $entry->accession;
   $entry->version;
   $entry->gi;
   $entry->keywords;       # reference to ARRAY
   $entry->organism;
   $entry->features;       # reference to ARRAY
   $entry->sequence;
   
   foreach my $feature (@{$entry->features}) {
     $feature->key;
     $feature->location;
     $feature->qualifiers; # reference to HASH
   }
 }

=head1 DESCRIPTION

GBlite is a package for parsing concatenated GenBank flat files. The GenBank
format is a common format for bioinformatics. Its specification is complicated,
and anyone using this module should at least skim the GenBank release.notes and
the DDJB/EMBL/GenBank feature table specification. These documents are
available from the NCBI.

=head1 AUTHOR

Ian Korf (ikorf@sapiens.wustl.edu, http://sapiens.wustl.edu/~ikorf)

=head1 ACKNOWLEDGEMENTS

This software was developed at Washington Univeristy, St. Louis, MO.

=head1 COPYRIGHT

Copyright (C) 2000 Ian Korf. All Rights Reserved.

=head1 DISCLAIMER

This software is provided "as is" without warranty of any kind.

=cut




