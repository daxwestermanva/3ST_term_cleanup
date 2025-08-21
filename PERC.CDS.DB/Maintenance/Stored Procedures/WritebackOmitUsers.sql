

-- =============================================
-- Author:		Rebecca Stephens
-- Create date: 2019-02-20
-- Description:	Removes PERC Staff from writebacks that contain data entered by users.  PERC staff is not removed from access log writebacks.
	--Created from previous code by Sara Tavakoli (Delete_PDSI_Team_PatientReviews)
-- Modifications:
     --12/2/2021   CMH   Took out reference to [PDSI].[PatientCohort_Writeback]	
	 --12/27/2021  LM	 Updated to reflect renamed tables
-- =============================================
CREATE PROCEDURE [Maintenance].[WritebackOmitUsers]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  DELETE w
  FROM [PDSI].[Writeback] w
  INNER JOIN [Config].[WritebackUsersToOmit] u on u.UserName=w.UserID
  ;
  	
  DELETE w
  FROM [Pharm].[Lithium_Writeback] w
  INNER JOIN [Config].[WritebackUsersToOmit] u on u.UserName=w.UserID
  ;

  DELETE w
  FROM [Pharm].[Antidepressant_Writeback] w
  INNER JOIN [Config].[WritebackUsersToOmit] u on u.UserName=w.UserID
  ;

END