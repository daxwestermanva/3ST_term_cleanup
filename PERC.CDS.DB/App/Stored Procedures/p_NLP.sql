


-- =============================================
-- Author:		<Liam Mina>
-- Create date: <11-25-2024>
-- Description:	Parameters for NLP report
-- Updates

-- =============================================
CREATE PROCEDURE [App].[p_NLP]
(
	@Patient varchar(100),
	@Report varchar(100)
)  
AS
BEGIN
	SET NOCOUNT ON;

	--For inline testing only
	--DECLARE @Report varchar(100)='NLP',@Patient varchar(100)='1039185975'
	--DECLARE @Report varchar(100)='CRISTAL',@Patient varchar(100)='1000713690'
	--DECLARE @Report varchar(100)='CRISTAL',@Patient varchar(100)='1040523160'


	SELECT DISTINCT 
		CASE WHEN Concept IN ('LONELINESS','LIVES ALONE','PSYCHOLOGICAL PAIN','CAPACITY FOR SUICIDE','DEBT','FOODINSECURE','HOUSING','JOBINSTABLE','JUSTICE','SLEEP','XYLA','IDU') THEN ISNULL(SubclassLabel,Concept)
			ELSE ISNULL(Concept,'') END AS Concept
	FROM Common.vwMVIPersonSIDPatientICN a WITH (NOLOCK) 
	LEFT JOIN Present.NLP_Variables b WITH (NOLOCK)
		ON a.MVIPersonSID=b.MVIPersonSID 
		AND (@Report<>'CRISTAL'
		OR (@Report='CRISTAL' AND Concept IN ('LONELINESS','LIVES ALONE','PSYCHOLOGICAL PAIN','CAPACITY FOR SUICIDE','DEBT','FOODINSECURE','HOUSING','JOBINSTABLE','JUSTICE','SLEEP'))
		OR b.Concept IS NULL)
	WHERE a.PatientICN=@Patient
	ORDER BY Concept
		; 
END