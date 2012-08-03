#!/bin/bash

{ [ "$1" ] && [ -f "$1" ] && source $1 ; } ||
{ [ -f ~/.mygenbank.conf ] && source ~/.mygenbank.conf ; } ||
{ [ -f .mygenbank.conf ] && source .mygenbank.conf ; } ||
{ [ "$MYGENBANK_DATA_GZ" -a "$MYGENBANK_CODE" -a "$MYGENBANK_DATA" ] ; } ||
{ echo "need to setup environment" && exit 1 ; }

for i in "$MYGENBANK_DATA_GZ" "$MYGENBANK_CODE" "$MYGENBANK_DATA" ; do
  [ ! -d $i ] && { mkdir -p "$i" || { echo "can't create $i" ; exit 1 ; } ; }
done


