-- =============================================
-- Author:		Amy Robinson
-- Create date: <July 25 2017>
-- Description:	Codesharing
-- =============================================
CREATE PROCEDURE  [App].[p_Admin_StoredProcedures]


	-- Add the parameters for the stored procedure here
    @ProcedureType varchar(1000)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
  
  
select
  distinct name
          ,name as NameLabel
from
Maintenance.StoredProcedureBackUp
where
  SchemaName = @ProcedureType and
  name not like 'fn%' and
  name not like 'sp%' and
  name not like '%14' and
  name not like '%old%' and
  name not like '%/_GS'  escape '/' and
  name not like 'GS%'  escape '/' and
  backupdate like
    (Select
       max(backupdate)
     from Maintenance.StoredProcedureBackUp )
order by
  namelabel
  
  
END


--go 
--exec [dbo].[sp_SignAppObject] @ObjectName = 'Admin_DiagnosisValidation_LSV' --Edit the name here to equal you procedure name above EXACTLY