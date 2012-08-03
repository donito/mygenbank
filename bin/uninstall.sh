#!/bin/bash

usage="
${0##*/} [configuration file]

Uninstalls all of the MyGenBank components:
 - the database
 - the user
 - the data folders

Only the code and gz folders are left behind.
"

{ [ "$1" ] && [ -f "$1" ] && source "$1" ; } ||
{ [ -f ~/.mygenbank.conf ] && source ~/.mygenbank.conf ; } ||
{ [ -f .mygenbank.conf ] && source .mygenbank.conf ; } ||
{ [ "$MYGENBANK_DB" -a "$MYGENBANK_DBUSER" -a "$MYGENBANK_DBHOST" -a "$MYGENBANK_DATA" ] ; } ||
{ echo -e "error: Need to setup environment\n$usage" && exit 1 ; }


# sql="drop database if exists $MYGENBANK_DB ;
# delete from db where user=\"${MYGENBANK_DBUSER}\";
# delete from user where user=\"${MYGENBANK_DBUSER}\"; "

sql="
revoke all on ${MYGENBANK_DB}.* from ${MYGENBANK_DBUSER}@localhost ;
revoke file on *.* from ${MYGENBANK_DBUSER}@localhost ; 
revoke all on ${MYGENBANK_DB}.* from ${MYGENBANK_DBUSER}@'10.4.0.%' ; 
# revoke all on ${MYGENBANK_DB}.* from ${MYGENBANK_DBUSER}@'192.168.1.%' ; 
drop database if exists $MYGENBANK_DB ;
"

{ cat <<!


The following MySQL statements will be sent to the server $MYGENBANK_DBHOST.

---
$sql
---

If this is not correct, press Control-C (^C).
Otherwise, enter the root password for 
the MySQL server at $MYGENBANK_DBHOST.

!
}

read -n 1 -p "Control-C or Enter .."

set -x
{ cat <<!
$sql
flush privileges ;
!
} | mysql -h $MYGENBANK_DBHOST -u root -p mysql


# && [ ! "$MYGENBANK_DATA" = "/" ] && [ -d "$MYGENBANK_DATA" ] && rm -rf "$MYGENBANK_DATA"

