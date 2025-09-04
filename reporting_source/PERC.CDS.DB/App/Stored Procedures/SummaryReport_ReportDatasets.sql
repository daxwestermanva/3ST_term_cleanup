

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <5/13/2024>
-- Description:	Adopted from Marcos Lau's <App.Diabetes_ReportDatasets>
--
-- 2024-06-05  CW  Adding Riskcategory = 12 to the procedure

-- =============================================
CREATE PROCEDURE [App].[SummaryReport_ReportDatasets]
	 @Report int
	,@Dataset int
	,@Station varchar(1000) 
	,@User varchar(100)
	,@NoPHI as varchar(10)
	,@GroupType as varchar(100)

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
		FROM [ORM].[MetricTable] as a
        WHERE a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
        AND GroupID = '-5' OR GroupID = 0
		UNION 

		SELECT DISTINCT GroupType as RowLabel, GroupID  as RowValue, 2 as RowOrder
		FROM [ORM].[MetricTable] as a
        WHERE a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
        AND GroupID <>'-5' AND GroupID <> 0
		ORDER BY RowOrder, RowLabel

 END


  ELSE IF @Dataset = 2 -- Provider Parameter 
	BEGIN
	SELECT DISTINCT
	         CASE WHEN @NoPHI = 1 THEN  0 ELSE isnull (ProviderSID,-1) END RowValue
	        ,CASE WHEN @NoPHI = 1 THEN 'Dr Zhivago' 
		          ELSE ProviderName END RowLabel, 2 AS RowOrder
	         ,0 as prescriberorder
	         ,CASE WHEN @NoPHI = 1 THEN 'Fake' ELSE ProviderName END as providertypedropdown
           FROM [ORM].[MetricTable] as a
           WHERE (@GroupType <> '-5' AND ProviderSID <> 0)
	       AND a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
		   AND GroupID IN (@GroupType)
	     
		  
            UNION
	
	
             SELECT DISTINCT -5 as  RowValue
	         ,'All Providers'  as  Rowlabel, 1 AS RowOrder
	         ,0 as PrescriberOrder
	         ,'All Providers' as  ProviderTypeDropDown 
            WHERE @GroupType = '-5' 
            ORDER BY RowOrder, RowLabel	
   END 


  ELSE IF @Dataset = 3 -- RiskGroup 
	BEGIN
		SELECT 'All Risk Groups' AS RowLabel, 0 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 0 --check if this count matches what's on the old report.
				UNION 
		SELECT 'Low (Active Opioid Rx)' AS RowLabel, 1 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 1
				UNION
		SELECT 'Medium (Active Opioid Rx)' AS RowLabel, 2 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 2
				UNION
		SELECT 'High (Active Opioid Rx)' AS RowLabel, 3 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 3
				UNION
		SELECT 'Very High (Active Opioid Rx)' AS RowLabel, 4 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 4
				UNION
		SELECT 'OUD Dx, No Opioid Rx (Elevated Risk)' AS RowLabel, 5 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 5
				UNION
		SELECT 'Very High (Opioid Recently Discontinued)' AS RowLabel, 9 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 9
				UNION
		SELECT 'Very High (Active Status, No Pills on Hand)' AS RowLabel, 10 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 10
				UNION
		SELECT 'Overdose In The Past Year (Elevated Risk)' AS RowLabel, 11 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 11
				UNION
		SELECT 'Additional Possible Community Care Overdose In The Past Year' AS RowLabel, 12 AS RowValue
				FROM [ORM].[MetricTable]
				WHERE Riskcategory = 12
		ORDER BY RowLabel

  END

   ELSE IF @Dataset = 4 -- Measure 
	BEGIN
		SELECT 
	      MeasureNameClean as RowLabel
		  ,MeasureID as RowValue
		  ,1 as RowOrder
          FROM [ORM].[MeasureDetails] WITH (NOLOCK)


--Continue below if necessary

  END 

	

END