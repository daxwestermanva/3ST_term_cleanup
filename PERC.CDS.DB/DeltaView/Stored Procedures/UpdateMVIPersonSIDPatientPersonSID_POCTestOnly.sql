






/*******************************************************************
DESCRIPTION:	PERC CDS maintained crosswalk table from MVIPersonSID to harmonized
				PatientSIDs (from VistA CDW data) and PersonSIDs (from Cerner Millenium data)
				
LOGIC:			1.	Get "PatientPersonSID" and PatientICN from the source EHR table (e.g., 
					SPatient.SPatient for VistA)
				2.	Join to SVeteran.SMVIPerson using PatientICN to get the MVIPersonSID
				2b. If the PatientICN is not available (currently for some Cerner patients)
					then try to join to SMVIPerson using patient SSN.
				3.	Check SMVIPerson for deleted ICNs and get the new ICN, if available.

BUSINESS KEY:	PatientPersonSID (INT), which is either the PatientSID or the PersonSID. 
				You can tell the difference by Sta3n (all Cerner Millenium PersonSID
				will have Sta3n = 200). These will also all be greater than 1800000000.

MODIFICATIONS:
	2021-04-30	RAS	Developing initial code.
	2021-07-09	JEB	Initial creation
	2021-08-13  JEB Enclave Refactoring - Counts confirmed
	2021-09-15	RAS	Adding code to find and update deactived ICN values. 
				--	Merged comments and staging work from other version in CDSSbx.
	2021-10-16	AI	Fix LEFT() logic to only parse %V% alias
	2022-01-10	RAS	Updated section to get MVIPersonSID for Cerner Millenium PersonSIDs based on MillCDS_FactPatientDemographic
					SP, which looks first at a join on ICN, then uses SSN where ICN is not available.

	2022-01-26	RAS Changed initial join of SPatient to SMVIPerson to LEFT instead of INNER - not dropping patients
					who are not mapped to a valid MVIPersonSID. This aligns with previous PDW mapping table and allows for 
					downstream projects to determine how to handle these cases.
	2024-05-09	LM	Added row number to section for Millenium PersonSIDs to prevent error in case of multiple matches on verified SSN
	2024-05-20	LM	Allow Millenium PersonSID matches on SSNs not marked as verified if no verified matches exist
TEST:
	EXEC [DeltaView].[UpdateMVIPersonSIDPatientPersonSID_POCTestOnly]

EXAMPLES:
	SELECT TOP 1000 * FROM [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly]
	SELECT TOP 1000 * FROM [DeltaView].[MVIPersonSIDPatientPersonSIDLog_POCTestOnly] ORDER BY UpdateDate DESC


APPROX RUN TIME: Initial ~ 25 min
				 Subsequent ~ 4 min

DEPENDENCIES:
	Writes to:
		-- [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly]
		-- [DeltaView].[MVIPersonSIDPatientPersonSIDLog_POCTestOnly]
	Reads from:
		-- [SPatient].[SPatient]
		-- [SVeteran].[SMVIPerson] 
		-- [SVeteranMill].[SPerson]
		-- [SVeteranMill].[SPersonAlias]
		-- [NDimMill].[CodeValue] 

QUESTIONS/CONSIDERATIONS:
	2021-04-30 RAS: Can we exclude PatientICN from this table? 

TO DO:
	20xx-xx-xx	ABC To do comments
	2022-01-26	RAS	Add PublishedTable logging?  
*******************************************************************/
CREATE PROCEDURE [DeltaView].[UpdateMVIPersonSIDPatientPersonSID_POCTestOnly]
AS
BEGIN

	-----------EXEC [Log].[ExecutionBegin] 'EXEC Code.UpdateMVIPersonSIDPatientPersonSID','Execution of Code.UpdateMVIPersonSIDPatientPersonSID Stored Procedure'

	DROP TABLE IF EXISTS #StagePatientPersonSIDToMVI
	CREATE TABLE #StagePatientPersonSIDToMVI
	(
		PatientPersonSID		INT				--Business Key, Unique
		,Sta3n					SMALLINT
		,PatientICN				VARCHAR(50)
		,MVIPersonSID			INT
		,PrimaryPersonFullICN	VARCHAR(150)	-- RAS: Added 2021-09-15 to address deactived ICNStatus in next step.
		,ICNStatusCode			VARCHAR(25)		-- RAS: Added 2021-09-15 to address deactived ICNStatus in next step.
	)
	CREATE UNIQUE CLUSTERED INDEX [PK_StagePatientPersonSIDToMVI_PatientPersonSID] ON #StagePatientPersonSIDToMVI
	(	--JEB: Will be used to screen for bad data, if any
		[PatientPersonSID] ASC
	)

	----------------------------------------------------
	-- PatientSID and PersonSID to MVIPersonSID Mapping
	----------------------------------------------------
	INSERT INTO #StagePatientPersonSIDToMVI
		(PatientPersonSID,Sta3n,PatientICN,MVIPersonSID,PrimaryPersonFullICN,ICNStatusCode)
	-- RAS: VistA patients from CDWWork SPatient
	SELECT
		sp.PatientSID AS PatientPersonSID
		,sp.Sta3n
		,CASE WHEN sp.PatientICN IN ('*Missing*','*Unknown at this time*') THEN NULL 
			ELSE sp.PatientICN END
		,mvi.MVIPersonSID
		,mvi.PrimaryPersonFullICN
		,mvi.ICNStatusCode
	FROM [SPatient].[SPatient] sp WITH (NOLOCK)

	/*<Vista>INNER JOIN $DeltaKeyTable VDK WITH (NOLOCK) ON VDK.PatientSID = sp.PatientSID</Vista>*/

	LEFT JOIN [SVeteran].[SMVIPerson] mvi WITH (NOLOCK)
		ON mvi.MVIPersonICN = sp.PatientICN 
	/*
	-- RAS: Cerner Millenium patients from SPV2 SVeteranMill SPerson
	--      Code taken from MillCDS PatientDemographic code (decision to use original code here to limit dependencies)
	;WITH SSN AS (
		SELECT PersonSID
			,AliasName
			,AliasPool
		FROM [SVeteranMill].[SPersonAlias] pa WITH(NOLOCK)
		WHERE ActiveIndicator = 1
			AND GETDATE() BETWEEN BeginEffectiveDateTime AND EndEffectiveDateTime
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.PersonAliasTypeCodeValueSID = cv.CodeValueSID
					AND cv.CernerKnowledgeIndex = 'CKI.CODEVALUE!2626' -- SSN
					AND cv.ActiveIndicator = 1
				)	 
		)
	,ICN AS (
		SELECT PersonSID
			,AliasName
			,AliasPool
		FROM [SVeteranMill].[SPersonAlias] pa WITH(NOLOCK)		
		WHERE ActiveIndicator = 1
			AND GETDATE() BETWEEN BeginEffectiveDateTime AND EndEffectiveDateTime
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.PersonAliasTypeCodeValueSID = cv.CodeValueSID
					AND cv.CernerKnowledgeIndex = 'CKI.CODEVALUE!4202428988' --DisplayKey: VETERANID
					AND cv.ActiveIndicator = 1
				)	 
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.AliasPoolCodeValueSID = cv.CodeValueSID
					AND cv.CodeValueSetID = '263'
					AND cv.DisplayKey = 'ICN'
					AND cv.ActiveIndicator = 1
				) 
		)
	INSERT INTO #StagePatientPersonSIDToMVI
		(PatientPersonSID,Sta3n,PatientICN,MVIPersonSID,PrimaryPersonFullICN,ICNStatusCode)
	SELECT PatientPersonSID,Sta3n,PatientICN,MVIPersonSID,PrimaryPersonFullICN,ICNStatusCode FROM (
		SELECT DISTINCT a.PersonSID AS PatientPersonSID
				,200 AS Sta3n
				,IIF(ICN.AliasName LIKE '%V%', LEFT(ICN.AliasName,CHARINDEX('V',ICN.AliasName)-1), NULL) AS PatientICN 
				,COALESCE(mvi.MVIPersonSID,mvi2.MVIPersonSID,-2) AS MVIPersonSID --RAS: Keeps Cerner test patients (is this only needed for the B1930 data?)
				,mvi.PrimaryPersonFullICN	
				,mvi.ICNStatusCode		
				,ROW_NUMBER() OVER (PARTITION BY a.PersonSID 
									ORDER BY a.ModifiedDateTime DESC  --prioritize most recently modified match on ICN first
										,CASE WHEN mvi2.SSNVerificationStatus = 'VERIFIED' THEN 0 ELSE 1 END --then prioritize verified SSN if exists
										,mvi2.PersonModifiedDateTime DESC --then prioritize most recently modified match on SSN
									) AS RowOrderID
		FROM [SVeteranMill].[SPerson] a WITH(NOLOCK)

		/*<Mill>INNER JOIN $DeltaKeyTable MDK WITH(NOLOCK) ON MDK.PersonSID = a.PersonSID</Mill>*/

		LEFT JOIN ICN ON ICN.PersonSID = a.PersonSID
		LEFT JOIN SSN ON SSN.PersonSID = a.PersonSID
		LEFT JOIN [SVeteran].[SMVIPerson] mvi WITH(NOLOCK) ON mvi.MVIPersonFullICN = ICN.AliasName
		LEFT JOIN (SELECT * FROM [SVeteran].[SMVIPerson]  WITH(NOLOCK)
					WHERE ICNStatus = 'PERMANENT' /*Joining on SSN could cause dups if a person has DEACTIVATED records in MVI data. */
					AND (SSNVerificationStatus <> 'INVALID PER SSA' OR SSNVerificationStatus IS NULL) /*Making sure we are only joining on valid SSNs.*/
					)	mvi2 /*Secondary join to grab MVIPersonSID if ICN is not available in Cerner data. */
			ON SSN.AliasName = mvi2.PersonSSN
			AND ICN.AliasName IS NULL						/*Only need to try this join if we don't have an ICN value in Cerner data. */
		WHERE a.PersonSID > 0 -- missing and unknown values are represented by -1 and 0. This results in duplicate PersonSID which should be the primary key for the insert
	) x
	WHERE RowOrderID=1 --Prevent multiple matches on PersonSSN
	*/

	/***************************************************************************************************************/

	DROP TABLE IF EXISTS #MILLTEMP;

	;WITH SSN AS (
		SELECT PersonSID
			,AliasName
			,AliasPool
		FROM [SVeteranMill].[SPersonAlias] pa WITH(NOLOCK)
		WHERE ActiveIndicator = 1
			AND GETDATE() BETWEEN BeginEffectiveDateTime AND EndEffectiveDateTime
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.PersonAliasTypeCodeValueSID = cv.CodeValueSID
					AND cv.CernerKnowledgeIndex = 'CKI.CODEVALUE!2626' -- SSN
					AND cv.ActiveIndicator = 1
				)	 
		)
	,ICN AS (
		SELECT PersonSID
			,AliasName
			,AliasPool
		FROM [SVeteranMill].[SPersonAlias] pa WITH(NOLOCK)		
		WHERE ActiveIndicator = 1
			AND GETDATE() BETWEEN BeginEffectiveDateTime AND EndEffectiveDateTime
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.PersonAliasTypeCodeValueSID = cv.CodeValueSID
					AND cv.CernerKnowledgeIndex = 'CKI.CODEVALUE!4202428988' --DisplayKey: VETERANID
					AND cv.ActiveIndicator = 1
				)	 
			AND EXISTS (
				SELECT 1 
				FROM [NDimMill].[CodeValue] cv WITH(NOLOCK)
				WHERE pa.AliasPoolCodeValueSID = cv.CodeValueSID
					AND cv.CodeValueSetID = '263'
					AND cv.DisplayKey = 'ICN'
					AND cv.ActiveIndicator = 1
				) 
		)


	SELECT DISTINCT a.PersonSID AS PatientPersonSID
			,200 AS Sta3n
			,IIF(ICN.AliasName LIKE '%V%', LEFT(ICN.AliasName,CHARINDEX('V',ICN.AliasName)-1), NULL) AS PatientICN 
			--,COALESCE(mvi.MVIPersonSID,mvi2.MVIPersonSID,-2) AS MVIPersonSID --RAS: Keeps Cerner test patients (is this only needed for the B1930 data?)				
			,a.PersonSID 
			,a.ModifiedDateTime				
			,SSNAliasName = SSN.AliasName
			,ICNAliasName = ICN.AliasName
			,mvi.MVIPersonSID
			,mvi.PrimaryPersonFullICN	
			,mvi.ICNStatusCode						
			/*,ROW_NUMBER() OVER (PARTITION BY a.PersonSID 
								ORDER BY a.ModifiedDateTime DESC  --prioritize most recently modified match on ICN first
									,CASE WHEN mvi2.SSNVerificationStatus = 'VERIFIED' THEN 0 ELSE 1 END --then prioritize verified SSN if exists
									,mvi2.PersonModifiedDateTime DESC --then prioritize most recently modified match on SSN
								) AS RowOrderID*/	
	INTO #MILLTEMP
	FROM [SVeteranMill].[SPerson] a WITH(NOLOCK)

	---------INNER JOIN [DeltaView].[DeltaKey_Mill_UpdateMVIPersonSIDPatientPersonSID_POCTestOnly] MDK WITH(NOLOCK) ON MDK.PersonSID = a.PersonSID

	/*<Mill>INNER JOIN $DeltaKeyTable MDK WITH(NOLOCK) ON MDK.PersonSID = a.PersonSID</Mill>*/
	LEFT JOIN ICN ON ICN.PersonSID = a.PersonSID
	LEFT JOIN SSN ON SSN.PersonSID = a.PersonSID
	LEFT JOIN [SVeteran].[SMVIPerson] mvi WITH(NOLOCK) ON mvi.MVIPersonFullICN = ICN.AliasName
	/*LEFT JOIN (SELECT MVIPersonSID, PersonSSN, SSNVerificationStatus, PersonModifiedDateTime  FROM [SVeteran].[SMVIPerson]  WITH(NOLOCK)
				WHERE ICNStatus = 'PERMANENT' /*Joining on SSN could cause dups if a person has DEACTIVATED records in MVI data. */
				AND (SSNVerificationStatus <> 'INVALID PER SSA' OR SSNVerificationStatus IS NULL) /*Making sure we are only joining on valid SSNs.*/
				)	mvi2 /*Secondary join to grab MVIPersonSID if ICN is not available in Cerner data. */
		ON SSN.AliasName = mvi2.PersonSSN
		AND ICN.AliasName IS NULL	*/					/*Only need to try this join if we don't have an ICN value in Cerner data. */
	WHERE 
		a.PersonSID > 0; -- missing and unknown values are represented by -1 and 0. This results in duplicate PersonSID which should be the primary key for the insert


	--SELECT * FROM #MILLTEMP

	INSERT INTO #StagePatientPersonSIDToMVI(
		PatientPersonSID,
		Sta3n,
		PatientICN,
		MVIPersonSID,
		PrimaryPersonFullICN,
		ICNStatusCode
	)
	SELECT 
		PatientPersonSID,
		Sta3n,
		PatientICN, 
		MVIPersonSID_DERIVED, 
		PrimaryPersonFullICN,
		ICNStatusCode 
	FROM 
	(
		SELECT
			L2.*,
			COALESCE(L2.MVIPersonSID,L2.mvi2MVIPersonSID,-2) AS MVIPersonSID_DERIVED, --RAS: Keeps Cerner test patients (is this only needed for the B1930 data?)
			ROW_NUMBER() OVER (PARTITION BY L2.PersonSID 
											ORDER BY L2.ModifiedDateTime DESC  --prioritize most recently modified match on ICN first
												,CASE WHEN L2.mvi2SSNVerificationStatus = 'VERIFIED' THEN 0 ELSE 1 END --then prioritize verified SSN if exists
												,L2.mvi2PersonModifiedDateTime DESC --then prioritize most recently modified match on SSN
											) AS RowOrderID
		FROM
		(
			SELECT 
				L.*,
				mvi2MVIPersonSID = mvi2.MVIPersonSID,
				mvi2SSNVerificationStatus = mvi2.SSNVerificationStatus,
				mvi2PersonModifiedDateTime = mvi2.PersonModifiedDateTime
			FROM 
				#MILLTEMP L
				LEFT JOIN (SELECT MVIPersonSID, PersonSSN, SSNVerificationStatus, PersonModifiedDateTime  FROM [SVeteran].[SMVIPerson]  WITH(NOLOCK)
								WHERE ICNStatus = 'PERMANENT' /*Joining on SSN could cause dups if a person has DEACTIVATED records in MVI data. */
								AND (SSNVerificationStatus <> 'INVALID PER SSA' OR SSNVerificationStatus IS NULL) /*Making sure we are only joining on valid SSNs.*/
								)	mvi2 /*Secondary join to grab MVIPersonSID if ICN is not available in Cerner data. */
						ON L.SSNAliasName = mvi2.PersonSSN
						AND L.ICNAliasName IS NULL			
						/*<Mill>AND mvi2.PersonSSN IN (
							SELECT SSNAliasName FROM #MILLTEMP WHERE ICNAliasName IS NULL
							INTERSECT
							SELECT PersonSSN FROM [SVeteran].[SMVIPerson]  WITH(NOLOCK)
						)</Mill>*/
		) L2
	) L3
	WHERE 
		L3.RowOrderID=1




	/***************************************************************************************************************/


	-- Some Cerner Millenium patients can be mapped to an MVIPersonSID, but not a PatientICN from the Mill source tables
	-- so add a PatientICN here if possible
	UPDATE #StagePatientPersonSIDToMVI
	SET PatientICN = sv.MVIPersonICN
		--SELECT c.*
		--	,sv.MVIPersonICN
		--	,sv.ICNStatus
	FROM #StagePatientPersonSIDToMVI c 
	INNER JOIN [SVeteran].[SMVIPerson] sv ON sv.MVIPersonSID = c.MVIPersonSID
	WHERE c.PatientICN IS NULL
		AND c.MVIPersonSID > 0

	---------------------------------------------------------------------
	-- FIND DEACTIVATED ICNs AND REMAP TO NEW ICN, IF AVAILABLE
	---------------------------------------------------------------------
	-- Records with deactivated ICNs have a PrimaryPersonFullICN that can be used to determine the "new" ICN
	-- We are making an assumption here that the PatientPersonSID associated with the "old" ICN should be mapped 
	-- to the "new ICN."  This is the best guess until the SPatient record is updated.  It is possible that
	-- the PatientPersonSID in question could be remappped to a completely different ICN (neither the old nor new).

	DROP TABLE IF EXISTS #BadICN;
	SELECT a.PatientPersonSID
		,a.Sta3n
		,PatientICN = mvi.MVIPersonICN
		,mvi.MVIPersonSID
		,mvi.PrimaryPersonFullICN
		,mvi.ICNStatusCode
		--,a.PatientICN
		--,a.MVIPersonSID
		--,a.PrimaryPersonFullICN
		--,a.ICNStatusCode 
	INTO #BadICN
	FROM #StagePatientPersonSIDToMVI a
	INNER JOIN [SVeteran].[SMVIPerson] mvi ON mvi.MVIPersonFullICN=a.PrimaryPersonFullICN
	WHERE a.ICNStatusCode = 'D' AND mvi.ICNStatusCode <> 'D'
	-- 15989 with status 'D', but 101 do not have new ICN

	DELETE #StagePatientPersonSIDToMVI WHERE PatientPersonSID IN (SELECT PatientPersonSID FROM #BadICN)
	
	INSERT INTO #StagePatientPersonSIDToMVI 
		(PatientPersonSID,Sta3n,PatientICN,MVIPersonSID,PrimaryPersonFullICN,ICNStatusCode)
	SELECT PatientPersonSID,Sta3n,PatientICN,MVIPersonSID,PrimaryPersonFullICN,ICNStatusCode 
	FROM #BadICN
	
	DROP TABLE #BadICN

	---------------------------------------------------------------------
	---- JEB: The following logic can also be used to screen out 'bad' data. In theory, everything should be distinct.
	----      So we could engineer a process to surface these, or we can let the process break and have temporary stale data until the issue is resolved, 
	----      usually to be resolved upstream outside of this process.
	--SELECT
	--	PatientPersonSID, Sta3n, PatientICN, MVIPersonSID 
	--FROM #StagePatientPersonSIDToMVI
	--GROUP BY 
	--	PatientPersonSID, Sta3n, PatientICN, MVIPersonSID 
	--HAVING COUNT(1) > 1
	---------------------------------------------------------------------

	----------------------------------------------------
	-- UPDATE TABLE AND LOG TABLE
		-- RAS: Using merge and logging table in order to track changes to the data. 
			-- It seems inevitable that questions will arise, but maybe we can 
			-- reevaluate the need for saving history in the future 
			-- (or at least implement a cutoff date for deleting history).
	----------------------------------------------------
	-- PREP FOR MERGE: UPDATE NULL FIELDS -- RAS Added 2022-01-26
	-- Merging will not work correctly if it is trying to match on NULL values, but since
	-- we want to keep all PatientPersonSIDs regardless of MVIPersonSID/PatientICN values
	-- we need to fill in a value here when one of these is missing
		--	SELECT count(*) FROM #StagePatientPersonSIDToMVI WHERE (MVIPersonSID IS NULL OR PatientICN IS NULL)
			-- 5456614
			-- 5212745 of these are from Millenium data
			--  243869 of these are from VistA data -- 88632 with PatientICN
	UPDATE #StagePatientPersonSIDToMVI
	SET MVIPersonSID = 0 
	WHERE MVIPersonSID IS NULL

	UPDATE #StagePatientPersonSIDToMVI
	SET PatientICN = '0' 
	WHERE PatientICN IS NULL

		 --SELECT * FROM #StagePatientPersonSIDToMVI WHERE (PatientICN = '0' OR MVIPersonSID = 0)
			--AND Sta3n <> 200
		 --SELECT DISTINCT PatientICN,MVIPersonSID FROM #StagePatientPersonSIDToMVI WHERE (PatientICN = '0' OR MVIPersonSID = 0)
			--ORDER BY PatientICN


	-- MAIN MERGE SECTION
	DECLARE @UpdateDate DATETIME2(0) = GETDATE();
	BEGIN TRY
		BEGIN TRANSACTION
		DECLARE @MergeOutput TABLE (
			ActionType			VARCHAR(50)
			,PatientPersonSID	INT NOT NULL
 			,Sta3n				SMALLINT
			,PatientICN			VARCHAR(50)
			,MVIPersonSID		INT
			);
		
			MERGE [DeltaView].[MVIPersonSIDPatientPersonSID_POCTestOnly] WITH(TABLOCK) t USING #StagePatientPersonSIDToMVI s
				ON (s.PatientPersonSID = t.PatientPersonSID) 
				-- only match on PatientPersonSID because only want 1 row per PatientPersonSID and other changes logged as updates, not inserts or deletes.
			WHEN MATCHED 
				AND NOT EXISTS ( -- only update if a value in the row has changed
					SELECT t.PatientPersonSID, t.Sta3n, t.PatientICN, t.MVIPersonSID
					INTERSECT
					SELECT s.PatientPersonSID, s.Sta3n, s.PatientICN, s.MVIPersonSID
					)
				THEN UPDATE 
				SET Sta3n = s.Sta3n
					,PatientICN = s.PatientICN
					,MVIPersonSID = s.MVIPersonSID
					,UpdateDate = @UpdateDate
			WHEN NOT MATCHED BY TARGET -- RAS: Add new rows (where the PatientSID or PersonSID did not exist in the table previously)
				THEN INSERT (PatientPersonSID, Sta3n, PatientICN, MVIPersonSID, UpdateDate)
					VALUES (s.PatientPersonSID, s.Sta3n, s.PatientICN, s.MVIPersonSID, @UpdateDate)
			
			/*WHEN NOT MATCHED BY SOURCE  -- RAS: Delete rows where the PatientSID or PersonSID no longer exists in the source data
				THEN DELETE	*/
				
			OUTPUT -- RAS: Save the output to the MergeOutput table for review and logging
				$action AS ActionType
				,ISNULL(inserted.PatientPersonSID, deleted.PatientPersonSID) 
				,ISNULL(inserted.Sta3n, deleted.Sta3n) 
				,ISNULL(inserted.PatientICN, deleted.PatientICN)
				,ISNULL(inserted.MVIPersonSID, deleted.MVIPersonSID) 
			INTO @MergeOutput
			;

			-- RAS: Main table will always have current data, but history of changes is saved to log
			--      table with this section.
			INSERT INTO [DeltaView].[MVIPersonSIDPatientPersonSIDLog_POCTestOnly] WITH(TABLOCK)
			SELECT
				PatientPersonSID	
				,Sta3n				
				,PatientICN			
				,MVIPersonSID		
				,UpdateDate	= @UpdateDate		
				,UpdateCode	= CASE WHEN ActionType = 'INSERT' THEN 'I'
					WHEN ActionType = 'DELETE' THEN 'D'
					WHEN ActionType = 'UPDATE' THEN 'U'
					END
			FROM @MergeOutput

		COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			PRINT 'Error occurred within transaction; transaction rolled back';
			-------EXEC [Log].[ExecutionEnd] @Status = 'Error';
			THROW; 
		END CATCH

	DROP TABLE IF EXISTS #StagePatientPersonSIDToMVI


	-------EXEC [Log].[ExecutionEnd]

END