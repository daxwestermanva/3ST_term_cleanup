
-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <4/12/2024>
-- Description:	Adopted from Marcos Lau's <App.Diabetes_ReportDatasets>
-- 2024-05-06  -TG Finetuning the report parameter datasets.
-- 2024-05-09  -TG Getting rid of clutters and formatting
-- =============================================
CREATE PROCEDURE [App].[OPPEReport_ReportDatasets]
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
		FROM [ORM].[OPPEMetric] as a
        WHERE a.ChecklistID in (SELECT value FROM string_split(@Station ,',')		) 
        AND GroupID = '-5' OR GroupID = 0
		UNION 

		SELECT DISTINCT GroupType as RowLabel, GroupID  as RowValue, 2 as RowOrder
		FROM [ORM].[OPPEMetric] as a
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
           FROM [ORM].[OPPEMetric] as a
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


  ELSE IF @Dataset = 3 -- Measure 
	BEGIN
		SELECT 
	      MeasureNameClean as RowLabel
		  ,MeasureID as RowValue
		  ,1 as RowOrder
          FROM [ORM].[MeasureDetails] WITH (NOLOCK)
          WHERE MeasureID IN (3,5,10,12)


--Continue below if necessary

  END 

	

END