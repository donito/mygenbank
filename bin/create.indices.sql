
alter table MyGenBank 
#  add primary key (accession), 
  add index (gi), 
  add index (length), 
  add index (date), 
  add index (taxid), 
  add index (mol_type), 
  add index (division), 
  add index (keywords), 
  add index (features)
;
