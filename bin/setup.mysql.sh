#!/bin/bash

usage="
${0##*/} [configuration file]

Creates the database and grants permissions in
a MySQL database.
"

{ [ "$1" ] && [ -f "$1" ] && source "$1" ; } ||
{ [ -f ~/.mygenbank.conf ] && source ~/.mygenbank.conf ; } ||
{ [ -f .mygenbank.conf ] && source .mygenbank.conf ; } ||
{ [ "$MYGENBANK_DB" -a "$MYGENBANK_DBUSER" -a "$MYGENBANK_DBHOST" ] ; } ||
{ echo -e "error: Need to setup environment\n$usage" && exit 1 ; }


sql="create database if not exists $MYGENBANK_DB ;
grant all on ${MYGENBANK_DB}.* to ${MYGENBANK_DBUSER}@localhost ;
grant file on *.* to ${MYGENBANK_DBUSER}@localhost ; 
grant all on ${MYGENBANK_DB}.* to ${MYGENBANK_DBUSER}@'10.4.0.%' ; 
grant file on *.* to ${MYGENBANK_DBUSER}@'10.4.0.%' ; 
# grant all on ${MYGENBANK_DB}.* to ${MYGENBANK_DBUSER}@'192.168.1.%' ; 
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

{ cat <<!
$sql
flush privileges ;
show tables from ${MYGENBANK_DB} ;
show grants for ${MYGENBANK_DBUSER}@localhost ;
show grants for ${MYGENBANK_DBUSER}@'10.4.0.%' ; 
!
} | mysql -h $MYGENBANK_DBHOST -u root -p mysql

