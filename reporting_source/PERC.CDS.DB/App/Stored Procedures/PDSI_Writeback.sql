

-- =============================================
-- Author:		Meenah Paik
-- Create date: 10/26/2021
-- Description:	New Writeback SP for PDSI Report

-- TESTING
	/*
	EXEC [App].[PDSI_Writeback] 
		 @MVIPersonSID	= 13902115
		,@PatientSID	= 4691347
		,@Sta3n			= '534'
		,@User 			= 'VHA21\VHAPALSTEPHR6'
		,@Action		= 'OAT: No change required'
		,@Comments		= 'Testing comments'
		,@Measures		= 'OAT,SUD16'
	*/
-- MODIFICATIONS:
	-- 20211130	RAS	Added back PatientSID because with changing ICNs/MVIPersonSIDs it is best to save both the MVIPersonSID AND at least 1 PatientSID.
				--	The PatientSID saved will be the one related to the station for the provider entering the data, however the MVIPersonSID should
				--	be used to link this data at the unique PATIENT LEVEL to other tables.
-- =============================================
CREATE PROCEDURE [App].[PDSI_Writeback]
	-- Add the parameters for the stored procedure here
	@MVIPersonSID int,
    @Sta3n varchar(10),
	@User varchar(150),
	@Action varchar(255),
	@Comments varchar(255),
	@Measures varchar(255)
	


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

INSERT INTO [PDSI].[Writeback] (Sta3n,MVIPersonSID,PatientReviewed,ExecutionDate,UserID,ActionType,Comments,VariableName)
SELECT DISTINCT
	 @Sta3n
	,@MVIPersonSID
	,1
	,GETDATE()
	,@User
	,@Action
	,@Comments
	,@Measures
	;

DELETE [PDSI].[Writeback]
WHERE ActionType = '' 
 

END