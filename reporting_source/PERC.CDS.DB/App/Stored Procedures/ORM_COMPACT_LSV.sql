 
-- =============================================
-- Author:		<Tolessa Gurmessa>
-- Create date: <04/18/2025>
-- Description:	Clone of [App].[MBC_COMPACT_LSV] -pulls COMPACT Act Episodes and Eligibility
-- Modifications:

-- =============================================
CREATE   PROCEDURE [App].[ORM_COMPACT_LSV]
(
	@User VARCHAR(MAX),
	@ICN VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;
 
	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @ICN = '1034459655'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @ICN = '1000652955'
 
	
--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN,PriorityGroup,PrioritySubGroup,COMPACTEligible
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @ICN
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

DROP TABLE IF EXISTS #COMPACTEpisodes
SELECT mp.PatientICN
	,mp.MVIPersonSID
	,CASE WHEN mp.PriorityGroup BETWEEN 1 AND 6 THEN CONCAT('Yes (Priority Group ',mp.PriorityGroup,')')
			WHEN mp.PrioritySubGroup IN ('e','g') AND mp.COMPACTEligible=1 THEN CONCAT('Yes (COMPACT eligible only, ',mp.PriorityGroup,mp.PrioritySubgroup,')')
			WHEN mp.PriorityGroup BETWEEN 7 AND 8 AND mp.COMPACTEligible=1 THEN CONCAT('Yes (Priority Group ',mp.PriorityGroup,mp.PrioritySubgroup,')')
			WHEN mp.COMPACTEligible = 1 THEN 'Yes (COMPACT eligible only)'
			ELSE 'Not verified as eligible'
			END AS COMPACTEligible
	,EligibilityMessage = CASE WHEN mp.CompactEligible = 0 THEN 'Contact your local Eligibility and Enrollment office to determine if this patient is eligible for COMPACT Act related services.'
		ELSE NULL END
	,a.ActiveEpisode
	,a.ActiveEpisodeSetting
	,CASE WHEN c.ActiveEpisode=1 THEN 'Active COMPACT Crisis Episode'
		WHEN c.ActiveEpisode=0 THEN 'Most Recent COMPACT Crisis Episode'
		WHEN a.ActiveEpisode IS NULL THEN 'No COMPACT Crisis Episodes' END AS ActiveEpisodeDisplay
	,CASE WHEN a.ActiveEpisode IS NOT NULL THEN CONCAT('Began in '
		,CASE WHEN c.CommunityCare=1 AND c.EpisodeBeginSetting<>'CommunityCare' THEN CONCAT(c.EpisodeBeginSetting, ' Community Care') ELSE c.EpisodeBeginSetting END
			,' at ' ,d.Facility) END AS ActiveEpisodeDisplay2
	,a.ChecklistID_EpisodeBegin
	,b.Facility
	,a.EpisodeBeginDate
	,a.EpisodeEndDate
	,CASE WHEN a.CommunityCare = 1 AND a.EpisodeBeginSetting <> 'Community Care' THEN CONCAT(a.EpisodeBeginSetting, ' Community Care')
		ELSE a.EpisodeBeginSetting END AS EpisodeBeginSetting
	,a.InpatientEpisodeEndDate
	,a.OutpatientEpisodeBeginDate
	,a.EpisodeRankDesc
	,a.ConfirmedStart
	,a.EncounterCodes
FROM #Patient mp 
LEFT JOIN [COMPACT].[Episodes] a WITH (NOLOCK) ON a.MVIPersonSID=mp.MVIPersonSID
LEFT JOIN [Lookup].[ChecklistID] b WITH (NOLOCK) ON a.ChecklistID_EpisodeBegin = b.ChecklistID
LEFT JOIN [COMPACT].[Episodes] c WITH (NOLOCK) ON c.MVIPersonSID=mp.MVIPersonSID AND c.EpisodeRankDesc=1
LEFT JOIN [Lookup].[ChecklistID] d WITH (NOLOCK) ON c.ChecklistID_EpisodeBegin = d.ChecklistID


END