

/*--=============================================
   Author:      Catherine Barry (based on Present.MentalHealthAssistant)
   Create date: 9/13/19
   Description: Create OMHSP_STANDARD table of MHA questions & responses for surveys of interest 
   Current Categories: 
  				PHQ-2+I9, PC-PTSD-5+I9, C-SSRS, I9+C-SSRS, PHQ9, AUDC
   Modifications: 9/26/19	CNB	Added code to remove future surveydatetimes. Future survey dates don't makes sense. 
  				 12/18/19	CNB	Corrected code that wasn't pulling I9+C-SSRS surveys (but should have been). Now uses: OR ll.list='Survey_I9CSSRS_MHA'
								Corrected more code (in final step) that wasn't inclusive enough to include the 'I9 and CSSRS' surveys
				 04/10/20	LM	Added DISTINCT to final step to remove duplicate values
				 06/15/20	MP	Added Audit-C Survey data and calculate scores per person per surveydate
				 08/21/20	RAS	Added logging and NOLOCKs
				 09/17/20	MP	Corrected Audit-C section to use RawScore instead of calculated score (these results see to be more inclusive/complete)
				 11/23/20	LM	Overlay of Cerner data - CSSRS and AUDIT-C
				 01/11/21	LM	Overlay of Cerner data - I9
				 02/24/21	CNB Included LocationSID in final tables
				 04/28/21	LM	Extended lookback period to 3 years
				 05/06/21	LM	Temporarily pulling CSSRS recent data from another source that pulls from SPVNext; data in MH.SurveyAnswer is currently stale since 4/23
				 05/17/21	LM	Added MH screening from health factors; reworked code for efficiency
				 06/21/21	LM	Removed temporary method of pulling recent CSSRS data
				 08/25/21	JEB Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
				 12/22/21	LM	Reduced lookback period to 2 years
				 05/17/22	RAS	Added initial build parameter to only look back 3 months and replace that data instead of doing entire 2 year full reload.
				 05/17/23	LM	Added COWS, CIWA, and PHQ9 assessments
				 01/03/24   CW  Added PTSD assessments
				 02/06/24	LM	Restructured for faster run time
				 02/07/24	LM	Added PHQ2
				 02/12/24	LM	Remove Detail table
				 02/12/24	LM	Include past 5 years of data. Nightly run will update past 3 months and weekly run will update past 2 years. Data 3-5 years old will remain stale unless manually refreshed with @InitialBuild=2
				 04/09/24	LM	Add Location SID value from Oracle Health/Cerner data
				 09/16/24	LM	Add BHL data from Cerner
Testing execution:
	EXEC [Code].[OMHSP_Standard_MentalHealthAssistant_v02] @InitialBuild=1

Helpful Auditing Scripts

	SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
	FROM [Log].[ExecutionLog] WITH (NOLOCK)
	WHERE name LIKE 'EXEC Code.OMHSP_Standard_MentalHealthAssistant%'
	ORDER BY ExecutionLogID DESC

	SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName IN ('MentalHealthAssistant_v02','MentalHealthAssistantDetail_v02') ORDER BY 1 DESC

--=============================================*/ 
CREATE PROCEDURE [Code].[OMHSP_Standard_MentalHealthAssistant_v02]
	@InitialBuild TINYINT = 0
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_MentalHealthAssistant','Execution of Code.OMHSP_Standard_MentalHealthAssistant SP'

	--DECLARE @InitialBuild TINYINT = 0
	DECLARE @BeginDate DATE 
	DECLARE @EndDate DATE
	DECLARE @PastTwoYears DATE = DATEADD(Year,-2,CAST(GETDATE() AS DATE))
	DECLARE @PastFiveYears DATE = DATEADD(Year,-5,CAST(GETDATE() AS DATE))

	IF (SELECT COUNT(*) FROM OMHSP_Standard.MentalHealthAssistant_v02 WHERE SurveyGivenDatetime<@PastTwoYears)<1000000 --if missing data >2 years old, populate with past 5 years of data
	BEGIN SET @InitialBuild = 2
	END;

	IF @InitialBuild = 1 --weekly reload of most recent 2 years of data; 3-5 year old data remains stale
	BEGIN
		SET @BeginDate = @PastTwoYears
		SET @EndDate = CAST(GETDATE() AS DATE)
	END
	ELSE IF @InitialBuild = 2 --if table is empty load with 5 years of data
	BEGIN
		SET @BeginDate = @PastFiveYears
		SET @EndDate = CAST(GETDATE() AS DATE)
	END
	ELSE --nightly reload of past 3 months of data; older data remains stale
	BEGIN
		SET @BeginDate = DATEADD(MONTH,-3,CAST(GETDATE() AS DATE))
		SET @EndDate = CAST(GETDATE() AS DATE)
	END

	/*--=============================================
	STEPS 1-5: PULL DATA FROM VISTA

	Step 1
	FIRST START with the reference cohort 
	--=============================================*/ 

	-- Step 1a. create table to identify relevant SIDs, Category, List, Printname for MHA Surveys of interest items
	DROP TABLE IF EXISTS #svys;
	SELECT 
		 ll.Category
		,lm.List
		,lm.Domain
		,lm.ItemID
		,lm.AttributeValue
		,lm.Attribute
		,ll.Printname
		--,ll.Description
		,CASE WHEN lm.Domain='SurveyChoice' THEN 1 ELSE 0 END AS AnswerFlag
		,CASE WHEN lm.Domain='SurveyQuestion' THEN 1 ELSE 0 END AS QuestionFlag 
		,CASE WHEN lm.Domain='Survey' THEN 1 ELSE 0 END AS SurveyFlag
	INTO #svys
	FROM [Lookup].[ListMember] lm WITH (NOLOCK)
	INNER JOIN [Lookup].[List] ll WITH (NOLOCK) 
		ON lm.List = ll.List
	WHERE ll.Category IN ('MHA','CSSRS', 'I9', 'AUDC','I9 and CSSRS', 'Standalone I9', 'COWS', 'PHQ9', 'CIWA', 'PTSD','PHQ2') 

	DROP TABLE IF EXISTS #Location
	SELECT loc.LocationSID
		,loc.Sta3n
		,sta6.ChecklistID
	INTO #Location
	FROM [Dim].[Location] loc WITH (NOLOCK)
	INNER JOIN [Dim].[Division] div WITH (NOLOCK) 
		ON loc.DivisionSID = div.DivisionSID
	LEFT JOIN [LookUp].[Sta6a] sta6 WITH (NOLOCK) 
		ON div.sta6a = sta6.sta6a

	--Step 2: Get SID values for cohort, surveys, and survey questions
	DROP TABLE IF EXISTS #FirstSIDs
	SELECT 
		mvi.MVIPersonSID
		,mp.PatientICN
		,sadm.PatientSID
		,sadm.Sta3n
		,ISNULL(l.ChecklistID, sadm.Sta3n) AS ChecklistID
		,sadm.SurveySID
  		,sadm.SurveyAdministrationSID 
		,sadm.LocationSID 
		,sadm.SurveyGivenDateTime 
		,sadm.SurveyName
		,CASE WHEN SurveyName IN ('PHQ-2','PHQ-2+I9') AND q.Category='PHQ9' THEN 'PHQ2' ELSE q.Category END AS Category
		,mp.Gender
	INTO #FirstSIDs
	FROM [MH].[SurveyAdministration] sadm WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON sadm.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #svys q 
		ON sadm.SurveySID = q.ItemID AND q.SurveyFlag=1
	INNER JOIN #Location l
		ON sadm.LocationSID = l.LocationSID
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) 
		ON mvi.MVIPersonSID = mp.MVIPersonSID
	WHERE sadm.SurveyGivenDateTime BETWEEN @BeginDate AND @EndDate
	
	--Step 3: Add response level details
	DROP TABLE IF EXISTS #SurveyResponses
	SELECT a.SurveyAdministrationSID
		,b.Category
		,b.List
		,b.ItemID
		,b.AttributeValue
		,b.PrintName
		--,c.Category AS Category2
		,c.List AS List2
		,c.AttributeValue AS AttributeValue2
		--,c.ItemID AS ItemID2
		,c.PrintName AS PrintName2
		--,a.SurveyQuestionSID
		--,a.SurveyChoiceSID
	INTO #SurveyResponses
	FROM [MH].[SurveyAnswer] a WITH (NOLOCK)
	INNER JOIN #svys b 
		ON a.SurveyQuestionSID = b.ItemID AND b.QuestionFlag=1
	INNER JOIN #FirstSIDs f 
		ON a.SurveyAdministrationSID = f.SurveyAdministrationSID 
	INNER JOIN #svys c
		ON a.SurveyChoiceSID = c.ItemID AND c.AnswerFlag=1

	/*****************************************/
	--Step 4: Calculate Scores
	/*****************************************/
	--Step 4a: Get raw score from SurveyResult table
	DROP TABLE IF EXISTS #RawScore;
	SELECT 
		a.SurveyAdministrationSID
		,a.SurveyName
		,MAX(a.RawScore) AS RawScore
	INTO #RawScore
	FROM [MH].[SurveyResult] a WITH (NOLOCK)
	INNER JOIN #FirstSIDs b 
		ON a.SurveyAdministrationSID = b.SurveyAdministrationSID
	GROUP BY a.SurveyAdministrationSID, a.SurveyName

	DROP TABLE IF EXISTS #LegacyScore
	SELECT DISTINCT a.SurveyAdministrationSID
			,a.SurveyName
			,cho.LegacyValue
			,a.SurveyAnswerSID
	INTO #LegacyScore
	FROM [MH].[SurveyAnswer] a WITH(NOLOCK)
	INNER JOIN #FirstSIDS b
	ON a.SurveyAdministrationSID = b.SurveyAdministrationSID
	INNER JOIN [Dim].[SurveyChoice] cho WITH (NOLOCK)
	ON a.SurveyChoiceSID = cho.SurveyChoiceSID	
	
	--Step 4b: Use RawScore if available; if not, calculate score using LegacyValue	
	DROP TABLE IF EXISTS #CombineRawScores
	SELECT 
		 ISNULL(c.SurveyAdministrationSID,b.SurveyAdministrationSID) AS SurveyAdministrationSID
		 ,ISNULL(c.SurveyName,b.SurveyName) AS SurveyName
		 ,ISNULL(c.RawScore, b.LegacyScore) AS RawScore
	INTO #CombineRawScores
	FROM  #RawScore c
	FULL OUTER JOIN (
			SELECT a.SurveyAdministrationSID
			,a.SurveyName
			,SUM(TRY_CAST(a.LegacyValue AS int)) AS LegacyScore
		FROM #LegacyScore a 
		GROUP BY a.SurveyAdministrationSID , a.SurveyName
		) b 
	ON c.SurveyAdministrationSID = b.SurveyAdministrationSID;
		
	DROP TABLE IF EXISTS #RawScore

	/****************************************/
	--Step 5: IDENTIFY POSITIVE SCREENS*/
	/*****************************************/
	-- A positive I9 is a response of Several days, more than half the days, or nearly every day to the I9 question
	-- A Positive C-SSRS is a positive response to questions 3, 4, 5, or 8; see http://vaww.visn19.portal.va.gov/sites/ECHCS/srsa/_layouts/15/start.aspx#/Shared%20Documents/Forms/AllItems.aspx?RootFolder=%2Fsites%2FECHCS%2Fsrsa%2FShared%20Documents%2FGuidance%20Documents&FolderCTID=0x012000BA36E0DB736F7149A39A2E1CD6A8E804&View=%7B1114B7F2%2D95A5%2D41AF%2D8828%2D2734026C14D6%7D 
	-- A positive AUDIT-C is a score of:
		--(1)mild: 4 for men, 3-4 for women 
		--(2)moderate: 5-7 
		--(3)severe: 8 +
	--A positive PHQ9 is a score of: https://coepes.nih.gov/sites/default/files/2020-12/PHQ-9%20depression%20scale.pdf
		--(1)minimal: 5-9
		--(2)minor depression: 10-14
		--(3)major depression, moderately severe: 15-19
		--(4)major depression, severe: 20+
	--All scored CIWA and COWS surveys are marked as 1 (positive) currently
	--A positive PC-PTSD-5 is a score of 4 or greater

	DROP TABLE IF EXISTS #AddDisplayCategories
	SELECT  
		 a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID AS PatientPersonSID
		,a.Sta3n
		,a.ChecklistID
		,a.LocationSID
		,CAST(a.SurveyAdministrationSID AS BIGINT) AS SurveyAdministrationSID
		,a.SurveyGivenDateTime
		,CAST(a.SurveyName AS VARCHAR(100)) AS SurveyName
		--,sr.SurveyQuestionSID
		,sr.itemid 
		,CASE WHEN SurveyName IN ('PHQ-2','PHQ-2+I9') AND ISNULL(sr.Category,a.Category)='PHQ9' THEN 'PHQ2' 
			ELSE ISNULL(sr.Category,a.Category) END AS Category
		,sr.List
		,sr.PrintName
		--,sr.SurveyChoiceSID
		--,sr.Itemid2
		--,sr.Category2
		,sr.List2
		,sr.PrintName2  
		,CAST('MHA' AS VARCHAR(15)) AS DataSource
		,a.Gender
	INTO #AddDisplayCategories
	FROM #FirstSIDs a
	LEFT JOIN #SurveyResponses sr 
		ON sr.SurveyAdministrationSID = a.SurveyAdministrationSID

		

	DROP TABLE IF EXISTS #FirstSIDs
	DROP TABLE IF EXISTS #SurveyResponses

	DROP TABLE IF EXISTS #AddScoring
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientPersonSID
		,a.Sta3n
		,a.ChecklistID
		,a.LocationSID
		,LocationSIDType=CAST('LocationSID' AS varchar(30))
		,a.SurveyAdministrationSID
		,a.SurveyGivenDateTime
		,a.SurveyName
		,CASE WHEN a.List='I9_Q_MHA' THEN 'I9' ELSE a.Category END AS Category  
		,a.DataSource
		,CASE WHEN a.List='I9_Q_MHA' AND a.List2 = 'Answer_NotAtAll_MHA' THEN 0
			WHEN a.List='I9_Q_MHA' AND a.List2 = 'Answer_SeveralDays_MHA' THEN 1
			WHEN a.List='I9_Q_MHA' AND a.List2 = 'Answer_MoreThanHalfTheDays_MHA' THEN 2
			WHEN a.List='I9_Q_MHA' AND a.List2 = 'Answer_NearlyEveryDay_MHA' THEN 3
			WHEN a.List='I9_Q_MHA' THEN -99
			WHEN a.List='PTSD_Q0_MHA' AND a.List2='Answer_No_MHA' THEN 0 --No to Q0 is a negative screen for PTSD
			ELSE ISNULL(r.RawScore, -99) END AS RawScore -- score of -99 for non-Audit-C rows or incomplete AUD-C
		,display_I9= CASE WHEN Category <> 'I9' THEN -1 --Means 'not applicable' because the row refers to the other survey 
			WHEN a.List='I9_Q_MHA' AND a.List2 in ('Answer_SeveralDays_MHA','Answer_MoreThanHalfTheDays_MHA','Answer_NearlyEveryDay_MHA')
			THEN 1 /*1 is a POSITIVE I9*/
			WHEN a.List='I9_Q_MHA' AND a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA','Answer_NotAsked_MHA') 
			THEN -99 /* -99 is Missing, Unknown, or Skipped */
			WHEN a.List<>'I9_Q_MHA' OR a.List IS NULL
			THEN -1 
			ELSE 0 END
		,display_CSSRS = CASE WHEN a.Category <> 'CSSRS' THEN -1 --Means 'not applicable' because the row refers to the other survey 
			WHEN a.List in ('CSSRS_Q3_MHA','CSSRS_Q4_MHA','CSSRS_Q5_MHA','CSSRS_Q8_MHA') AND a.List2='Answer_Yes_MHA'
			THEN 1 /*1 is a POSITIVE CSSRS*/
			WHEN a.List in ('CSSRS_Q3_MHA','CSSRS_Q4_MHA','CSSRS_Q5_MHA','CSSRS_Q8_MHA') AND 
				 a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA')
			THEN -99 /* -99 is Missing, Unknown, or Skipped */
			WHEN a.List IS NULL THEN -1
			ELSE 0  END
		,display_AUDC = CASE WHEN a.Category <> 'AUDC' THEN -1  --refers to a different survey 
			WHEN RawScore=-99 THEN -99
			WHEN ((r.RawScore < 4 AND a.Gender = 'M') OR (r.RawScore < 3 AND a.Gender = 'F'))
				THEN 0 --negative 
			WHEN ((r.RawScore = 4 AND a.Gender = 'M') OR (r.RawScore in (3,4) AND a.Gender = 'F'))
				THEN 1 --mild 
			WHEN r.RawScore in (5,6,7)
				THEN 2 --moderate
			WHEN r.RawScore > 7
				THEN 3 --severe
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99 
			WHEN a.List2 IS NULL THEN -1
			END 
		,display_COWS = CASE WHEN a.Category <> 'COWS' THEN -1 
			WHEN r.RawScore=-99 THEN -99
			WHEN r.RawScore IS NOT NULL THEN 1
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99 
			WHEN a.List2 IS NULL THEN -1
			END
		,display_CIWA = CASE WHEN a.Category <>'CIWA' THEN -1 
			WHEN r.RawScore=-99 THEN -99
			WHEN r.RawScore IS NOT NULL THEN 1
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99 
			WHEN a.List2 IS NULL THEN -1
			END
		,display_PHQ2 = CASE WHEN a.Category <> 'PHQ2' THEN -1
			WHEN RawScore=-99 THEN -99
			WHEN RawScore<3 THEN 0
			WHEN RawScore>=3 THEN 1
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99 
			WHEN a.List2 IS NULL THEN -1
			END
		,display_PHQ9 = CASE WHEN a.Category <> 'PHQ9' THEN -1 --https://coepes.nih.gov/sites/default/files/2020-12/PHQ-9%20depression%20scale.pdf
			WHEN r.RawScore=-99 THEN -99
			WHEN r.RawScore < 5 THEN 0
			WHEN r.RawScore <10 THEN 1
			WHEN r.RawScore < 15 THEN 2
			WHEN r.RawScore < 20 THEN 3 
			WHEN r.RawScore >= 20 THEN 4 
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99 
			WHEN a.List2 IS NULL THEN -1
			END
		,display_PTSD = CASE WHEN a.Category <> 'PTSD' THEN -1
			WHEN a.List='PTSD_Q0_MHA' AND a.List2='Answer_No_MHA' THEN 0 --No to Q0 is a negative screen
			WHEN r.RawScore=-99 THEN -99
			WHEN r.RawScore < 4 THEN 0 --negative
			WHEN r.RawScore >= 4 THEN 1 --positive
			WHEN a.List2 in ('Answer_Unknown_MHA','Answer_Skipped_MHA','Answer_Missing_MHA') THEN -99
			WHEN a.List2 IS NULL THEN -1
			END
	INTO #AddScoring
	FROM #AddDisplayCategories a
	LEFT JOIN #CombineRawScores r ON a.SurveyAdministrationSID = r.SurveyAdministrationSID

	DROP TABLE IF EXISTS #CombineRawScores
	DROP TABLE IF EXISTS #AddDisplayCategories

	--Some questions with the same SID value are in multiple surveys causing a mixup in the results. 
	--Also a handful of cases where survey questions unrelated to the survey administered are present. Delete irrelevant responses
	DELETE FROM #AddScoring
	WHERE (SurveyName='AUDC' AND (display_I9<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1))
		OR (Category='I9' AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1))
		OR (SurveyName='C-SSRS' AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_I9<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1))
		OR (SurveyName='COWS' AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_CSSRS<>-1 OR display_I9<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1))
		OR (SurveyName = 'CIWA-AR-' AND (display_AUDC<>-1 OR display_I9<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1))
		OR (SurveyName IN ('PHQ-2','PHQ-2+I9') AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ9<>-1 OR display_PTSD<>-1)) --Allow I9
		OR (SurveyName='PHQ9' AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ2<>-1 OR display_PTSD<>-1 OR display_PHQ2<>-1)) --allow I9
		OR (SurveyName IN ('PC-PTSD-5','PC-PTSD-5+I9') AND (display_AUDC<>-1 OR display_CIWA<>-1 OR display_COWS<>-1 OR display_CSSRS<>-1 OR display_PHQ2<>-1 OR display_PHQ9<>-1)) --allow I9
	
	/****************************************************************/
	/*	Step 6:	Add Mental Health Survey data from health factors */
	/*		I9s and CSSRS unable to respond can be documented via health factors */
	/****************************************************************/
	--Step 6a: Get SID values for health factors
	DROP TABLE IF EXISTS #HealthFactorSIDS
	SELECT 
		 mvi.MVIPersonSID
		,h.PatientSID
		,h.Sta3n
		,v.LocationSID
		,h.HealthFactorSID
		,h.HealthFactorDateTime
		,h.HealthFactorTypeSID
	INTO #HealthFactorSIDS
	FROM [HF].[HealthFactor] h WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #svys AS lm 
		ON h.HealthFactorTypeSID = lm.ItemID
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	WHERE lm.Category = 'Standalone I9' --includes health factors from standalone I9 screen plus CSSRS unable to respond
		AND lm.Domain='HealthFactorType' 
		AND h.HealthFactorDateTime BETWEEN @BeginDate AND @EndDate

	--Step 6b: Identify result values and insert into final temp table
	INSERT INTO #AddScoring
	SELECT 
		 h.MVIPersonSID
		,b.PatientICN
		,h.PatientSID AS PatientPersonSID
		,h.Sta3n
		,ISNULL(l.ChecklistID,h.Sta3n) AS ChecklistID
		,h.LocationSID
		,LocationSIDType='LocationSID'
		,h.HealthFactorSID AS SurveyAdministrationSID
		,h.HealthFactorDateTime
		,CASE WHEN lm.List LIKE 'I9%' OR h.HealthFactorDateTime<='2019-11-01' THEN 'Standalone I9'
			WHEN lm.List = 'CSSRS_SIUnableToAnswer_HF' AND h.HealthFactorDateTime>'2019-11-01' THEN 'C-SSRS'
			END AS SurveyName
		,CASE WHEN lm.List LIKE 'I9%' OR h.HealthFactorDateTime<='2019-11-01' THEN 'I9'
			WHEN lm.List = 'CSSRS_SIUnableToAnswer_HF' AND h.HealthFactorDateTime>'2019-11-01' THEN 'CSSRS'
			END AS Category
		,'Health Factor' AS DataSource
		,RawScore=CASE WHEN List='I9_SINotAtAll_HF' THEN 0
			WHEN List='I9_SISeveralDays_HF' THEN 1
			WHEN List='I9_SIMoreThanHalfTheDays_HF' THEN 2
			WHEN List='I9_SINearlyEveryDay_HF' THEN 3
			ELSE -99 END
		,CASE WHEN lm.List IN ('I9_SIMoreThanHalfTheDays_HF','I9_SINearlyEveryDay_HF','I9_SISeveralDays_HF') THEN 1
			WHEN lm.List='I9_SINotAtAll_HF' THEN 0
			WHEN  lm.List = 'CSSRS_SIUnableToAnswer_HF' AND h.HealthFactorDateTime<='2019-11-01' THEN -99 --99 is Missing, Unknown, or Skipped
			ELSE -1 END AS display_I9
		,CASE WHEN lm.List = 'CSSRS_SIUnableToAnswer_HF' AND h.HealthFactorDateTime>'2019-11-01' THEN -99 --99 is Missing, Unknown, or Skipped
			ELSE -1 END AS display_CSSRS
		,display_AUDC =-1
		,display_COWS =-1
		,display_CIWA =-1
		,display_PHQ2 =-1
		,display_PHQ9 =-1
		,display_PTSD =-1
	FROM #HealthFactorSIDS h
	INNER JOIN #svys lm 
		ON h.HealthFactorTypeSID = lm.ItemID
	INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK) 
		ON h.MVIPersonSID = b.MVIPersonSID
	INNER JOIN #Location l 
		ON h.LocationSID = l.LocationSID
	;

	/****************************************************************/
	/*	Step 7:	GET DATA FROM CERNER*/
	/****************************************************************/
	--Step 7a: Get SID values and details for Cerner PowerForms
	DROP TABLE IF EXISTS #PowerFormDetails 
	SELECT 
		 pf.MVIPersonSID
		,pf.PersonSID
		,pf.DCPFormsReferenceSID
  		,pf.DocFormActivitySID
		,pf.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID
		,pf.TZFormUTCDateTime AS FormDateTime
		,pf.DocFormDescription AS SurveyName 
		,pf.STAPA
		,s.Category
		,s.List
		,s.PrintName
		,pf.DerivedDtaEvent as DTAEvent
		,pf.DerivedDtaEventResult as DTAEventResult
		,pf.EncounterSID
		,DataSource='PowerForm'
	INTO #PowerFormDetails
	FROM [Cerner].[FactPowerForm] pf WITH (NOLOCK) 
	INNER JOIN #svys s 
		ON s.ItemID = pf.DerivedDtaEventCodeValueSID 
		AND s.AttributeValue=pf.DerivedDtaEventResult
	WHERE s.Attribute='DTA'
	AND pf.TZFormUTCDateTime BETWEEN @BeginDate AND @EndDate

	UNION ALL

	SELECT 
		 pf.MVIPersonSID
		,pf.PersonSID
		,pf.DCPFormsReferenceSID
  		,pf.DocFormActivitySID
		,pf.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID 
		,pf.TZFormUTCDateTime AS FormDateTime
		,pf.DocFormDescription AS SurveyName 
		,pf.STAPA
		,s.Category
		,s.List
		,s.PrintName
		,pf.DerivedDtaEvent as DTAEvent
		,pf.DerivedDtaEventResult as DTAEventResult
		,pf.EncounterSID
		,DataSource='PowerForm'
	FROM [Cerner].[FactPowerForm] pf WITH (NOLOCK) 
	INNER JOIN #svys s 
		ON s.ItemID = pf.DerivedDtaEventCodeValueSID 
	WHERE s.Attribute = 'FreeText'
	AND pf.TZFormUTCDateTime BETWEEN @BeginDate AND @EndDate

	--Step 7b: Get SID values and details for Cerner PowerForms
	DROP TABLE IF EXISTS #BHLDetails 
	SELECT 
		 pf.MVIPersonSID
		,pf.PersonSID
		,pf.EventSID
  		,pf.ParentEventSID
		,pf.EventCodeValueSID
		,pf.TZClinicalSignificantModifiedDateTime AS FormDateTime
		,s.Category AS SurveyName 
		,pf.STAPA
		,s.Category
		,s.List
		,s.PrintName
		,pf.Event
		,pf.ResultValue
		,pf.EncounterSID
		,DataSource='BHL'
	INTO #BHLDetails
	FROM [Cerner].[FactBHL] pf WITH (NOLOCK) 
	INNER JOIN #svys s 
		ON s.ItemID = pf.EventCodeValueSID 
		AND s.AttributeValue=pf.ResultValue
	WHERE s.Attribute='ResultValue'
	AND pf.TZClinicalSignificantModifiedDateTime BETWEEN @BeginDate AND @EndDate

	UNION ALL

	SELECT 
		 pf.MVIPersonSID
		,pf.PersonSID
		,pf.EventSID
  		,pf.ParentEventSID
		,pf.EventCodeValueSID
		,pf.TZClinicalSignificantModifiedDateTime AS FormDateTime
		,s.Category AS SurveyName 
		,pf.STAPA
		,s.Category
		,s.List
		,s.PrintName
		,pf.Event
		,pf.ResultValue
		,pf.EncounterSID
		,DataSource='BHL'
	FROM [Cerner].[FactBHL] pf WITH (NOLOCK) 
	INNER JOIN #svys s 
		ON s.ItemID = pf.EventCodeValueSID 
	WHERE s.Attribute = 'FreeText'
	AND pf.TZClinicalSignificantModifiedDateTime BETWEEN @BeginDate AND @EndDate

	--Step 7c: Union PowerForm and BHL data
	DROP TABLE IF EXISTS #CernerDetailsTogether
	SELECT * 
	INTO #CernerDetailsTogether
	FROM #PowerFormDetails
	UNION ALL
	SELECT * FROM #BHLDetails
	
	--Step 7d: Identify result values and insert into final temp table
	INSERT INTO #AddScoring 
	SELECT 
		 d.MVIPersonSID
		,mp.PatientICN
		,d.PersonSID AS PatientPersonSID
		,200 AS Sta3n
		,d.StaPA AS ChecklistID
		,CASE WHEN o.LocationNurseUnitCodeValueSID<1 THEN o.LocationCodeValueSID
			ELSE o.LocationNurseUnitCodeValueSID END AS LocationSID
		,CASE WHEN o.LocationNurseUnitCodeValueSID<1 THEN 'LocationCodeValueSID'
			ELSE 'LocationNurseUnitCodeValueSID' END AS LocationSIDType
		,d.DocFormActivitySID
		,d.FormDateTime
		,d.SurveyName
		,d.Category
		,d.DataSource
		,RawScore=CASE WHEN List IN ('AUDC_Score','CIWA_Score','COWS_Score','CSSRS_Score','PHQ2_Score','PHQ9_Score','PTSD_Score') 
				THEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int)
			WHEN d.List='I9_SINotAtAll_HF' THEN 0
			WHEN d.List='I9_SISeveralDays_HF' THEN 1
			WHEN d.List='I9_SIMoreThanHalfTheDays_HF' THEN 2
			WHEN d.List='I9_SINearlyEveryDay_HF' THEN 3
			ELSE -99 END
		,CASE WHEN d.List IN ('I9_SIMoreThanHalfTheDays_HF','I9_SINearlyEveryDay_HF','I9_SISeveralDays_HF') THEN 1
			WHEN d.List='I9_SINotAtAll_HF' THEN 0
			ELSE -1 END AS display_I9
		,CASE WHEN d.List in ('CSSRS_Q3Yes_HF','CSSRS_Q4Yes_HF','CSSRS_Q5Yes_HF','CSSRS_Q8Yes_HF') THEN 1
			WHEN d.Category = 'CSSRS' THEN 0
			ELSE -1 END AS display_CSSRS
		,CASE WHEN d.List = 'AUDC_Score' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) > 7 THEN 3
			WHEN d.List = 'AUDC_Score' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) in (5,6,7) THEN 2
			WHEN d.List = 'AUDC_Score' AND mp.Gender = 'M' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) = 4 THEN 1
			WHEN d.List = 'AUDC_Score' AND mp.Gender = 'F' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) in  (3,4) THEN 1
			WHEN d.List = 'AUDC_Score' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) < 4 THEN 0
			ELSE -1 END AS display_AUDC
		,display_COWS =CASE WHEN d.List='COWS_Score' THEN 1 ELSE -1 END
		,display_CIWA =CASE WHEN d.List='CIWA_Score' THEN 1 ELSE -1 END
		,display_PHQ2 =CASE WHEN d.List<>'PHQ2_Score' THEN -1
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) <3 THEN 0
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int)>=3 THEN 1 END
		,display_PHQ9 =CASE WHEN d.List <> 'PHQ9_Score'  THEN -1 
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) < 5 THEN 0
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) <10 THEN 1
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) < 15 THEN 2
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) < 20 THEN 3 
			WHEN TRY_CAST(LEFT(d.DTAEventResult,2) AS int) >= 20 THEN 4 END
		,display_PTSD =CASE WHEN d.List <> 'PTSD_Score' THEN -1
			WHEN d.List='PTSD_Score' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) < 4 THEN 0
			WHEN d.List='PTSD_Score' AND TRY_CAST(LEFT(d.DTAEventResult,2) AS int) >= 4 THEN 1 END
	FROM #CernerDetailsTogether d
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) 
		ON d.MVIPersonSID = mp.MVIPersonSID
	LEFT JOIN [Cerner].[EncMillEncounter] o WITH (NOLOCK)
		ON d.EncounterSID = o.EncounterSID 
		
	DROP TABLE IF EXISTS #HealthFactorSIDS
	DROP TABLE IF EXISTS #PowerFormDetails
	DROP TABLE IF EXISTS #BHLDetails
	DROP TABLE IF EXISTS #CernerDetailsTogether

	/**************************************************/
	----Step 8: Pull Final Table -----
	/**************************************************/
	DROP TABLE IF EXISTS #Stage_MHA
	SELECT DISTINCT  MVIPersonSID
				,PatientICN
				,PatientPersonSID
				,Sta3n
				,ChecklistID
				,LocationSID
				,LocationSIDType
				,SurveyAdministrationSID
				,CASE WHEN DataSource='MHA' THEN 'SurveyAdministrationSID'
					WHEN DataSource='Health Factor' THEN 'HealthFactorSID'
					WHEN DataSource='PowerForm' THEN 'DocFormActivitySID'
					WHEN DataSource='BHL' THEN 'ParentEventSID'
					END AS SurveySIDType
				,SurveyGivenDatetime	
				,SurveyName	
				,SurveyCategory = Category
				,RawScore
				,display_I9
				,display_CSSRS
				,display_AUDC
				,display_PHQ2
				,display_PHQ9
				,display_COWS
				,display_CIWA
				,display_PTSD
	INTO #Stage_MHA
	FROM #AddScoring

	DROP TABLE IF EXISTS #AddScoring

	DROP TABLE IF EXISTS #Standard_MHA;
	SELECT 
		MVIPersonSID
		,PatientICN
		,PatientPersonSID
		,Sta3n
		,ChecklistID
		,LocationSID
		,LocationSIDType
		,SurveyAdministrationSID
		,SurveySIDType
		,SurveyGivenDateTime
		,SurveyName
		,RawScore
		,display_I9
		,display_CSSRS
		,display_AUDC
		,display_PHQ2
		,display_PHQ9
		,display_COWS
		,display_CIWA
		,display_PTSD
		,DisplayScore = 
			CASE WHEN display_I9=0 OR display_CSSRS=0 OR display_AUDC=0 OR display_PHQ2=0 OR display_PHQ9=0 OR display_COWS=0 OR display_CIWA=0 OR display_PTSD=0 THEN 'Negative' 
				WHEN display_I9=1 OR display_CSSRS=1 OR display_PHQ2=1 OR display_COWS=1 OR display_CIWA=1 OR display_PTSD=1 THEN 'Positive'
				WHEN display_AUDC=1 OR display_PHQ9=1 THEN 'Positive-Mild'
				WHEN display_AUDC=2 OR display_PHQ9=2 THEN 'Positive-Moderate'
				WHEN display_PHQ9=3 THEN 'Positive-Moderately Severe'
				WHEN display_AUDC=3 OR display_PHQ9=4 THEN 'Positive-Severe'
				WHEN display_I9=-99 OR display_CSSRS=-99 OR display_AUDC=-99 OR display_PHQ2=-99 OR display_PHQ9=-99 OR display_COWS=-99 OR display_CIWA=-99 OR display_PTSD=-99 THEN 'Skipped'
				END
	INTO #Standard_MHA
	FROM 
		(
			SELECT
				 MVIPersonSID
				,PatientICN
				,PatientPersonSID
				,Sta3n
				,ChecklistID
				,LocationSID
				,LocationSIDType
				,SurveyAdministrationSID
				,SurveySIDType
				,SurveyGivenDatetime	--It is important to keep the MINUTES of the surveydatetime because some items must be completed within a 24-hour time frame
				,SurveyName				--It is important to include the survey name because the I9 question can come from 2 surveys, and it may matter to the clinician which survey it is
				,MAX(RawScore) OVER (PARTITION BY SurveyAdministrationSID, SurveyCategory,LocationSID) AS RawScore
				,display_I9				--0 (no including not asked due to other responses), 1 (yes), -99 (unknown, missing, skipped), -1 (not applicable - the row refers to the other survey)
				,display_CSSRS			--0 (no including not asked due to other responses), 1 (yes), -99 (unknown, missing, skipped), -1 (not applicable - the row refers to the other survey)
				,display_AUDC			--0 (neg: score below 4 for men, below 3 for women), 1 (mild: 4 for men, 3-4 for women), 2 (moderate: 5-7), 3 (severe: 8+), -1 (not applicable - other survey)
				,display_PHQ2			--0 (negative), 1 (positive)
				,display_PHQ9
				,display_COWS
				,display_CIWA
				,display_PTSD
				,RN_AUDC = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_AUDC DESC)
				,RN_I9 =   ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_I9 DESC)
				,RN_CS =   ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_CSSRS DESC) --occasionally multiple records have the same datetime value but different LocationSIDs and we need to capture them all	
				,RN_COWS = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_COWS DESC)
				,RN_CIWA = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_CIWA DESC)
				,RN_PHQ2 = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_PHQ2 DESC) 
				,RN_PHQ9 = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_PHQ9 DESC)
				,RN_PTSD = ROW_NUMBER() OVER(PARTITION BY SurveyAdministrationSID,SurveyCategory,LocationSID ORDER BY display_PTSD DESC)
			FROM #Stage_MHA
		) x
	WHERE 
		(
			(RN_I9 = 1 AND display_I9 <> -1) 
			OR (RN_CS = 1 AND display_CSSRS <> -1)
			OR (RN_AUDC = 1 AND display_AUDC <> -1)
			OR (RN_COWS = 1 AND display_COWS <> -1)
			OR (RN_CIWA = 1 AND display_CIWA <> -1)			
			OR (RN_PHQ2 = 1 AND display_PHQ2 <> -1)
			OR (RN_PHQ9 = 1 AND display_PHQ9 <> -1)
			OR (RN_PTSD = 1 AND display_PTSD <> -1)
		)
	; 

	DROP TABLE IF EXISTS #Stage_MHA

	--DECLARE @InitialBuild TINYINT = 0, @BeginDate DATE = DATEADD(MONTH,-3,CAST(GETDATE() AS DATE)),  @PastFiveYears DATE = DATEADD(DAY,-730,CAST(GETDATE() AS DATE))
	IF @InitialBuild = 2
	BEGIN
		EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.MentalHealthAssistant_v02', '#Standard_MHA'
	END
	ELSE
	BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DELETE [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (TABLOCK)
			WHERE SurveyGivenDateTime >= @BeginDate OR SurveyGivenDateTime < @PastFiveYears
			INSERT INTO [OMHSP_Standard].[MentalHealthAssistant_v02] WITH (TABLOCK) (
				MVIPersonSID,PatientICN,PatientPersonSID,Sta3n,ChecklistID,LocationSID,LocationSIDType,SurveyAdministrationSID
				,SurveySIDType,SurveyGivenDatetime,SurveyName,RawScore,display_i9,display_CSSRS,display_AUDC
				,display_PHQ2,display_PHQ9,display_COWS,display_CIWA,display_PTSD,DisplayScore
				)
			SELECT 
				MVIPersonSID,PatientICN,PatientPersonSID,Sta3n,ChecklistID,LocationSID,LocationSIDType,SurveyAdministrationSID
				,SurveySIDType,SurveyGivenDatetime,SurveyName,RawScore,display_i9,display_CSSRS,display_AUDC
				,display_PHQ2,display_PHQ9,display_COWS,display_CIWA,display_PTSD,DisplayScore
			FROM #Standard_MHA
	
			DECLARE @AppendRowCount2 INT = (SELECT COUNT(*) FROM #Standard_MHA)
			EXEC [Log].[PublishTable] 'OMHSP_Standard','MentalHealthAssistant_v02','#Standard_MHA','Append',@AppendRowCount2
		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		ROLLBACK TRANSACTION
		PRINT 'Error publishing to MentalHealthAssistant_v02; transaction rolled back';
			DECLARE @ErrorMsg2 VARCHAR(1000) = ERROR_MESSAGE()
		EXEC [Log].[ExecutionEnd] 'Error' -- Log end of SP
		;THROW 	
	END CATCH
		
	END
	
	
	DROP TABLE IF EXISTS #Standard_MHA

	EXEC [Log].[ExecutionEnd]
  
END