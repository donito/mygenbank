
DROP TABLE IF EXISTS MyGenBank;

CREATE TABLE MyGenBank
(
accession CHAR(25)      NOT NULL,
version   INT1,
gi        INT4 UNSIGNED,
length    INT3 UNSIGNED NOT NULL,
date      DATE          NOT NULL,
taxid     INT3 UNSIGNED,
genbank   INT4 UNSIGNED,
fasta     INT4 UNSIGNED NOT NULL,
file      CHAR(10)      NOT NULL,
mol_type  ENUM("AA","DNA","ds-RNA","ds-mRNA","ds-rRNA","mRNA","ms-DNA","ms-RNA","rRNA","scRNA","ss-DNA","ss-RNA","tRNA","uRNA","snoRNA","linear") NOT NULL,
division  ENUM("bct","est","gss","htc","htg","inv","mam","pat","phg","pln","pri","ref","rod","sts","syn","una","vrl","vrt") NOT NULL,
keywords  SET("EST","HTG","HTGS_PHASE0","HTGS_PHASE1","HTGS_PHASE2","HTGS_PHASE3","HTGS_DRAFT","GSS","STS"),
features  SET("CAAT_signal","CDS","conflict","enhancer","exon","gene","GC_signal","intron","mat_peptide","misc_binding","misc_RNA","misc_signal","misc_structure","modified_base","mRNA","organelle","polyA_signal","polyA_site","precursor_RNA","prim_transcript","promoter","protein_bind","RBS","repeat_region","rRNA","satellite","sig_peptide","snRNA","stem_loop","STS","TATA_signal","terminator","transit_peptide","transposon","tRNA","unsure","variation","3_clip","3_UTR","5_clip","5_UTR"),

PRIMARY KEY (accession)

);


# merge table version
# CREATE TABLE MyGenBank ( accession char(15) NOT NULL default '', version tinyint(3) unsigned default NULL, gi int(10) unsigned default NULL, length mediumint(8) unsigned NOT NULL default '0', date date NOT NULL default '0000-00-00', taxid mediumint(8) unsigned default NULL, genbank int(10) unsigned default NULL, fasta int(10) unsigned NOT NULL default '0', file char(10) NOT NULL default '', mol_type enum('AA','DNA','ds-RNA','ds-mRNA','ds-rRNA','linear','mRNA','ms-DNA','ms-RNA','rRNA','scRNA','snoRNA','ss-DNA','ss-RNA','tRNA','uRNA') NOT NULL default 'AA', division enum('bct','est','gss','htc','htg','inv','mam','pat','phg','pln','pri','rod','sts','sup','syn','una','vrl','vrt') NOT NULL default 'bct', keywords set('EST','GSS','HTG','HTGS_DRAFT','HTGS_PHASE0','HTGS_PHASE1','HTGS_PHASE2','HTGS_PHASE3','STS') default NULL, features set('3_UTR','3_clip','5_UTR','5_clip','CAAT_signal','CDS','GC_signal','RBS','STS','TATA_signal','conflict','enhancer','exon','gene','intron','mRNA','mat_peptide','misc_RNA','misc_binding','misc_signal','misc_structure','modified_base','organelle','polyA_signal','polyA_site','precursor_RNA','prim_transcript','promoter','protein_bind','rRNA','repeat_region','satellite','scRNA','sig_peptide','snRNA','tRNA','terminator','transit_peptide','transposon','unsure','variation') default NULL, PRIMARY KEY  (accession), KEY gi (gi), KEY length (length), KEY date (date), KEY taxid (taxid), KEY mol_type (mol_type), KEY division (division), KEY keywords (keywords), KEY features (features)) TYPE=merge union=(nonest,est);
