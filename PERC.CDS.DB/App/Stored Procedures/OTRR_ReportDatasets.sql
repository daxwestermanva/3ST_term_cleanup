
-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: <5/10/2024>
-- Description:	Adopted from Marcos Lau's <App.Diabetes_ReportDatasets>
-- =============================================
CREATE PROCEDURE [App].[OTRR_ReportDatasets]
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
	         ,'All Providers/Teams'  as  RowLabel
	         ,0 as PrescriberOrder
	         ,'All Providers/Teams' as  ProviderTypeDropDown
            WHERE @GroupType = '-5'
            ORDER BY RowLabel
   END 


  ELSE IF @Dataset = 3 -- Measure 
	BEGIN
			SELECT 'All Opioids' AS RowLabel, 3 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE MOUD =1 OR MOUD =0
				  UNION 
			SELECT 'MOUD' AS RowLabel, 1 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE MOUD =1
				  UNION
            SELECT 'Tramadol Only' AS RowLabel, 4 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE TramadolOnly = 1
				  UNION
            SELECT 'Long Term Opioid' AS RowLabel, 5 AS RowValue
			      FROM [ORM].[PatientOTRRView]
				  WHERE ChronicOpioid=1 
				  ORDER BY RowLabel

--Continue below if necessary

  END 

	

END