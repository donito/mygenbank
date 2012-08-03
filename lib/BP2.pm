package BP2;
#----------------------------------------------------------#
# Copyright (C) 1997 Washington University, St. Louis, MO. #
# All Rights Reserved.                                     #
#                                                          #
# Author: Ian Korf                                         #
# Send all comments to ikorf@sapiens.wustl.edu             #
#                                                          #
# DISCLAIMER: THIS SOFTWARE IS PROVIDED "AS IS"            #
#             WITHOUT WARRANTY OF ANY KIND.                #
#----------------------------------------------------------#

#----------------------------------------------------------------------
# BP2.pm
#	Blast Processor 2
#	see BP2.README for more documentation
#----------------------------------------------------------------------
use strict;

#------------------------ CLASS VARIABLES -----------------------------

my %multiplier;     # used for displaying alignments

#----------------------------------------------------------------------


#----------------------------------------------------------------------
# Parse()
# Arguments:
#	filename (perhaps with a complete path)
#	optional filtering parameters (see BP2.README for syntax)
#	optional clustering parameters
#	optional 'noseqs' and 'nocalc'
# Returns: 7 references (see BP2.README)
#----------------------------------------------------------------------
sub Parse {
	my ($file, @arg) = @_;
	open(BLAST_REPORT,"<$file") or die "Can't open $file";
	my (@err, $results, $blast, $query, $database, $params,$stats);
	my ($arg, $line, $noseq, $nocalc, $filter, $cluster);
	$noseq = $nocalc = $filter = $cluster = ''; # false on default
	foreach $arg (@arg) {
		if (defined $arg) {
			if ($arg =~ /^Filter/i)
				{($filter)  = $arg =~/Filter\s+(\w.+)/}
			elsif ($arg =~ /^Cluster/i)
				{($cluster) = $arg =~/Cluster\s+(\w.+)/}
			elsif ($arg =~ /^Noseqs/i)
				{$noseq = 'true'}
			elsif ($arg =~ /^Nocalc/i)
				{$nocalc = 'true'}
			elsif ($arg eq '')
				{my $empty_argument_is_okay}
			else {warn "ignoring unknown arg \"$arg\" to Parse()\n"}
		}
	}
	$line = '';
	while (1) {
		if ($line =~ /^>/) {
			$results = extract_results($line,$noseq,
				$nocalc,$filter,$cluster);
			$params = extract_parameters();
			$stats = extract_statistics();
		}
		elsif ($line =~ /^BLAST|^TBLAST/)
			{$blast = extract_blast($line)}
		elsif ($line =~ /^Query=/)
			{$query = extract_query($line)}
		elsif ($line =~ /^Database:/)
			{$database = extract_database($line)}
		elsif ($line =~ /^FATAL|^EXIT/)
			{push(@err,$line)}
		$line = <BLAST_REPORT>;
		last unless defined $line;
	}
	close BLAST_REPORT;
	return ($blast,$database,$query,$results,$params,$stats,\@err);
}

#------------------------- PARSING ROUTINES ---------------------------
sub extract_results {
	#----- this will read all the results until the end of the results
	my ($line,$noseq,$nocalc,$filter,$cluster,$query) = @_;
	my ($i,$gene,$def);
	my @final_result;  # keeps alignments if passing filter and cluster

	#----- some regular expressions defined for readability and reuse
	my $int = '[\d,]+';            # integer with commas allowed
	my $float = '[\de\.\-\+]+';    # floating point
	my $frame = '[\+\-][123]';     # reading frame
	my $seq = '[A-Za-z\-\*\+\|]+'; # seq (nt, aa, '-', '*', '+', '|')

	#----- parser loop begins here
	while (1) {
		my %result;        # holds a set of alignments temporarily
		#----- skip/exit
		next unless $line =~ /\w/;
		last unless $line =~ /^>/;

		#----- get the definition line for the sbjct
		$def = '';
		while ($line !~ /\s+Length = \d+/) {
			$def .= $line;
			$line = <BLAST_REPORT>;
		}
		$def =~ s/\s+/ /g;
		$result{'sbjct_name'} = $def;

		#----- get the length of the sbjct seqeunce
		($result{'sbjct_length'}) = $line =~ /Length = ($int)/;
		$result{'sbjct_length'} =~ s/,//g;


		#----- get the alignments - the real work
		$i = -1;                    # $i is the alignment enumerator
		while (1) {
			# an alignment starts with the flag 'Score'
			# and continues until the next 'Score'
			# or until a new gene encountered '>'
			# this loop will skip or break on the following tags...
			last if $line =~ /^Parameters/;
			$line = <BLAST_REPORT> unless $line =~ /^ Score|^>/;
			last unless defined $line;
			next unless $line =~ /\w/;
			next if $line =~ /Strand HSPs:/;
			next if $line =~ /SCORE_ERROR/;
			last unless $line =~ /^ Score/;

			$i++;
			#----- get the alignment header (score, p, etc)
			($result{'alignment'}[$i]{'score'}) =
				$line =~ /Score = ($int)/;
			($result{'alignment'}[$i]{'bits'}) =
				$line =~ /\(($float) bits\)/;
			($result{'alignment'}[$i]{'expect'}) =
				$line =~ /Expect = ($float)/;
			($result{'alignment'}[$i]{'p'}) =
				$line =~ /[Sum ]*P[\(\d+\)]* = ($float)/;
			($result{'alignment'}[$i]{'group'})  =
				$line =~ /Group = ($int)/;

			#----- get information from the next line too
			$line = <BLAST_REPORT>;
			($result{'alignment'}[$i]{'identities'}) =
				$line =~ /Identities = ($int)/;
			$line =~ /Positives = ($int)\/($int)/;
			$result{'alignment'}[$i]{'positives'} = $1;
			$result{'alignment'}[$i]{'align_length'} = $2;


			#----- getting the frame MY 12/29/97
			if (defined($line)){
				if ($line =~/Frame = /){
					($result{'alignment'}[$i]{'frame'}) = 
					$line =~ /Frame = ($frame)/;
				}
			}
			#----- END M. Y. HACK 12/29/97 


			#----- get the sequence data (sequences and positions)
			#----- sequences can be switched off via 'Noseqs'
			my $first_assigned = 0;
				# to prevent reassigning begin coordinates
			$result{'alignment'}[$i]{'query'} = '' unless $noseq;
			$result{'alignment'}[$i]{'align'} = '' unless $noseq;
			$result{'alignment'}[$i]{'sbjct'} = '' unless $noseq;
			while (1) {
				# this loop will skip or break on the following tags...
				$line = <BLAST_REPORT> unless $line =~ /^Query/;
				next unless $line =~ /\w/;
				last unless $line =~ /^Query/;

				#----- grab coordinates and cat lines
				# Query: first
				$line =~ /^Query:\s+($int)\s+($seq)\s+($int)/;
				$result{'alignment'}[$i]{'q_begin'} = $1
					unless $first_assigned;
				$result{'alignment'}[$i]{'query'}  .= $2
					unless $noseq;
				$result{'alignment'}[$i]{'q_end'}   = $3;

				# Alignment between Query and Sbjct
				my $offset = index($line,$2);
				$line = <BLAST_REPORT>;
				chomp($line);
				$result{'alignment'}[$i]{'align'} .=
					substr($line,$offset)
					unless $noseq;

				# Sbjct: 
				$line = <BLAST_REPORT>;
				$line =~ /^Sbjct:\s+($int)\s+($seq)\s+($int)/;
				$result{'alignment'}[$i]{'s_begin'} = $1
					unless $first_assigned;
				$result{'alignment'}[$i]{'sbjct'}  .= $2
					unless $noseq;
				$result{'alignment'}[$i]{'s_end'}   = $3;

				$first_assigned = 'true';
			}
		}

		#----- put in the calculated values unless 'nocalc' swithed on
		AddCalculatedFields(\%result) unless $nocalc;

		#----- filter sequences if switched on
		if (not $filter)
			{push @final_result,{%result}}
		elsif ($filter and QueryResult(\%result,$filter))
			{push @final_result,{%result}}
		else {my $HSP_was_filtered_out}

		#----- cluster alignments if there's more than one gene
		if ($cluster and defined @final_result and @final_result > 1) {
			my $query = pop(@final_result);
			@final_result = Cluster(\@final_result,$query,$cluster);
		}
	}
	return (\@final_result);
}
sub AddCalculatedFields {
	my ($r) = @_;
	my ($i,$f,$k);
	my ($short5,$short3);

	#----- add number of HSPs
	$r->{'hsp'} = @{$r->{'alignment'}};

	#----- get the gi if possible
	($r->{'gi'}) = $r->{'sbjct_name'} =~ /^>gi\|(\d+)[\|\s]/;
	$r->{'gi'} = 'undefined' unless defined $r->{'gi'};

	#----- Add p (from the first alignment?)
	$r->{'p'} = $r->{'alignment'}[0]{'p'};

	#----- Add score, bits, length, percent_id, percent_sim
	$r->{'length'} = $r->{'bits'} = $r->{'identities'} =
		$r->{'positives'} = $r->{'score'} = 0;
	for($k=0;$k<@{$r->{'alignment'}};$k++) {
		$f = $r->{'alignment'}[$k];
		$r->{'score'} += $f->{'score'};
		if (defined $f->{query})
			{$r->{'length'} += length($f->{query})}
		else
			{$r->{'length'} += abs($f->{'q_begin'} - $f->{'q_end'})}
		$r->{'bits'} += $f->{'bits'} if defined $f->{'bits'};
		$r->{'identities'} += $f->{'identities'};
		$r->{'positives'} += $f->{'positives'};
	 }
	 $r->{'percent_id'} = int($r->{'identities'} / $r->{'length'} *100);
	 $r->{'percent_sim'} = int($r->{'positives'} / $r->{'length'} *100);

	#----- Add start, stop
	@{$r->{'alignment'}} = sort by_pos(@{$r->{'alignment'}});
	 $r->{'start'}  = $r->{'alignment'}[0]{'q_begin'};
	 $r->{'stop'}   = $r->{'alignment'}[$k-1]{'q_end'};

	#----- Add content
#	$short5 = $short3 = 0;
#	$short5 = 'true' if Fcmp($r->{'start'},1,5);
#	$short3 = 'true' if Fcmp($r->{'stop'},$r->{'sbjct_length'},5);
#	if    ($short5 and $short3) {$r->{'content'} = 'island'}
#	elsif ($short5)             {$r->{'content'} = 'short5'}
#	elsif ($short3)             {$r->{'content'} = 'short3'}
#	else                        {$r->{'content'} = 'complete'}

	$r->{'members'} = [];

	return $r;
}
sub extract_blast {
	my ($line) = @_;
	my (%blast);
	$line =~ /^([T]*BLAST.) (.+) \[(.+)\] \[(.+)\]/;
	($blast{'program'},$blast{'version'},$blast{'date'},
		$blast{'build'}) = ($1,$2,$3,$4);
	return \%blast;
}
sub extract_query {
	my ($line) = @_;
	my (%query,$def);
	($def) = $line =~ /Query=\s+(.+)\n/;
	while (1) {
		$line = <BLAST_REPORT>;
		last unless defined $line;
		last if $line =~ /^\s+\([\d,]+ letters\)/;
		$def .= $line
	}
	($query{'length'}) = $line =~ /([\d,]+)/;
	$query{'length'} =~ s/,//g;
	$def =~ s/\s+/ /g;
	$query{'name'} = $def;
	return \%query;
}
sub extract_database {
	my ($line) = @_;
	my (%database);
	($database{'name'}) = $line =~ /Database:\s+(.+)\n/;
	$line = <BLAST_REPORT>;
	$line =~ /([\d,]+) sequences; ([\d,]+) total letters/;
	($database{'sequences'}, $database{'total_letters'}) = ($1,$2);
	$database{'sequences'} =~ s/,//g;
	$database{'total_letters'} =~ s/,//g;
	return \%database;
}
sub extract_parameters {
	#----- this will read until the "Statistics:" flag is seen
	my ($line,@parameter,$query);
	while (1) {
		$line = <BLAST_REPORT>;
		last if $line =~ /^Sta/;
		push(@parameter,$line);
	}
	return \@parameter;
}
sub extract_statistics {
	#----- this will read until EOF
	my ($line,@statistics);
	while (1) {
		$line = <BLAST_REPORT>;
		last unless defined $line;
		push(@statistics,$line);
	}
	return \@statistics;
}

#--------------------- END OF PARSING ROUTINES ------------------------



#----------------- FILTERING AND CLUSTERING ROUTINES ------------------

#----------------------------------------------------------------------
# QueryResult()
# Arguments:
#	a reference to a particular result/gene (set of alignments)
#	filtering parameters
# Returns:
#	0 if the the set of alignments doesn't pass the test
#   1 if it passes the test
# Note:
#	QueryResult() is used for Parse() filtering and is called by
#	FilterResults() for post-parse filtering
#----------------------------------------------------------------------
sub QueryResult {
	my ($r,$filter) = @_;
	my $field = '\w+';
	my $nop = '<|>|<=|>=|==';   # number operator
	my $top = 'eq|ne';          # text operator
	my $pop = '=~|!~';          # pattern operator
	my $text = '"[\w\s]+"';
	my $match = '/[\w\s]+/';
	my $number = '[\de\.\-\+]+';

	#----- parse filtering into eval-able code
	$filter =~ s/($field) ($nop) ($number)/\$r->{'$1'} $2 $3/g;
	$filter =~ s/($field) ($top) ($text)/\$r->{'$1'} $2 $3/g;
	$filter =~ s/($field) ($pop) ($match)/\$r->{'$1'} $2 $3/g;
	return eval($filter);
}

#----------------------------------------------------------------------
# FilterResults()
# Arguments:
#	a reference to the RESULTS data structure
#	filtering parameters (see BP2.README for syntax)
# Returns: a filtered list
#----------------------------------------------------------------------
sub FilterResults {
	my ($r,$filter) = @_;
	my ($i,@keep);
	for($i=0;$i<@$r;$i++) {
		push(@keep,$r->[$i]) if QueryResult($r->[$i],$filter);
	}
	return \@keep;
}

#----------------------------------------------------------------------
# Cluster - called inline by Parse() and also by ClusterResults()
#
# Arguments:
#	a list of alignments
#	an alignment to compare to the list
#	a type of clustering (full, name, gi, est) - see README.BP2
# Returns:
#	a new clustered list
# Note:
#	builds a list as it goes.
#----------------------------------------------------------------------
sub Cluster {
	my ($gene,$query,$type) = @_;
	my ($within,$i,$result,$cluster);
	($type,$within) = $type =~ /type=(\w+)\s+within=(\d+)/;

	#----- compare each "gene" with the query gene
	for($i=0;$i<@$gene;$i++) {
		$result = CompareAlignments($gene->[$i],$query,$within);
		next unless $result;
		if ($type eq 'est') {
			if ($result eq 'identical' or $result =~ /^long/
				or $result eq 'super') {
				$gene->[$i] = Intercalate($gene->[$i],$query,$type);
				return @$gene;
			}
			elsif ($result =~ /^short/ or $result eq 'subset') {
				$gene->[$i] = Intercalate($query,$gene->[$i],$type);
				return @$gene;
			}
			#elsif ($result =~ /^skew/) {not handled yet}
		}
		elsif ($result eq 'identical') {
			$gene->[$i] = Intercalate($gene->[$i],$query,$type);
			return @$gene;
		}
	}
	push(@$gene,$query);  # it wasn't clustered
	return @$gene;
}

#---------------------------------------------------------------------
# Intercalate - called exclusively by Cluster()
#
# Arguments:
#	a parent alignment
#   a daughter alignment (perhaps with many others)
#   a type of clustering
# Returns:
#	an updated parent alignment containing the daughter(s)
#---------------------------------------------------------------------
sub Intercalate {
	my ($p,$d,$type) = @_;
	if ($type eq 'full')
		{push(@{$p->{'members'}},$d)}
	elsif ($type eq 'name')
		{push(@{$p->{'members'}},$d->{'sbjct_name'})}
	elsif ($type eq 'gi')
		{push(@{$p->{'members'}},$d->{'gi'})}
	elsif ($type eq 'est')
		{push(@{$p->{'members'}},$d->{'sbjct_name'})}
	push(@{$p->{'members'}},@{$d->{'members'}})
		if defined $d->{'members'};
	return $p;
}

#---------------------------------------------------------------------
# ClusterResults
#
# Arguments:
#	a reference to a list of alignments
#	type of clustering (full, name, gi, est) and bounds
#		eg. type=est within=20
# Returns: a new clustered list
#---------------------------------------------------------------------
sub ClusterResults {
	my ($r,$type) = @_;
	my ($query,@keep);
	while (@$r > 0) {
		$query = shift @$r;
		@keep = Cluster(\@keep,$query,$type);
	}
	return \@keep;
}

#---------------------------------------------------------------------
# CompareAlignments
#
# Arguments:
#	alignment_set_1
#	alignment_set_2 (the hash ref for each)
#	fuzzy boundary for comparisons
# Returns various values
#	'identical'    alignments are the same
#	'short5'       alignment1 has a shorter 5' end
#	'short3'       alignment1 has a shorter 3' end
#	'long5'        alignment1 has a longer 5' end
#	'long3'        alignment1 has a longer 3' end
#	'subset'       alignment1 is shorter on both ends
#	'super'        alignment1 is longer on both ends
#	'skew5'        alignment1 is longer on 5' and shorter on 3'
#	'skew3'        alignment1 is shorter on 5' and longer on 3'
#	0              alignments do not match internally
#
#---------------------------------------------------------------------
sub CompareAlignments {
	my ($a1,$a2,$fuzzy) = @_;
	my ($i,$begin,$end,$internal_mismatch);

	#----- first check if they have the same number of alignments
	return 0 if scalar @{$a1->{'alignment'}} !=
		scalar @{$a2->{'alignment'}};

	#----- if there's only one alignment, just compare the HSPs
	return CompareHSP($a1->{'alignment'}[0],
		$a2->{'alignment'}[0],$fuzzy) if @{$a1->{'alignment'}} == 1;

	#----- internal alignments MUST match
	#----- there can be at most two non-identical matches - at the ends
	$internal_mismatch = '';
	for($i=1;$i<@{$a1->{'alignment'}}-1;$i++) {
		if (CompareHSP($a1->{'alignment'}[$i],
				$a2->{'alignment'}[$i],$fuzzy) ne 'identical') {
			$internal_mismatch = 'true';
		}
	}
	return 0 if $internal_mismatch;

	#----- alignments match internally, what about their ends
	$begin = CompareHSP($a1->{'alignment'}[0],
		$a2->{'alignment'}[0],$fuzzy);
	$end = CompareHSP($a1->{'alignment'}[@{$a1->{'alignment'}}-1],
		$a1->{'alignment'}[@{$a2->{'alignment'}}-1],$fuzzy);

	#----- ends must be anchored
	return 0 unless $begin eq 'identical' or $begin eq 'short5'
		or $begin eq 'long5';
	return 0 unless $end eq 'identical' or $end eq 'short3'
		or $end   eq 'long3';
	if ($begin eq 'identical' and $end eq 'identical')
		{return 'identical'}
	elsif ($begin eq 'identical' and $end eq 'short3') {return 'short3'}
	elsif ($begin eq 'identical' and $end eq 'long3') {return 'long3'}
	elsif ($begin eq 'short5' and $end eq 'identical') {return 'short5'}
	elsif ($begin eq 'short5' and $end eq 'short3') {return 'subset'}
	elsif ($begin eq 'short5' and $end eq 'long3') {return 'skew3'}
	elsif ($begin eq 'long5' and $end eq 'identical') {return 'long5'}
	elsif ($begin eq 'long5' and $end eq 'short3') {return 'skew5'}
	elsif ($begin eq 'long5' and $end eq 'long3') {return 'super'}
	else {die "funny error"}
}

#---------------------------------------------------------------------
# CompareHSP
#
# Three Arguments:
#	hsp1 hash 'q_begin' and 'q_end'
#	hsp2 hash 'q_begin' and 'q_end'
#	fuzzy boundary
#
# Returns various values (uses Fcmp for comparisons)
#	'identical'    same begin and end
#	'short5'       hsp1 is shorter on the 5' end but anchored at 3'
#	'short3'       ..                     3'                     5'
#	'long5'        ..      longer         5'                     3'
#	'long3'        ..      longer         3'                     5'
#	'subset'       hsp1 is shorter on both ends
#	'super'        hsp1 is longer on both ends
#	'skew5'        hsp1 is longer on 5' and shorter on 3'
#	'skew3'        ..
#	0              hsps do not match
#
#---------------------------------------------------------------------
sub CompareHSP {
	my ($hsp1,$hsp2,$fuzzy) = @_;
	my ($begin,$end,$result);
	my ($strand1,$strand2);

	# this is a strand sensitive function so find the strand
	if ($hsp1->{'q_begin'} < $hsp1->{'q_end'}) {$strand1 = '+'}
	else {$strand1 = '-'}
	if ($hsp2->{'q_begin'} < $hsp2->{'q_end'}) {$strand2 = '+'}
	else {$strand2 = '-'}

	# compare the coordinates
	$begin = Fcmp($hsp1->{'q_begin'}, $hsp2->{'q_begin'}, $fuzzy);
	$end = Fcmp($hsp1->{'q_end'}, $hsp2->{'q_end'}, $fuzzy);

	# produce the results
	if    ($strand1 ne $strand2)        {return 0}
	elsif ($begin ==  1 and $end ==  1) {return 'super'}
	elsif ($begin ==  1 and $end ==  0) {return 'long5'}
	elsif ($begin ==  1 and $end == -1) {return 'skew5'}
	elsif ($begin ==  0 and $end ==  1) {return 'long3'}
	elsif ($begin ==  0 and $end ==  0) {return 'identical'}
	elsif ($begin ==  0 and $end == -1) {return 'short3'}
	elsif ($begin == -1 and $end ==  1) {return 'skew3'}
	elsif ($begin == -1 and $end ==  0) {return 'short5'}
	elsif ($begin == -1 and $end == -1) {return 'subset'}
	else                                {return 0}
}

#-------------- END OF FILTERING AND CLUSTERING ROUTINES -------------



#------------------------ DISPLAY ROUTINES ---------------------------

#---------------------------------------------------------------------
# FormatHSP - requires SetMultiplier() to be called first
#
# Argument: an alignment
# Returns:  a reference to a string (for printing or whatever)
#---------------------------------------------------------------------
sub FormatHSP {
	my ($hsp) = @_;
	my ($k,$f,$m);
	my $out = "\n";
	unless (defined %multiplier) {
		warn "You cannot display HSPs until you've SetMultiplier()\n";
		exit(1);
	}

	my $offset = LastWord($hsp->{sbjct_name},75);
	my $firstline = substr($hsp->{sbjct_name},0,$offset);

	$out .= "$firstline\n";
	$k = $offset;
	while($k < length($hsp->{sbjct_name})) {
		$offset = LastWord($hsp->{sbjct_name},$k+69) - $k;
		$out .= " " x 10 . substr($hsp->{sbjct_name},$k,$offset) . "\n";
		$k += $offset;
	}
	$out .= " " x 11 . "Length = $hsp->{sbjct_length}\n\n";

	for($k=0;$k<@{$hsp->{alignment}};$k++) {
		$f = $hsp->{alignment}[$k];
		my $len = $f->{align_length};
		my $pid = int $f->{identities} / $len * 100;
		my $psim =  int $f->{positives} / $len * 100;
		$out .= " Score = $f->{score} ($f->{bits} bits),";
		$out .= " Expect = $f->{expect}, P = $f->{p}";
		if (defined $f->{group}) {$out .= ", Group = $f->{group}"}
		$out .= "\n";
		$out .= " Identities = $f->{identities}/$f->{align_length}";
		$out .= " ($pid%),";
		$out .= " Positives = $f->{positives}/$f->{align_length}";
		$out .= " ($psim%)\n\n";

		my %strand;
		$strand{query} = $f->{q_begin} < $f->{q_end} ? 1 : -1;
		$strand{sbjct} = $f->{s_begin} < $f->{s_end} ? 1 : -1;

		my ($q_begin,$q_end,$s_begin,$s_end);
		my ($q_seq,$s_seq,$q_len,$s_len,$q_gaps,$s_gaps);
		$q_gaps = $s_gaps = 0;

		for($m=0;$m<length($f->{query});$m+=60) {
			$q_seq = substr($f->{query},$m,60);
			$s_seq = substr($f->{sbjct},$m,60);
			$q_len = length($q_seq);
			$s_len = length($s_seq);

			$q_begin = $f->{q_begin} + $strand{query} *
				$multiplier{query} * ($m - $q_gaps);
			$s_begin = $f->{s_begin} + $strand{sbjct} *
				$multiplier{sbjct} * ($m - $s_gaps);

			$q_gaps += $q_seq =~ tr/-/-/;
			$s_gaps += $s_seq =~ tr/-/-/;

			$q_end = $f->{q_begin} + $strand{query} *
				$multiplier{query} * ($q_len - $q_gaps) +
				$strand{query} * $m * $multiplier{query} -
				$strand{query};
			$s_end = $f->{s_begin} + $strand{sbjct} *
				$multiplier{sbjct} * ($s_len - $s_gaps) +
				$strand{sbjct} * $m * $multiplier{sbjct} -
				$strand{sbjct};

			my $pad1 = length($q_begin);
			my $pad2 = length($s_begin);
			my $pad  = $pad1 > $pad2 ? $pad1 : $pad2;
			$pad1 = " " x ($pad-$pad1);
			$pad2 = " " x ($pad-$pad2);
			$pad  = " " x $pad;

			$out .= "Query: $pad1 $q_begin ";
			$out .= substr($f->{query},$m,60) . " $q_end\n";
			$out .= "         $pad" . substr($f->{align},$m,60) . "\n";
			$out .= "Sbjct: $pad2 $s_begin ";
			$out .= substr($f->{sbjct},$m,60) . " $s_end\n\n";
		}
	}
	return \$out;
}


#---------------------------------------------------------------------
# CreateReport
#---------------------------------------------------------------------
sub CreateReport {
	my ($bl,$d,$q,$r,$p,$s,$e) = @_;
	SetMultiplier($bl->{'program'});
	my $out = "";

	$out .= "$bl->{'program'} $bl->{'version'} ";
	$out .= "[$bl->{'date'}] [$bl->{'build'}]\n\n";

	my $firstline = substr($q->{name},0,60);
	my $length = length($firstline)-1;
	my $offset = length($firstline);

	$out .= "Query=  $firstline\n";
	my $k;
	for($k=$offset;$k<$length;$k+=60)
		{$out .= " " x 8 . substr($q->{name},$k,60) . "\n"}
	$out .= "        ($q->{'length'} letters)\n\n";

	$out .= "Database:  $d->{name}\n";
	$out .= "           $d->{sequences} sequences; ";
	$out .= "$d->{total_letters} total letters\n\n";

	#----- sort alignments by p
	@$r = sort {$a->{p} <=> $b->{p}} @$r;
	my $i;
	for($i=0;$i<@$r;$i++) {
		my $foo = BP2::FormatHSP($r->[$i]);
		$out .= $$foo;
	}

	$out .= "\nParameters:\n";
	for($i=0;$i<@$p;$i++) {$out .= "$p->[$i]"}

	$out .= "\nStatistics:\n";
	for($i=0;$i<@$s;$i++) {$out .= "$s->[$i]"}
	return \$out;
}


#---------------------------------------------------------------------
# LastWord - to prevent word clipping
#
# Arguments:
#	String
#	Offset
# Returns: position of last word before offset (0 if not found)
#---------------------------------------------------------------------
sub LastWord {
	my ($string,$offset) = @_;
	return $offset if $offset > length($string);
	my $i;
	for($i=$offset;$i>0;$i--)
		{last if substr($string,$i,1) =~ /\s/}
	return $i;
}


#---------------------------------------------------------------------
# SetMultiplier
#
# Argument: program name (eg. $b->{program})
# Returns:  nothing
# Sets the Class variable %multiplier used for display purposes
#---------------------------------------------------------------------
sub SetMultiplier {
	my ($program) = @_;
	if ($program eq 'BLASTN')
		{$multiplier{query} = $multiplier{sbjct} = 1}
	elsif ($program eq 'BLASTP')
		{$multiplier{query} = $multiplier{sbjct} = 1}
	elsif ($program eq 'BLASTX')
		{$multiplier{query} = 3; $multiplier{sbjct} = 1}
	elsif ($program eq 'TBLASTN')
		{$multiplier{query} = 1; $multiplier{sbjct} = 3}
	elsif ($program eq 'TBLASTX')
		{$multiplier{query} = $multiplier{sbjct} = 3}
	else {die "error, unknown program type"}
}


#---------------------- END DISPLAY ROUTINES -------------------------



#--------------------- GENERAL USE ROUTINES --------------------------

#---------------------------------------------------------------------
# Sorting instructions
#---------------------------------------------------------------------
sub by_pos   {$a->{'q_begin'}    <=> $b->{'q_begin'}}
sub by_p     {$a->{'p'}          <=> $b->{'p'}}
sub by_gi    {$a->{'gi'}         <=> $b->{'gi'}}
sub by_name  {$a->{'sbjct_name'} cmp $b->{'sbjct_name'}}
sub by_start {$a->{'start'}      <=> $b->{'start'}}

#---------------------------------------------------------------------
# Fcmp (Fuzzy_comparison)
#
# Takes three arguments: arg1, arg2, fuzzy_factor
# Returns
#	1	argument1 > argument2
#	0	argument1 ~ argument2
#	-1	argument1 < argument2
#
#---------------------------------------------------------------------
sub Fcmp {
	my ($a,$b,$fuzzy) = @_;
	if (abs($a - $b) < $fuzzy) {return 0}
	elsif ($a > $b) {return 1}
	else {return -1}
}



1;
