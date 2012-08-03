#!/bin/bash

if { cd /extra/genbank/ && nice wget -N 'ftp://ftp.ncbi.nih.gov/genbank/*.seq.gz' >& wget.$(date +%Y%m%d).log.txt ;} ; then
  cd /extra/genbank/
  ls -lat | head | mail -s "genbank $(date) yes" rwcitek
else
  echo | mail -s "genbank $(date) no" rwcitek
fi

