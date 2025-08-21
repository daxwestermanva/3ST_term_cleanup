
-- =============================================
-- Author:		Amy Furman 
-- Create date: 4/15/2014
-- Description:	DataSet for Diagnosis Crosswalk

-- 2021-11-05	RAS	Refactored to use new LookUp.ICD10_Display table for when criteria is ProjectType.

--	EXEC [App].[Definitions_Diagnosis] 'Suicide','DxCategory'
--	EXEC [OMHSP_PERC_CDS].[App].[Definitions_Diagnosis] 'Suicide','DxCategory'
--	EXEC [App].[Definitions_Diagnosis] 'CRISTAL','ProjectType'
-- =============================================
CREATE PROCEDURE [App].[Definitions_Diagnosis]
	@Disease1 varchar(max)
	,@Column varchar(1000)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

IF @Column = 'ProjectType' -- includes inner join to ICD10_Display to determine which DxCategories to show
BEGIN
  SELECT dxv.ICD10Code
	  ,dxv.ICD10Description
	  ,dxv.DxCategory
	  ,dis.ProjectType
	  ,cd.PrintName
	  ,cd.ColumnDescription
  FROM [LookUp].[ICD10_Vertical] dxv WITH (NOLOCK)
  INNER JOIN [LookUp].[ICD10_Display] dis WITH (NOLOCK) ON dis.DxCategory = dxv.DxCategory
  INNER JOIN [LookUp].[ColumnDescriptions] cd WITH (NOLOCK) ON 
		dxv.DxCategory = cd.ColumnName
		AND cd.TableName='ICD10'
  WHERE dis.ProjectType IN (SELECT value FROM string_split(@Disease1 ,','))
  ORDER BY PrintName

END
IF @Column = 'DxCategory'
BEGIN
  SELECT dxv.ICD10Code
	  ,dxv.ICD10Description
	  ,dxv.DxCategory
	  ,cd.PrintName
	  ,cd.ColumnDescription
  FROM [LookUp].[ICD10_Vertical] dxv WITH (NOLOCK)
  INNER JOIN [LookUp].[ColumnDescriptions] cd WITH (NOLOCK) ON 
		dxv.DxCategory = cd.ColumnName
		AND cd.TableName='ICD10'
  WHERE dxv.DxCategory IN (SELECT value FROM string_split(@Disease1 ,','))
  ORDER BY PrintName
END

END