#!/bin/bash

usage="
${0##*/} [configuration file]

Creates the tables in a MyGenBank database.
"

{ [ "$1" ] && [ -f "$1" ] && source "$1" ; } ||
{ [ -f ~/.mygenbank.conf ] && source ~/.mygenbank.conf ; } ||
{ [ -f .mygenbank.conf ] && source .mygenbank.conf ; } ||
{ [ "$MYGENBANK_DB" -a "$MYGENBANK_DBUSER" -a "$MYGENBANK_DBHOST" ] ; } ||
{ echo -e "error: Need to setup environment\n$usage" && exit 1 ; }


sql=' DROP TABLE IF EXISTS MyGenBank;

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
features  SET("CAAT_signal","CDS","conflict","enhancer","exon","gene","GC_signal","intron","mat_peptide","misc_binding","misc_RNA","misc_signal","misc_structure","modified_base","mRNA","organelle","polyA_signal","polyA_site","precursor_RNA","prim_transcript","promoter","protein_bind","RBS","repeat_region","rRNA","satellite","sig_peptide","snRNA","stem_loop","STS","TATA_signal","terminator","transit_peptide","transposon","tRNA","unsure","variation","3_clip","3_UTR","5_clip","5_UTR")

);
'

{ cat <<!


The following MySQL statements will be sent to the server using these settings:
host: ${MYGENBANK_DBHOST}
MyGenBank database: ${MYGENBANK_DB}
user: ${MYGENBANK_DBUSER}

---
$sql
---

If this is not correct, press Control-C (^C).
Otherwise, enter the user ${MYGENBANK_DBUSER}'s
password for the MySQL server at $MYGENBANK_DBHOST.

!
}

read -n 1 -p "Control-C or Enter .."

{ cat <<!
$sql
show tables from ${MYGENBANK_DB} ;
!
} | mysql -h ${MYGENBANK_DBHOST} -u ${MYGENBANK_DBUSER} ${MYGENBANK_DB}

