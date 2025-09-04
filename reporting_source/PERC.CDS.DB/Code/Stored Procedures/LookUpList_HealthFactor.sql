/*--=============================================
-- Author:		Amy Furman and Rebecca Stephens
-- Create date: 2017-02-08
-- Description: Health Factor LookUp: Pulls all HF from CDW dim table and creates binary variables for different categories
-- Current Categories:
		EBP,Labs,REACH,Suicide Prevention Safety Plan,Tobacco/Nicotine 
--Modifications:
	2018-08-22	- Matt Wollner	- Converted HF to List Mapping
								- V02
	2018-09-27	- Matt Wollner	- Renamed to [Code].[LookUpList_HealthFactor]
	2020-09-08	- LM			- converted ORM health factors to list mapping structure
	2020-09-18	- RAS			- converted exact and pattern match to use shared SP. Added tobacco HFs to ListMappingRule and removed from custom mapping section
	2020-11-13	- RAS			- Added EBP Contingency Management to custom mappings
	2023-10-24  - EC            - Moved EBP Contingency Management to LookupList_ListMember
	2024-03-19	- LM			- Update delete step to delete list values no longer hard coded or in config file
	2024-06-17	- LM			- Get health factor matches for mapped health factor categories
--=============================================*/ 


CREATE PROCEDURE [Code].[LookUpList_HealthFactor]
AS
BEGIN
	
----------------------------------------------------------------------------
-- PHASE 1:  Get all the standard Health Factor Mappings
-- Exact Match and Patttern Match will get Auto Approved
----------------------------------------------------------------------------
EXEC [Code].[LookUpList_ListMember] @Domain='HealthFactorType'
	,@SourceTable='[Dim].[HealthFactorType]'
	,@ItemIDName='HealthFactorTypeSID'
	--,@Debug = 1 --Use this line to see the printed results of the dynamic SQL from LookUpList_ListMember

----------------------------------------------------------------------------
--Create temp table for use in Phase 2 and 3
----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ListMember

	CREATE TABLE #ListMember(
		[List] VARCHAR(50),
		[Domain] VARCHAR(50),
		[Attribute] VARCHAR(50),
		[ItemID] INT,
		[ItemIDName] VARCHAR(50),
		[AttributeValue] VARCHAR(100),
		[CreatedDateTime] SMALLDATETIME,
		[MappingSource]  VARCHAR(50),
		[ApprovalStatus]  VARCHAR(50),
		[ApprovedDateTime] SMALLDATETIME
	 )
----------------------------------------------------------------------------
-- PHASE 2: Get the Custom Health Factor Mappings
-- Eact Match and Patttern Match will get Pending  Approval
----------------------------------------------------------------------------

	-------------------------------------------------------
	------ LABS --------------------------------------
	-------------------------------------------------------

		/********** A1c **************/
		-- updating definition information
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'A1c_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'A1c_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE HF.[HealthFactorType] like '%A1c%' 
			AND HF.[HealthFactorType] not like '%order%' 
			AND HF.[HealthFactorType] not like '%life%' 
			AND HF.[HealthFactorType] not like '%refused%'
			AND HF.[HealthFactorTypeSID] not in (
				800024829,800050490,800050675,800024831,800035459
				,800036126,800096464,800096448,800035460,800050674
				)
			AND	TMP.Domain IS NULL ;

		/********** Hematocrit **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'Hematocrit_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'Hematocrit_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE  (HF.[HealthFactorType] like '%hemato%' or HF.[HealthFactorType] like '%hct%') 
			AND HF.[HealthFactorType] not like '%hgb%'
			AND	TMP.Domain IS NULL
		;

		/********** Barbiturate Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Barbiturate_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Barbiturate_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%barb%'
			AND	TMP.Domain IS NULL 
		;
		/********** Cocaine Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Cocaine_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Cocaine_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%coca%'
			AND	TMP.Domain IS NULL 
		;
		/********** Methadone Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Methadone_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Methadone_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' OR HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%meth%' 
			AND	TMP.Domain IS NULL
		;
		/********** Amphetamine Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Amphetamine_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Amphetamine_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' OR HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%amph%'
			AND	TMP.Domain IS NULL 
		;
		/********** Phencyclidine Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Phencyclidine_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Phencyclidine_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' OR HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%phen%'
			AND	TMP.Domain IS NULL 
		;
		/********** Ethanol Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Ethanol_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Ethanol_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE  (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%etha%'
			AND	TMP.Domain IS NULL 
		;
		/********** Opiate Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Opiate_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Opiate_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%opia%' 
			AND	TMP.Domain IS NULL
		;
		/********** Benzodiazepine Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Benzodiazepine_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Benzodiazepine_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%benz%' 
			AND	TMP.Domain IS NULL
		;
		/********** Oxycodone Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_Oxycodone_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_Oxycodone_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
			AND HF.[HealthFactorType] not like '%alb%' 
			AND HF.[HealthFactorType] not like '%pro%'
			AND HF.[HealthFactorType] like '%oxyc%' 
			AND	TMP.Domain IS NULL
		;
		/**********  Urine Drug Screen **************/
		INSERT INTO #ListMember (List,ItemID,AttributeValue)
		SELECT DISTINCT 
			 'UDS_HF' 
			,HF.HealthFactorTypeSID 
			,HF.HealthFactorType
		FROM  [Dim].[HealthFactorType] HF
		LEFT OUTER JOIN #ListMember TMP 
			ON TMP.List =  'UDS_HF'
			AND TMP.ItemID = HF.HealthFactorTypeSID 
		WHERE (HF.[HealthFactorType] like '%outside%urine%' or HF.[HealthFactorType] like '%urine%outside%') 
		   AND HF.[HealthFactorType] not like '%alb%' 
		   AND HF.[HealthFactorType] not like '%pro%'
		   AND (	HF.[HealthFactorType] not like '%benz%'
				and HF.[HealthFactorType] not like '%oxyc%' 
				and HF.[HealthFactorType] not like '%opia%' 
				and HF.[HealthFactorType] not like '%etha%' 
				and HF.[HealthFactorType] not like '%phen%' 
				and HF.[HealthFactorType] not like '%amph%' 
				and HF.[HealthFactorType] not like '%meth%' 
				and HF.[HealthFactorType] not like '%coca%' 
				and HF.[HealthFactorType] not like '%barb%' 
				)
			AND	TMP.Domain IS NULL;

--Fill in additional fields for all of the above custom mappings
UPDATE #ListMember
SET  Domain = 'HealthFactorType'
	,Attribute = 'HealthFactorType'
	,ItemIDName = 'HealthFactorTypeSID'
	,CreatedDateTime = GETDATE()
	,MappingSource = 'LookUp_HealthFactor'
	,ApprovalStatus = 'Pending'

	
	--Category matches 
	INSERT INTO #ListMember (List,Domain,Attribute,ItemID,ItemIDName,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus)
	SELECT DISTINCT 
		lr.List 
		,Domain = 'HealthFactorType'
		,Attribute = 'HealthFactorType'
		,HF.HealthFactorTypeSID 
		,ItemIDName = 'HealthFactorTypeSID'
		,HF.HealthFactorType
		,CreatedDateTime = GETDATE()
		,MappingSource = 'LookUp_HealthFactor'
		,ApprovalStatus = 'Pending'
	FROM  [Dim].[HealthFactorType] HF WITH(NOLOCK)
	INNER JOIN [Dim].[HealthFactorType] C WITH(NOLOCK)
		ON HF.CategoryHealthFactorTypeSID = c.HealthFactorTypeSID
	INNER JOIN [Lookup].[ListMappingRule] lr WITH(NOLOCK)
		ON C.HealthFactorType LIKE lr.SearchTerm
	AND lr.Domain='HealthFactorCategory'
	AND HF.EntryType='Factor' AND c.EntryType='Category'

	INSERT INTO #ListMember (List,Domain,Attribute,ItemID,ItemIDName,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus)
	SELECT DISTINCT 
			lr.List 
		,lr.Domain
		,lr.Attribute
		,C.HealthFactorTypeSID 
		,ItemIDName = 'HealthFactorTypeSID'
		,C.HealthFactorType
		,CreatedDateTime = GETDATE()
		,MappingSource = 'LookUp_HealthFactor'
		,ApprovalStatus = 'Approved'
	FROM  [Dim].[HealthFactorType]  C
	INNER JOIN [Lookup].[ListMappingRule] lr
		ON C.HealthFactorType LIKE lr.SearchTerm
	AND lr.Domain='HealthFactorCategory'
	AND c.EntryType='Category'

----------------------------------------------------------------------------
-- PHASE 3: Find Members with No Mappings
 ----------------------------------------------------------------------------
 /*
	INSERT INTO #ListMember
	SELECT DISTINCT
		'Unknown'
		,'HealthFactorType'
		,HFT.HealthFactorTypeSID ItemID
		,HFT.HealthFactorType
		,GETDATE() AS [CreatedDateTime]
		,'No Match' AS [MappingSource]
		,'Pending' AS [ApprovalStatus]
		,NULL AS [ApprovedDateTime]
	FROM [Dim].[HealthFactorType] HFT
	LEFT OUTER JOIN #ListMember TMP 
			ON TMP.ItemID = HFT.HealthFactorTypeSID 

	WHERE 	TMP.ItemID IS NULL 
	*/
----------------------------------------------------------------------------
-- PHASE 4: Load Lookup.ListMember
-- Insert and Delete
 ----------------------------------------------------------------------------

	MERGE [Lookup].[ListMember] AS TARGET
	USING (SELECT DISTINCT * FROM #ListMember) AS SOURCE
			ON	TARGET.List = SOURCE.List
			AND TARGET.Domain = SOURCE.Domain
			AND TARGET.Attribute = SOURCE.Attribute
			AND TARGET.ItemID = SOURCE.ItemID
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (List,Domain,ItemID,ItemIDName,Attribute,AttributeValue,CreatedDateTime,MappingSource,ApprovalStatus,ApprovedDateTime) 
		VALUES (SOURCE.List,SOURCE.Domain,SOURCE.ItemID,SOURCE.ItemIDName,SOURCE.Attribute,SOURCE.AttributeValue
			,SOURCE.CreatedDateTime,SOURCE.MappingSource,SOURCE.ApprovalStatus,SOURCE.ApprovedDateTime) 
	WHEN NOT MATCHED BY SOURCE AND TARGET.Attribute = 'HealthFactorType' AND TARGET.List IN (SELECT List FROM #ListMember)
		THEN DELETE;

	DELETE FROM [Lookup].[ListMember]
	WHERE (
	 (List NOT IN (SELECT List FROM [Lookup].[ListMappingRule] WHERE Attribute = 'HealthFactorType') AND MappingSource IN ('Exact Match','Pattern Match')) --deleted from config
		OR (List NOT IN (SELECT List FROM #ListMember) AND MappingSource='LookUp_HealthFactor') --deleted from hard coded matches
		)
	AND Attribute = 'HealthFactorType'

	UPDATE [Lookup].[ListMember]
	SET ItemIDName='HealthFactorTypeSID'
	WHERE ItemIDName IS NULL AND Domain IN ('HealthFactorType','HealthFactorCategory')

	
	;

END