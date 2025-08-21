

-- =============================================
-- Author:		<Liam Mina>
-- Create date: <09/12/2022>
-- Description:	Dataset pulls 5 most recent CSRE acute and chronic risk levels - used in CRISTAL
-- Updates

--
-- EXEC [App].[MBC_CSRE_LSV] @User = 'vha21\vhapalminal'	, @Patient = '1000995350'
-- EXEC [App].[MBC_CSRE_LSV] @User = 'vha21\vhapalminal'	, @Patient = '1001542730'
-- =============================================
CREATE PROCEDURE [App].[MBC_CSRE_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'	; SET @Patient = '1000983414'
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'vha21\vhapalminal'		; SET @Patient = '1000986647'

	--Step 1: find patient, set permissions
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT 
		MVIPersonSID,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

	--Step 2: Get 5 most recent CSRE acute and chronic risk levels
	DROP TABLE IF EXISTS #FiveMostRecent
	SELECT TOP (5) WITH TIES
		pat.PatientICN
		,h.ChecklistID
		,c.Facility
		,ISNULL(h.AcuteRisk,'Unknown') AS AcuteRisk
		,h.AcuteRiskComments
		,ISNULL(h.ChronicRisk,'Unknown') AS ChronicRisk
		,h.ChronicRiskComments
		,CAST(ISNULL(h.EntryDateTime,h.VisitDateTime) AS DATE) AS EntryDate
		,h.VisitSID
		,ROW_NUMBER() OVER (PARTITION BY h.PatientICN ORDER BY h.EntryDateTime DESC) AS RN
	INTO #FiveMostRecent
	FROM #Patient AS pat
	INNER JOIN [OMHSP_Standard].[CSRE] AS h WITH (NOLOCK) 
		ON pat.MVIPersonSID = h.MVIPersonSID
	INNER JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
		ON h.ChecklistID = c.ChecklistID
	WHERE h.AcuteRisk IS NOT NULL OR h.ChronicRisk IS NOT NULL
	ORDER BY ISNULL(h.EntryDateTime, h.VisitDateTime) DESC

	SELECT h.PatientICN
		,h.ChecklistID
		,h.Facility
		,h.AcuteRisk
		,h.AcuteRiskComments
		,h.ChronicRisk
		,h.ChronicRiskComments
		,h.EntryDate
		,h.RN
		,d.Type
		,d.PrintName
		,d.Comments
	FROM #FiveMostRecent h
	LEFT JOIN [OMHSP_Standard].[CSRE_Details] AS d WITH (NOLOCK)
		ON h.VisitSID = d.VisitSID AND h.RN=1 AND d.Type LIKE '%Factor'
	;

END