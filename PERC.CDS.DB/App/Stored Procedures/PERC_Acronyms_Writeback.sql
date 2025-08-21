


-- =============================================
-- Author:		Liam Mina
-- Create date: 5/17/2022
-- Description:	

-- =============================================
CREATE PROCEDURE [App].[PERC_Acronyms_Writeback]
	-- Add the parameters for the stored procedure here
	@LookupOrSubmit varchar (15),
	@NewAcronym varchar(10),
	@NewDefinition varchar(100),
	@NewDescription varchar(100),
	@User varchar(150)
	


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

INSERT INTO [CDS].[PERC_Acronyms_Writeback] (Acronym,Definition,Description,DateSubmitted,UserID)
SELECT DISTINCT
	 @NewAcronym
	 ,@NewDefinition
	 ,@NewDescription
	 ,GETDATE()
	 ,@User
WHERE @LookupOrSubmit='Submit New'
	;

DELETE [CDS].[PERC_Acronyms_Writeback]
WHERE Acronym is null OR Acronym = '' 
 

END