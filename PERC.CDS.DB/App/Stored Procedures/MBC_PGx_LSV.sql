/** =============================================
-- Author:		<Amy Robinson>
-- Create date: <6/8/2022>
-- Description:	PGx testing and its effect on opioid response
EXEC [App].[MBC_PGx_LSV]  @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1000656578
EXEC [App].[MBC_PGx_LSV]  @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001030511
EXEC [App].[MBC_PGx_LSV]  @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001027685

Updates
1.0		Amy Robinson				Initial
2.0		Susana Martins		5/1/24		Replaced DOEx with new table: [PDW].[NOP_PGx_DOEx_PGx_CYP2D6_data] with more lab sources that requires restriction for 'active' result
2.1		Susana Martins		5/20/24	Corrected 3 part naming convention
2.1.1   Bacani, Jason		09/12/2024  D&A PERC Support - Refactored for newer Synonym name, per Susana Martins, ticket CDW-9999/PSRM-99
-- =============================================**/
CREATE PROCEDURE [App].[MBC_PGx_LSV]
(
  @User varchar(max),
  @Patient varchar(1000)
)
AS
BEGIN
	SET NOCOUNT ON;

	--For inlne testing only
	--DECLARE @User varchar(max), @Patient varchar(1000), @Report varchar(100); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1012354055; SET @Report = 'STORM'  
	--DECLARE @User varchar(max), @Patient varchar(1000), @Report varchar(100); SET @User = 'VHA21\VHAPALMINAL'; SET @Patient = 1001319032; SET @Report = 'CRISTAL'

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT a.MVIPersonSID,a.PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS a WITH (NOLOCK)
	WHERE a.PatientICN =  @Patient
		and EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;

select distinct  p.PatientICN,p.MVIPersonSID, a.VINCI_Phenotype
,case when VINCI_Phenotype like '%Poor%' or VINCI_Phenotype like '%ultra%' then 1 else 0 end Banner
,case when VINCI_Phenotype like '%Poor%' and        
        ( DrugNameWithoutDose like '%codeine%' or DrugNameWithoutDose like '%tramadol%') 
            then 'Patient is a poor CYP2D6 metabolizer and may experience diminished analgesia with codeine/tramadol'  
     when VINCI_Phenotype like '%Poor%' and        
        (( DrugNameWithoutDose not like '%codeine%' and DrugNameWithoutDose not like '%tramadol%') or drugnamewithoutdose is null) 
            then 'Patient is a poor CYP2D6 metabolizer and may experience diminished analgesia with codeine/tramadol' 
      when VINCI_Phenotype like '%ultra%' and        
        ( DrugNameWithoutDose like '%codeine%' or DrugNameWithoutDose like '%tramadol%') 
            then 'Patient is an ultrarapid CYP2D6 metabolizer and has the potential for<font color ="red"> serious toxicity </font>  with codeine/tramadol' 
     when VINCI_Phenotype like '%ultra%' and        
          ((DrugNameWithoutDose not like '%codeine%' and DrugNameWithoutDose not like '%tramadol%') or drugnamewithoutdose is null )
            then 'Patient is an ultrarapid CYP2D6 metabolizer and has the potential for<font color ="red"> serious toxicity </font>with codeine/tramadol' 
        when (VINCI_Phenotype like '%normal%' or VINCI_Phenotype like '%Intermediate%' )    
            then 'Patient is a normal CYP2D6 metabolizer' 
            End Findings
,case  when (VINCI_Phenotype like '%Poor%' or VINCI_Phenotype like '%ultra%') and        
        ( DrugNameWithoutDose not like '%codeine%' and DrugNameWithoutDose not like '%tramadol%' or drugnamewithoutdose is null )
            then 'Avoid codeine/tramadol use. If opioid use is warranted, consider a non-codeine/tramadol opioid.' 
       when VINCI_Phenotype like '%Poor%' and       
        ( DrugNameWithoutDose like '%codeine%' or DrugNameWithoutDose like '%tramadol%') 
            then 'Assess current ' + DrugNameWithoutDose + ' therapy for efficacy.'
    when VINCI_Phenotype like '%ultra%' and        
        ( (DrugNameWithoutDose  like '%codeine%' or DrugNameWithoutDose  like '%tramadol%' or drugnamewithoutdose is null ) )
            then 'Consider discontinuation of ' + DrugNameWithoutDose + ' and assess for adverse effects.' 
    when (VINCI_Phenotype like '%normal%' or VINCI_Phenotype like '%Intermediate%' )    
            then 'This result does not impact the clinical decision making around efficacy and safety of codeine/tramadol, prescribe in accordance with <p style="color:red;"> VA Opioid guidelines </p>' 
                end Recommendation
                ,f.DrugNameWithoutDose
				,f.Opioid_Rx
  FROM #patient as p 
  inner join   (	
  Select a.*
						  ,b.MVIPersonSID 
					from [PDW].[NOP_PGx_DOEx_PGx_CYP2D6_data]  a WITH (NOLOCK)
					inner join Common.MasterPatient b WITH (NOLOCK) on a.PatientICN=b.PatientICN
					where UpdateStatus='A'  -- denotes active in case of multiple results for same specimen collection date
					) a  on p.MVIPersonSID=a.MVIPersonSID
  left outer join Present.Medications f WITH (NOLOCK) on p.mvipersonsid=f.mvipersonsid and f.Opioid_Rx = 1 and (DrugNameWithoutDose like '%codeine%' or DrugNameWithoutDose like '%tramadol%')
	;
END