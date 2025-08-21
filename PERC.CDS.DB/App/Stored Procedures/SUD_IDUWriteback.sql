-- =============================================
-- Author:		Amy Robinson
-- Create date: 3/18/2023
-- Description:	Writeback SP for IDU report
-- =============================================
create PROCEDURE [App].[SUD_IDUWriteback]
	-- Add the parameters for the stored procedure here

	@MVIPersonSID int,
	@User varchar(MAX),
	@Confirmed varchar(255)



AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


INSERT INTO [SUD].[IDU_Writeback] 
SELECT  
	 @MVIPersonSID as MVIPersonSID
		,@Confirmed as Confirmed
    ,GetDate() as ExecutionDate
	,@User as UserID


update SUD.IDUCohort SET
  Confirmed = @Confirmed
 where MVIPersonSID = @MVIPersonSID
 
 delete from SUD.IDUCohort
 where MVIPersonSID = @MVIPersonSID and @Confirmed = 0 

END