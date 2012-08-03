
alter table MyGenBank 
  drop index gi, 
  drop index length, 
  drop index date, 
  drop index taxid, 
  drop index mol_type, 
  drop index division, 
  drop index keywords, 
  drop index features
;
