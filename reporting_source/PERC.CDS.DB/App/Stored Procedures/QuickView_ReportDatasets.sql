

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <5/13/2024>
-- Description:	Adopted from Marcos Lau's <App.Diabetes_ReportDatasets>

-- =============================================
CREATE PROCEDURE [App].[QuickView_ReportDatasets]
	@Report int  
	,@Dataset int  
	,@Station varchar(1000) 
	,@User varchar(100)
	,@NoPHI as varchar(10)
	,@GroupType as varchar(20)
	

AS
BEGIN
	SET NOCOUNT ON;

	IF @Report <> 1
		SET @Report = 0
	;

    IF @Report = 0 
		SELECT 'Hello' as RowLabel, '0' as RowValue, 0 as RowOrder
 ELSE
 
 --declare @Report int  =1
	--declare @Dataset int = 3
	--declare @Station varchar(1000) = '640'
	--declare  @User varchar(100) = 'VHA21\vhapalgurmet'
	--declare @NoPHI as varchar(10)=0
	--declare @GroupType as varchar(20)= '-5'
 
 IF @Dataset = 1 -- GroupType Parameter 
	BEGIN
		SELECT 'Station Level' as RowLabel, '-5'  as RowValue, 1 as RowOrder
		UNION 

		SELECT DISTINCT GroupType as RowLabel, GroupID  as RowValue, 2 as RowOrder
		FROM [Present].[GroupAssignments_STORM] as a
        WHERE a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
        AND GroupID <>'-5'
		ORDER BY RowOrder, RowLabel

 END


  ELSE IF @Dataset = 2 -- Provider Parameter 
	BEGIN
		
       SELECT DISTINCT
	         CASE WHEN @NoPHI = 1 or @GroupType = -5 THEN  0 ELSE isnull (ProviderSID,-1) END RowValue
	        ,CASE WHEN @NoPHI = 1 THEN 'Dr Zhivago' 
		          WHEN  @GroupType = -5 THEN 'All Providers/Teams'  
		          ELSE ProviderName END RowLabel
	         ,0 as prescriberorder
	         ,CASE WHEN @NoPHI = 1 THEN 'Fake' ELSE ProviderName END as providertypedropdown
           FROM [Present].[GroupAssignments_STORM] as a
           WHERE @GroupType <>'-5 '
	       AND a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
	       AND (GroupID IN (@GroupType))

            UNION ALL

             SELECT -5 as  RowValue
	         ,'All Providers/Teams'  as  Rowlabel
	         ,0 as PrescriberOrder
	         ,'All Providers/Teams' as  ProviderTypeDropDown
            WHERE @GroupType = '-5'
            ORDER BY RowLabel
   END 


  ELSE IF @Dataset = 3 -- RiskGroup 
	BEGIN
		SELECT 'OUD Dx, No Opioid Rx (Elevated Risk)' AS RowLabel, 5 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 5 --check if this count matches what's on the old report.
				  UNION 
			SELECT 'Very High - Opioid Rx' AS RowLabel, 4 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 4
				  UNION
            SELECT 'Very High - Active Status, No Pills on Hand' AS RowLabel, 10 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 10
				  UNION
            SELECT 'Very High - Recently Discontinued' AS RowLabel, 9 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 9
				  UNION
			SELECT 'High - Opioid Rx' AS RowLabel, 3 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 3
				  UNION
           SELECT 'Medium - Opioid Rx' AS RowLabel, 2 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 2
				  UNION
           SELECT 'Low - Opioid Rx' AS RowLabel, 1 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 1
				  UNION
           SELECT 'Medium - Recently Discontinued' AS RowLabel, 7 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 7
 UNION
           SELECT 'High - Recently Discontinued' AS RowLabel, 8 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 8
				  UNION
           SELECT 'Low - Recently Discontinued' AS RowLabel, 6 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 6
				  UNION
		 SELECT 'Overdose In The Past Year (Elevated Risk)' AS RowLabel, 11 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE Riskcategory = 11
				  ORDER BY RowLabel
  END

   ELSE IF @Dataset = 4 -- Measure 
	BEGIN
		SELECT 
	      MeasureNameClean as RowLabel
		  ,MeasureID as RowValue
		  ,1 as RowOrder
          FROM [ORM].[MeasureDetails] WITH (NOLOCK)
         

  END 

  ELSE IF @Dataset = 5 -- Cohort 
	BEGIN
			SELECT 'All STORM Cohort' AS RowLabel, 3 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE OUD IN (1,0)
				  UNION 
			SELECT 'OUD Dx Patients' AS RowLabel, 1 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE OUD =1
				  UNION
            SELECT 'Opioid Rx Patients' AS RowLabel, 2 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE OpioidForPain_Rx = 1
				  UNION
            SELECT 'SUD Tx Patients' AS RowLabel, 4 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE SUDdx_poss=1
                  UNION
            SELECT 'OD In The Past Year' AS RowLabel, 5 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE ODPastYear=1
				  ORDER BY RowLabel

--Continue below if necessary

  END 
	

END