#!/bin/bash

usage="
${0##*/} [configuration file]

Creates the indices in a MyGenBank database.
"

{ [ "$1" ] && [ -f "$1" ] && source "$1" ; } ||
{ [ -f ~/.mygenbank.conf ] && source ~/.mygenbank.conf ; } ||
{ [ -f .mygenbank.conf ] && source .mygenbank.conf ; } ||
{ [ "$MYGENBANK_DB" -a "$MYGENBANK_DBUSER" -a "$MYGENBANK_DBHOST" ] ; } ||
{ echo -e "error: Need to setup environment\n$usage" && exit 1 ; }


sql='
alter table MyGenBank 
  add primary key (accession), 
  add index (gi), 
  add index (length), 
  add index (date), 
  add index (taxid), 
  add index (mol_type), 
  add index (division), 
  add index (keywords), 
  add index (features)
;
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
show index from MyGenBank ;
!
} | mysql -h ${MYGENBANK_DBHOST} -u ${MYGENBANK_DBUSER} ${MYGENBANK_DB}


