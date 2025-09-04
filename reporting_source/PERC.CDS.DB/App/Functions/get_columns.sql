

CREATE function [App].[get_columns] (@table_name sysname)
returns table
as
return 
(
  select distinct top 10000000 column_id, name from sys.columns where object_id in
  (  select object_id from sys.tables t where t.name = @table_name )
  order by column_id
)