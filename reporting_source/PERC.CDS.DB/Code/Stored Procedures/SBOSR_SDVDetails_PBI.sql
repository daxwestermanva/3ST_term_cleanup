
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Main dataset for Suicide Behavior and Overdose Summary Report (PowerBI). This program is 
--				essentially the combination (UNION) of 2 separate datasets: one based on date of report 
--				and another based on date of event. Following the main dataset UNION, additional 
--				information (in relation to the suicidal/overdose behaviors) is added to create the 
--				final dataset. This is necessary for the PowerBI slicers, which will be used/synced on 
--				every page. 
--
--				Row duplication is expected in this dataset.
--				
-- Modifications:
-- 06-08-2023 CW  Limit to EventType='Suicide Event' OR Overdose=1 in #ReportDate and #EventDate; Remove
--				  duplication from #HRF; Add EventType to #UnpvtReportDate and #UnpvtEventDate.
-- 07-26-2023 CW  Reformatting SDVClassification. Updating BHAP/Fit-C rules.
-- 09-19-2023 CW  Reformatting REACH Vet and PRF slicers
-- 02-12-2025 CW  Updating main data source for this dataset to [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported].
--				  This will allow for duplicate entries to display for the same event at different ChecklistIDs,
--				  which will help with cross-facility coordination. Also adding EventCountIndicator to be used for the 
--				  distinct count of events vs SDVCtnKey.
-- 07-15-2025 CW  Adding datasource to the dataset; to use in Power BI report (Patient Level Information page)
-- =======================================================================================================
CREATE PROCEDURE [Code].[SBOSR_SDVDetails_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	-----------------------------------------------------------------------------
	--Create dataset driven by date note was entered into CPRS (ReportDate)
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ReportDate 
	SELECT 
		 MVIPersonSID
		,SPANPatientID
		,PatientICN
		,ActivePatient
		,PatientKey
		,PatientNameLastFour
		,ChecklistID
		,ADMPARENT_FCDM
		,Facility
		,[Date]
		,DataSource
		,CASE WHEN R_EventDateT IS NULL THEN LEFT(OrigEventDate,12) ELSE R_EventDateT END AS EventDateCombined
		,CASE WHEN EventDate IS NULL THEN 1 ELSE 0 END AS EventDateNULL
		,EventDate
		,R_EventDateT
		,ReportDate
		,R_ReportDateT
		,CASE WHEN SDVClassification IS NULL THEN Event_Type ELSE SDVClassification END AS SDVClassification
		,VAProperty
		,SevenDaysDx
		,ISNULL(MethodType1,'None Reported') as MethodType1		--['None Reported' needed to keep NULL values in dataset; will 
		,MethodType2											--change back to NULL value in #Final temp table below]
		,MethodType3
		,ISNULL(Method1,'None Reported') as Method1				--['None Reported' needed to keep NULL values in dataset; will 
		,Method2												--change back to NULL in #Final temp table below]
		,Method3
		,Outcome
		,Overdose
		,Fatal
		,PreparatoryBehavior
		,UndeterminedSDV
		,SuicidalSDV
		,Event_Type
		,EventCountIndicator
	INTO #ReportDate
	FROM (
			SELECT 
				 MVIPersonSID
				,SPANPatientID
				,PatientICN
				,ActivePatient
				,CONCAT(ISNULL(MVIPersonSID,999),SPANPatientID) as PatientKey	--[PatientKey used as means to join to other supplemental
				,CONCAT(PatientName, ' (',LastFour,')') PatientNameLastFour		--datasets. Not every patient in report has an
				,ChecklistID													--MVIPersonSID.]
				,ADMPARENT_FCDM													
				,Facility
				,[Date]
				,DataSource
				,EventDate
				,OrigEventDate
				,ReportDate
				,R_EventDateT
				,R_ReportDateT
				,SDVClassification
				,VAProperty
				,SevenDaysDx
				,MethodType1
			 	,MethodType2
				,MethodType3
				,CASE WHEN Method1 IS NULL OR Method1 = MethodType1 THEN MethodType1
			 		  ELSE MethodType1 + ' - ' + Method1 END AS Method1
				,CASE WHEN Method2 IS NULL OR Method2 = MethodType2 THEN MethodType2
					  ELSE MethodType2 + ' - ' + Method2 END AS Method2
				,CASE WHEN Method3 IS NULL OR Method3 = MethodType3 THEN MethodType3
					  ELSE MethodType3 + ' - ' + Method3 END AS Method3
				,Outcome
				,Overdose
				,Fatal
				,PreparatoryBehavior
				,UndeterminedSDV
				,SuicidalSDV
				,Event_Type
				,EventCountIndicator
			FROM (
					SELECT DISTINCT
						 rept.MVIPersonSID
						,rept.SPANPatientID
						,mp.PatientICN
						,CASE WHEN mp.DateOfDeath_Combined IS NULL THEN 1 ELSE 0 END AS ActivePatient
						,CASE 
							WHEN rept.MVIPersonSID IS NOT NULL THEN mp.PatientName 
							WHEN sp.LastName IS NOT NULL THEN CONCAT(sp.LastName, ', ',sp.FirstName)
							ELSE CONCAT('SPAN Patient ID: ',CAST(rept.SPANPatientID as varchar))
							END as PatientName
						,ISNULL(mp.LastFour,RIGHT(TRY_CAST(sp.SSN as int),4)) AS LastFour
						,cl.ChecklistID
						,cl.ADMPARENT_FCDM
						,cl.Facility
						,cast(rept.EntryDateTime as Date) [Date]
						,rept.DataSource
						,rept.EventDateFormatted as EventDate
						,rept.EventDate as OrigEventDate
						,rept.EntryDateTime as ReportDate
						,CAST(FORMAT(rept.EventDateFormatted,'M/d/yyyy') as varchar) as R_EventDateT
						,CAST(FORMAT(rept.EntryDateTime,'M/d/yyyy') as varchar) as R_ReportDateT
						,rept.SDVClassification							
						,rept.VAProperty
						,rept.SevenDaysDx
						,rept.MethodType1  
						,CASE WHEN rept.Method1='Other' AND rept.MethodComments1 IS NOT NULL THEN LEFT(rept.MethodComments1,55) 
							  ELSE rept.Method1 END AS Method1
						,rept.MethodType2
						,CASE WHEN rept.Method2='Other' AND rept.MethodComments2 IS NOT NULL THEN LEFT(rept.MethodComments2,55)	
							  ELSE rept.Method2 END AS Method2
						,rept.MethodType3
						,CASE WHEN rept.Method3='Other' AND rept.MethodComments3 IS NOT NULL THEN LEFT(rept.MethodComments3,55)	
							  ELSE rept.Method3 END AS Method3
						,rept.MethodComments1
						,rept.MethodComments2
						,rept.MethodComments3
						,CASE WHEN rept.Outcome2 IS NOT NULL AND rept.Outcome2<>rept.Outcome1 THEN CONCAT(rept.Outcome1, ', ', rept.Outcome2) 
							  ELSE rept.Outcome1 END AS Outcome
						,rept.Overdose
						,rept.Fatal
						,rept.PreparatoryBehavior
						,rept.UndeterminedSDV
						,rept.SuicidalSDV
						,rept.EventType as Event_Type
						,rept.EventCountIndicator
					FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] rept WITH(NOLOCK)
					LEFT JOIN Common.MasterPatient mp WITH (NOLOCK)	--[Left join to maintain SPANPatientID where 
						ON rept.MVIPersonSID=mp.MVIPersonSID			--there may not be an MVIPerson.]
					LEFT JOIN [PDW].[SpanExport_tbl_Patient] sp WITH (NOLOCK)
						ON rept.SPANPatientID=sp.PatientID
					LEFT JOIN LookUp.ChecklistID cl WITH (NOLOCK)
						ON rept.ChecklistID=cl.ChecklistID
					WHERE (rept.Overdose=1 OR
						   rept.EventType='Suicide Event') AND
						  (rept.EntryDateTime < GETDATE() OR rept.EventDateFormatted IS NULL) AND
						  (mp.TestPatient=0 OR mp.TestPatient IS NULL)
				 ) Src
		 )Src2;

	--Unpivot data for Method based on Report Date
	DROP TABLE IF EXISTS #UnpvtReportDate 
	SELECT *
	INTO #UnpvtReportDate
	FROM (SELECT 
			 MVIPersonSID
			,SPANPatientID
			,ActivePatient
			,PatientICN
			,PatientKey
			,PatientNameLastFour
			,ChecklistID
			,ADMPARENT_FCDM
			,Facility
			,[Date]
			,DataSource
			,EventDate
			,ReportDate
			,EventDateCombined
			,EventDateNULL
			,R_EventDateT
			,R_ReportDateT
			,SDVClassification
			,VAProperty
			,SevenDaysDx
			,Method1
			,Method2
			,Method3
			,MethodType1 = MethodType1
			,MethodType2 = MethodType2
			,MethodType3 = MethodType3
			,Outcome
			,Overdose
			,Fatal
			,PreparatoryBehavior
			,UndeterminedSDV
			,SuicidalSDV	
			,Event_Type 
			,EventCountIndicator
		FROM #ReportDate) p 
	UNPIVOT
			(Method FOR MethodNumber IN 
				(MethodType1 
				,MethodType2
				,MethodType3)
			) Src;

	--Event type based on ReportDate
	DROP TABLE IF EXISTS #EventType_R
	SELECT *
		,EventType='All Overdose Events'
	INTO #EventType_R
	FROM #UnpvtReportDate
	WHERE Overdose=1 
	UNION
	SELECT *
		,EventType='All Suicide Events'
	FROM #UnpvtReportDate
	WHERE Event_Type='Suicide Event';

	-----------------------------------------------------------------------------
	--Create dataset driven by date of event (EventDate)
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #EventDate 
	SELECT 
		 MVIPersonSID
		,SPANPatientID
		,PatientICN
		,ActivePatient
		,PatientKey
		,PatientNameLastFour
		,ChecklistID
		,ADMPARENT_FCDM
		,Facility
		,ISNULL([Date],ReportDate) as [Date] --[If EventDate IS NULL, default to ReportDate]
		,DataSource
		,CASE WHEN E_EventDateT IS NULL THEN LEFT(OrigEventDate,12) ELSE E_EventDateT END AS EventDateCombined
		,CASE WHEN EventDate IS NULL THEN 1 ELSE 0 END AS EventDateNULL
		,EventDate
		,E_EventDateT
		,ReportDate
		,E_ReportDateT
		,CASE WHEN SDVClassification IS NULL THEN Event_Type ELSE SDVClassification END AS SDVClassification
		,VAProperty
		,SevenDaysDx
		,ISNULL(MethodType1,'None Reported') as MethodType1		--['None Reported' needed to keep NULL values in dataset; will 
		,MethodType2											--change back to NULL value in #Final temp table below]
		,MethodType3
		,ISNULL(Method1,'None Reported') as Method1				--['None Reported' needed to keep NULL values in dataset; will 
		,Method2												--change back to NULL value in #Final temp table below]
		,Method3
		,Outcome
		,Overdose
		,Fatal
		,PreparatoryBehavior
		,UndeterminedSDV
		,SuicidalSDV
		,Event_Type
		,EventCountIndicator
	INTO #EventDate
	FROM (SELECT 
				 MVIPersonSID
				,SPANPatientID
				,PatientICN
				,ActivePatient
				,CONCAT(ISNULL(MVIPersonSID,999),SPANPatientID) as PatientKey
				,CONCAT(PatientName, ' (',LastFour,')') PatientNameLastFour
				,ChecklistID
				,ADMPARENT_FCDM
				,Facility
				,[Date]
				,DataSource
				,EventDate
				,OrigEventDate
				,ReportDate
				,E_EventDateT
				,E_ReportDateT
				,SDVClassification
				,VAProperty
				,SevenDaysDx
				,MethodType1
			 	,MethodType2
				,MethodType3
				,CASE WHEN Method1 IS NULL OR Method1 = MethodType1 THEN MethodType1
			 		  ELSE MethodType1 + ' - ' + Method1 END AS Method1
				,CASE WHEN Method2 IS NULL OR Method2 = MethodType2 THEN MethodType2
					  ELSE MethodType2 + ' - ' + Method2 END AS Method2
				,CASE WHEN Method3 IS NULL OR Method3 = MethodType3 THEN MethodType3
					  ELSE MethodType3 + ' - ' + Method3 END AS Method3
				,Overdose
				,Outcome
				,Fatal
				,PreparatoryBehavior
				,UndeterminedSDV
				,SuicidalSDV
				,Event_Type
				,EventCountIndicator
			FROM (SELECT DISTINCT
						 evnt.MVIPersonSID
						,evnt.SPANPatientID
						,mp.PatientICN
						,CASE WHEN mp.DateOfDeath_Combined IS NULL THEN 1 ELSE 0 END AS ActivePatient
						,CASE 
							WHEN evnt.MVIPersonSID IS NOT NULL THEN mp.PatientName
							WHEN sp.LastName IS NOT NULL THEN CONCAT(sp.LastName, ', ',sp.FirstName)
							ELSE CONCAT('SPAN Patient ID: ',CAST(evnt.SPANPatientID as varchar))
							END as PatientName
						,ISNULL(mp.LastFour,RIGHT(TRY_CAST(sp.SSN as int),4)) AS LastFour
						,cl.ChecklistID
						,cl.ADMPARENT_FCDM
						,cl.Facility
						,cast(evnt.EventDateFormatted as Date) [Date]
						,evnt.DataSource
						,evnt.EventDateFormatted as EventDate
						,evnt.EventDate as OrigEventDate
						,evnt.EntryDateTime as ReportDate
						,CAST(FORMAT(evnt.EventDateFormatted,'M/d/yyyy') as varchar) as E_EventDateT
						,CAST(FORMAT(evnt.EntryDateTime,'M/d/yyyy') as varchar) as E_ReportDateT
						,evnt.SDVClassification
						,evnt.VAProperty
						,evnt.SevenDaysDx
						,evnt.MethodType1  
						,CASE WHEN evnt.Method1='Other' AND evnt.MethodComments1 IS NOT NULL THEN LEFT(evnt.MethodComments1,55) 
							  ELSE evnt.Method1 END AS Method1
						,evnt.MethodType2
						,CASE WHEN evnt.Method2='Other' AND evnt.MethodComments2 IS NOT NULL THEN LEFT(evnt.MethodComments2,55)	
							  ELSE evnt.Method2 END AS Method2
						,evnt.MethodType3
						,CASE WHEN evnt.Method3='Other' AND evnt.MethodComments3 IS NOT NULL THEN LEFT(evnt.MethodComments3,55)	
							  ELSE evnt.Method3 END AS Method3
						,evnt.MethodComments1
						,evnt.MethodComments2
						,evnt.MethodComments3
						,CASE WHEN evnt.Outcome2 IS NOT NULL AND evnt.Outcome2<>evnt.Outcome1 THEN CONCAT(evnt.Outcome1, ', ', evnt.Outcome2) 
							  ELSE evnt.Outcome1 END AS Outcome
						,evnt.Overdose
						,evnt.Fatal
						,evnt.PreparatoryBehavior
						,evnt.UndeterminedSDV
						,evnt.SuicidalSDV
						,evnt.EventType as Event_Type
						,evnt.EventCountIndicator
					FROM [OMHSP_Standard].[vwSuicideOverdoseEvent_FacilityReported] evnt WITH(NOLOCK)
					LEFT JOIN Common.MasterPatient mp WITH (NOLOCK)	--[Left join to maintain SPANPatientID where 
						ON evnt.MVIPersonSID=mp.MVIPersonSID			--there may not be an MVIPerson.]
					LEFT JOIN LookUp.ChecklistID cl WITH(NOLOCK)
						ON evnt.ChecklistID=cl.ChecklistID
					LEFT JOIN [PDW].[SpanExport_tbl_Patient] sp WITH (NOLOCK)
						ON evnt.SPANPatientID = sp.PatientID
					WHERE (evnt.Overdose=1 OR
						   evnt.EventType='Suicide Event') AND
						  (evnt.EntryDateTime < GETDATE() OR evnt.EventDateFormatted IS NULL) AND
						  (mp.TestPatient=0 OR mp.TestPatient IS NULL)
				 ) Src 
		 ) Src2;

	--Unpivot data for Method based on Event Date
	DROP TABLE IF EXISTS #UnpvtEventDate 
	SELECT *
	INTO #UnpvtEventDate
	FROM (SELECT 
			 MVIPersonSID
			,SPANPatientID
			,PatientICN
			,ActivePatient
			,PatientKey
			,PatientNameLastFour
			,ChecklistID
			,ADMPARENT_FCDM
			,Facility
			,[Date]
			,DataSource
			,EventDate
			,ReportDate
			,EventDateCombined
			,EventDateNULL
			,E_EventDateT
			,E_ReportDateT
			,SDVClassification
			,VAProperty
			,SevenDaysDx
			,Method1
			,Method2
			,Method3
			,MethodType1 = MethodType1
			,MethodType2 = MethodType2
			,MethodType3 = MethodType3
			,Outcome
			,Overdose
			,Fatal
			,PreparatoryBehavior
			,UndeterminedSDV
			,SuicidalSDV	
			,Event_Type
			,EventCountIndicator
		FROM #EventDate) p 
	UNPIVOT
		(Method FOR MethodNumber IN 
			(MethodType1 
			,MethodType2
			,MethodType3)				
		) Src;

	--Event type based on EventDate
	DROP TABLE IF EXISTS #EventType_E
	SELECT *
		,EventType='All Overdose Events'
	INTO #EventType_E
	FROM #UnpvtEventDate
	WHERE Overdose=1 
	UNION
	SELECT *
		,EventType='All Suicide Events'
	FROM #UnpvtEventDate
	WHERE Event_Type='Suicide Event';

	-----------------------------------------------------------------------------
   	--Combine for dataset driven by EventDate and dataset driven by ReportDate
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Combine
	SELECT 
		 MVIPersonSID
		,PatientICN
		,SPANPatientID
		,ActivePatient
		,PatientKey
		,PatientNameLastFour
		,ChecklistID
		,ADMPARENT_FCDM
		,Facility
		,EventType
		,EventCountIndicator
		,[Date]
		,DataSource
		,EventDate
		,EventDateCombined
		,EventDateNULL
		,ReportDate
		,R_EventDateT
		,R_ReportDateT
		,E_EventDateT=NULL
		,E_ReportDateT=NULL
		,SDVClassification
		,VAProperty
		,SevenDaysDx
		,CONCAT('[',PatientKey,Date,SDVClassification,']') SDVCtnKey --[Historically used for non-distinct event counts in dashboard]
		,Method														 --[Using as MethodForVisuals below]
		,MethodNumber
		,Method1													 --[Using in logic below for MethodPrintName]
		,Method2													 --[Using in logic below for MethodPrintName]
		,Method3													 --[Using in logic below for MethodPrintName]
		,Outcome
		,Overdose
		,Fatal
		,PreparatoryBehavior
		,UndeterminedSDV
		,SuicidalSDV
	INTO #Combine
	FROM #EventType_R
	UNION 
	SELECT 
		 MVIPersonSID
		,PatientICN
		,SPANPatientID
		,ActivePatient
		,PatientKey
		,PatientNameLastFour
		,ChecklistID
		,ADMPARENT_FCDM
		,Facility
		,EventType
		,EventCountIndicator
		,[Date]
		,DataSource
		,EventDate
		,EventDateCombined
		,EventDateNULL
		,ReportDate
		,NULL
		,NULL
		,E_EventDateT
		,E_ReportDateT
		,SDVClassification
		,VAProperty
		,SevenDaysDx
		,CONCAT('[',PatientKey,Date,SDVClassification,']') SDVCtnKey --[Historically used for non-distinct event counts in dashboard]
		,Method														 --[Using as MethodForVisuals below]
		,MethodNumber
		,Method1													 --[Using in logic below for MethodPrintName]
		,Method2													 --[Using in logic below for MethodPrintName]
		,Method3													 --[Using in logic below for MethodPrintName]
		,Outcome
		,Overdose
		,Fatal
		,PreparatoryBehavior
		,UndeterminedSDV
		,SuicidalSDV
	FROM #EventType_E;

	--Reformat SDVClassification for final SBOSR cohort before moving to next step(s) to help with slicer visibility
	DROP TABLE IF EXISTS #SBOSR
	SELECT MVIPersonSID
		,PatientICN
		,SPANPatientID
		,ActivePatient
		,PatientKey
		,PatientNameLastFour
		,ChecklistID
		,ADMPARENT_FCDM
		,Facility
		,EventType
		,EventCountIndicator
		,[Date]
		,DataSource
		,EventDate
		,EventDateCombined
		,EventDateNULL
		,ReportDate
		,R_EventDateT
		,R_ReportDateT
		,E_EventDateT
		,E_ReportDateT
		,CASE
			WHEN SDVClassification='Accidental Overdose' AND Fatal=1 
				THEN 'Accidental Overdose, Fatal'
			WHEN SDVClassification='Accidental Overdose' AND Fatal=0
				THEN 'Accidental Overdose, Non-Fatal'
			WHEN SDVClassification='Severe Adverse Drug Event' AND Fatal=1
				THEN 'Severe Adverse Drug Event, Fatal'
			WHEN SDVClassification='Severe Adverse Drug Event' AND Fatal=0
				THEN 'Severe Adverse Drug Event, Non-Fatal'
			WHEN SDVClassification='Insufficient evidence to suggest self-directed violence' 
				THEN 'Insufficient evidence to suggest SDV'
			WHEN SDVClassification='Non-Suicidal Self Directed Violence, With Injury, Interrupted by Self or Other' 
				THEN 'Non-Suicidal SDV, With Injury, Interrupted by Self or Other'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence Ideation'
				THEN 'Non-Suicidal SDV Ideation'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence, Fatal'
				THEN 'Non-Suicidal SDV, Fatal'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence, Preparatory'
				THEN 'Non-Suicidal SDV, Preparatory'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence, With Injury'
				THEN 'Non-Suicidal SDV, With Injury'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence, Without Injury'
				THEN 'Non-Suicidal SDV, Without Injury'
			WHEN SDVClassification='Non-Suicidal Self-Directed Violence, Without Injury, Interrupted by Self or Other'
				THEN 'Non-Suicidal SDV, Without Injury, Interrupted by Self or Other'
			WHEN SDVClassification='Suicidal Ideation, With Suicidal Intent'
				THEN 'Suicidal Ideation, With Suicidal Intent'
			WHEN SDVClassification='Suicidal Ideation, With Undetermined Suicidal Intent'
				THEN 'Suicidal Ideation, With Undetermined Suicidal Intent'
			WHEN SDVClassification='Suicidal Ideation, Without Suicidal Intent'
				THEN 'Suicidal Ideation, Without Suicidal Intent'
			WHEN SDVClassification='Suicidal Self-Directed Violence, Preparatory'		
				THEN 'Suicidal SDV, Preparatory'
			WHEN SDVClassification='Suicide'
				THEN 'Suicide'
			WHEN SDVClassification='Suicide Attempt, With Injury'
				THEN 'Suicide Attempt, With Injury'
			WHEN SDVClassification='Suicide Attempt, With Injury, Interrupted by Self or Other'
				THEN 'Suicide Attempt, With Injury, Interrupted by Self or Other'
			WHEN SDVClassification='Suicide Attempt, Without Injury'
				THEN 'Suicide Attempt, Without Injury'
			WHEN SDVClassification='Suicide Attempt, Without Injury, Interrupted by Self or Other'
				THEN 'Suicide Attempt, Without Injury, Interrupted by Self or Other'
			WHEN SDVClassification='Undetermined Self-Directed Violence'
				THEN 'Undetermined SDV'
			WHEN SDVClassification='Undetermined Self-Directed Violence, Fatal'
				THEN 'Undetermined SDV, Fatal'
			WHEN SDVClassification='Undetermined Self-Directed Violence, Preparatory'
				THEN 'Undetermined SDV, Preparatory'
			WHEN SDVClassification='Undetermined Self-Directed Violence, With Injury'
				THEN 'Undetermined SDV, With Injury'
			WHEN SDVClassification='Undetermined Self-Directed Violence, With Injury, Interrupted by Self or Other'
				THEN 'Undetermined SDV, With Injury, Interrupted by Self or Other'
			WHEN SDVClassification='Undetermined Self-Directed Violence, Without Injury'
				THEN 'Undetermined SDV, Without Injury'
			WHEN SDVClassification='Undetermined Self-Directed Violence, Without Injury, Interrupted by Self or Other'
				THEN 'Undetermined SDV, Without Injury, Interrupted by Self or Other'
				END AS SDVClassification
		,VAProperty
		,SevenDaysDx
		,SDVCtnKey 
		,Method														
		,MethodNumber
		,Method1													
		,Method2													
		,Method3													
		,Outcome
		,Overdose
		,Fatal
		,PreparatoryBehavior
		,UndeterminedSDV
		,SuicidalSDV
	INTO #SBOSR
	FROM #Combine c;

	-----------------------------------------------------------------------------
	--Contacts in relation to suicide behavior
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ContactTracking 
	SELECT
 		 PatientKey
		,MVIPersonSID
		,VisitDate
		,EventDate
		,ReportDate
		,[Date]
		,DataSource
		,SDVCtnKey
		,Outpatient_Seen_Gap as DayGap
		,CASE WHEN Outpatient_Seen_Gap >= 0 AND Outpatient_Seen_Gap <= 7 THEN 1
		 ELSE 0 END AS Seen7Days		
		,CASE WHEN Outpatient_Seen_Gap > 7 AND Outpatient_Seen_Gap <= 30 THEN 1
		 ELSE 0 END AS Seen30Days		
	INTO #ContactTracking
	FROM (	SELECT DISTINCT			
				 s.PatientKey
				,o.MVIPersonSID
				,CAST(o.VisitDateTime AS DATE) AS VisitDate
				,s.EventDate
				,s.ReportDate
				,s.[Date]
				,s.DataSource
				,s.SDVCtnKey
				,DATEDIFF (DAY,o.VisitDateTime,ISNULL(s.EventDate,s.Date)) AS Outpatient_Seen_Gap 
			FROM #SBOSR s
			INNER JOIN [App].[vwCDW_Outpat_Workload] o WITH(NOLOCK)		--[VistA Outpatient]
				ON s.MVIPersonSID=o.MVIPersonSID
				AND o.VisitDateTime BETWEEN DATEADD(DAY,-30,ISNULL(s.EventDate,s.Date)) AND ISNULL(s.EventDate,s.Date)
			UNION
			SELECT DISTINCT
				 s.PatientKey
				,c.MVIPersonSID
				,CAST(c.TZDerivedVisitDateTime AS DATE) AS VisitDate
				,s.EventDate
				,s.ReportDate
				,s.[Date]
				,s.DataSource
				,s.SDVCtnKey
				,DATEDIFF (DAY,c.TZDerivedVisitDateTime,ISNULL(s.EventDate,s.Date)) AS Outpatient_Seen_Gap
			FROM #SBOSR s
			INNER JOIN Cerner.FactUtilizationOutpatient c WITH(NOLOCK)	--[Cerner Outpatient]
				ON s.MVIPersonSID=c.MVIPersonSID
				AND c.TZDerivedVisitDateTime BETWEEN DATEADD(DAY,-30,ISNULL(s.EventDate,s.Date)) AND ISNULL(s.EventDate,s.Date)
				) Src
	UNION					--[Combine inpatient and outpatient contacts]
	SELECT
 		 PatientKey
		,MVIPersonSID
		,AdmitDate
		,EventDate
		,ReportDate
		,[Date]
		,DataSource
		,SDVCtnKey
		,Inpatient_Seen_Gap as DayGap
		,CASE WHEN Inpatient_Seen_Gap >= 0 AND Inpatient_Seen_Gap <= 7 THEN 1 
		 ELSE 0 END AS Inpatient_Seen_7_Days
		,CASE WHEN Inpatient_Seen_Gap > 7 AND Inpatient_Seen_Gap <= 30 THEN 1 
		 ELSE 0 END AS Inpatient_Seen_30_Days
	FROM (	SELECT DISTINCT
				s.PatientKey
				,i.MVIPersonSID
				,CAST(i.AdmitDateTime AS DATE) AS AdmitDate
				,s.EventDate
				,s.ReportDate
				,s.[Date]
				,s.DataSource
				,s.SDVCtnKey
				,DATEDIFF (DAY, i.AdmitDateTime, ISNULL(s.EventDate,s.Date)) AS Inpatient_Seen_Gap
			FROM #SBOSR s
			INNER JOIN Inpatient.BedSection i WITH (NOLOCK)		--[Inpatient VM Overlaid]
				ON s.MVIPersonSID=i.MVIPersonSID
				AND i.AdmitDateTime BETWEEN DATEADD(DAY,-30,ISNULL(s.EventDate,s.Date)) AND ISNULL(s.EventDate,s.Date)
				) Src;

	--Left joining here to use inner join in final temp table; speeds up run time
	DROP TABLE IF EXISTS #SBOSRContactTracking
	SELECT DISTINCT
		 s.PatientKey
		,s.SDVCtnKey
		,s.[Date]
		,s.DataSource
		,s.EventDate
		,s.ReportDate
		,MAX(c.Seen7Days) AS Seen7Days
		,MAX(c.Seen30Days) AS Seen30Days
	INTO #SBOSRContactTracking
	FROM #SBOSR s
	LEFT JOIN #ContactTracking c
		ON s.PatientKey=c.PatientKey AND s.SDVCtnKey=c.SDVCtnKey
	GROUP BY s.PatientKey,s.SDVCtnKey, s.[Date], s.DataSource, s.EventDate, s.ReportDate;

	-----------------------------------------------------------------------------
	--Additional parameters for filtering 
	-----------------------------------------------------------------------------
	--HRF flag status
	DROP TABLE IF EXISTS #HRF
	SELECT MVIPersonSID, MIN(HRFType) HRFType
	INTO #HRF
	FROM (
		SELECT	
			 MVIPersonSID
			,CASE WHEN CAST(HRFType as varchar)='1' THEN 'Current Active PRF-Suicide'
				  WHEN CAST(HRFType as varchar)='2' THEN 'Inactivated-Past Year'
				  WHEN CAST(HRFType as varchar)='3' THEN 'Inactivated-Over Year Ago'
			 END AS HRFType
		FROM ( SELECT DISTINCT
					s.MVIPersonSID
					,CASE WHEN h.CurrentActiveFlag=1 THEN 1 --Current Active HRF Flag
							WHEN CAST(h.EpisodeEndDateTime AS DATE) >= DATEADD(DAY, -366, GETDATE()) THEN 2 --HRF Flag Inactived-Past Year
							WHEN CAST(h.EpisodeEndDateTime AS DATE) < DATEADD(DAY, 366, GETDATE()) THEN 3 --History of HRF Flag
						ELSE 0 END AS HRFType
				FROM [PRF_HRS].[EpisodeDates] h
				INNER JOIN #SBOSR s
					ON s.MVIPersonSID=h.MVIPersonSID) Src
		) Src2
	GROUP BY MVIPersonSID;

	--REACH VET status
	DROP TABLE IF EXISTS #REACH
	SELECT h.MVIPersonSID
		,CASE WHEN h.Top01Percent=1 THEN 'Top Risk Tier' 
		 ELSE 'Top Risk Tier-Past Year' END AS RV_Status
	INTO #REACH
	FROM [REACH].[History] h WITH(NOLOCK)
	INNER JOIN #SBOSR s
		on h.MVIPersonSID=s.MVIPersonSID
	WHERE h.Top01Percent = 1 OR h.MonthsIdentified12 IS NOT NULL;

	--Prescribed medications
	DROP TABLE IF EXISTS #Meds
	SELECT DISTINCT 
		a.MVIPersonSID
		,CASE 
			WHEN a.DrugNameWithoutDose LIKE '%BUPRENORPHINE%' THEN 'Buprenorphine'
			WHEN a.OpioidForPain_rx	= 1 OR a.OpioidAgonist_Rx = 1  THEN 'Opioid'
			WHEN a.Anxiolytics_Rx = 1 OR a.Benzodiazepine_Rx = 1  THEN 'Anxiolytic or Benzodiazepine'
			WHEN a.Antidepressant_Rx = 1 THEN 'Antidepressant'
			WHEN a.Antipsychotic_Rx = 1 THEN 'Antipsychotic'
			WHEN a.MoodStabilizer_Rx = 1 THEN 'Mood Stabilizer'
			WHEN a.Stimulant_Rx = 1 THEN 'Stimulant'
		 END AS MedType
	INTO #Meds
	FROM [Present].[Medications] AS a WITH (NOLOCK) 
	INNER JOIN #SBOSR as p 
		ON a.MVIPersonSID = p.MVIPersonSID 
	WHERE Psychotropic_Rx = 1 OR
		Benzodiazepine_Rx = 1 OR
		OpioidForPain_Rx = 1 OR	
		Stimulant_Rx = 1 OR
		OpioidAgonist_Rx = 1 OR 
		a.DrugNameWithoutDose like '%BUPRENORPHINE%';

	-----------------------------------------------------------------------------
	--Combine for final dataset related to suicide behaviors
	-----------------------------------------------------------------------------
	DROP TABLE IF EXISTS #Final
	SELECT *
		,CASE WHEN RV_Status='Top Risk Tier' THEN 1
			  WHEN RV_Status='Top Risk Tier-Past Year' THEN 2
			  WHEN RV_Status='No Top Risk Tier-Past Year' THEN 3
		 END AS RV_Status_Number						--[for slicer sorting]
		,CASE WHEN HRFType='Current Active PRF-Suicide' THEN 1
			  WHEN HRFType='Inactivated-Past Year' THEN 2
			  WHEN HRFType='Inactivated-Over Year Ago' THEN 3
			  WHEN HRFType='No History of PRF-Suicide' THEN 4
		 END AS HRFNumber								--[for slicer sorting]
		,CASE WHEN MonthName='January'		THEN 1
			  WHEN MonthName='February'		THEN 2
			  WHEN MonthName='March'		THEN 3
			  WHEN MonthName='April'		THEN 4
			  WHEN MonthName='May'			THEN 5
			  WHEN MonthName='June'			THEN 6
			  WHEN MonthName='July'			THEN 7
			  WHEN MonthName='August'		THEN 8
			  WHEN MonthName='September'	THEN 9
			  WHEN MonthName='October'		THEN 10
			  WHEN MonthName='November'		THEN 11
			  WHEN MonthName='December'		THEN 12
		 END AS Month_Number							--[for slicer sorting]
		,CASE 
			WHEN SDVClassification LIKE '%Prep%' THEN 'Preparatory Behavior'	--[limit method confusion on visual for prep behaviors]
			WHEN Method1 = 'None Reported' THEN NULL							--[keep NULL method values per CSREs/SBORs to encourage 
																				--data updates]
			--[the remaining method rules are to ensure unnecessary '|' symbols are kept out of MethodPrintName]
			WHEN [Method1=Method2]=1 AND [Method1=Method3]=0 AND [Method2=Method3]=0 AND (Method2 IS NOT NULL AND Method3 IS NULL) THEN Method1
			WHEN [Method1=Method2]=1 AND [Method1=Method3]=1 AND [Method2=Method3]=1 AND (Method2 IS NOT NULL AND Method3 IS NOT NULL) THEN Method1
			WHEN [Method1=Method2]=1 AND [Method1=Method3]=0 AND [Method2=Method3]=0 AND (Method2 IS NOT NULL AND Method3 IS NOT NULL) THEN CONCAT(Method1, ' | ', Method3)
			WHEN [Method1=Method2]=1 AND [Method1=Method3]=1 AND [Method2=Method3]=1 AND (Method2 IS NOT NULL AND Method3 IS NULL) THEN Method1
			WHEN [Method1=Method2]=0 AND [Method1=Method3]=0 AND [Method2=Method3]=0 AND (Method2 IS NULL AND Method3 IS NULL) THEN Method1
			WHEN [Method1=Method2]=0 AND [Method1=Method3]=1 AND [Method2=Method3]=0 THEN CONCAT(Method1, ' | ', Method3)
			WHEN [Method1=Method2]=0 AND [Method1=Method3]=0 AND [Method2=Method3]=1 THEN CONCAT(Method1, ' | ', Method2)
			WHEN [Method1=Method2]=0 AND [Method1=Method3]=0 AND [Method2=Method3]=0 AND (Method2 IS NOT NULL AND Method3 IS NOT NULL) THEN CONCAT(Method1, ' | ', Method2, ' | ', Method3)
			WHEN [Method1=Method2]=0 AND [Method1=Method3]=0 AND [Method2=Method3]=0 AND (Method2 IS NOT NULL AND Method3 IS NULL) THEN CONCAT(Method1, ' | ', Method2)
			END AS MethodPrintName						--[method for table visual]
		,CONCAT([Month],' ',[Year]) as MonthYear
		,FORMAT([Date], 'yyyy MM') as AdmitYearMonth_Number
	INTO #Final
	FROM (	SELECT DISTINCT
				 s.MVIPersonSID
				,s.PatientICN
				,s.SPANPatientID
				,CASE WHEN S.ActivePatient=1 THEN 'Living' ELSE 'Deceased' END AS ActivePatient
				,s.PatientKey
				,s.PatientNameLastFour
				,ISNULL(s.ChecklistID,'Unknown') AS ChecklistID
				,ISNULL(s.ADMPARENT_FCDM,'Unknown') AS ADMPARENT_FCDM
				,ISNULL(s.Facility,'Unknown') AS Facility
				,CASE 
					WHEN s.E_EventDateT IS NULL AND s.E_ReportDateT IS NULL THEN 'RDate' 
					WHEN s.R_EventDateT IS NULL AND s.R_ReportDateT IS NULL THEN 'EDate' END AS SDVCntType
				,s.SDVCtnKey
				,s.EventType
				,s.EventCountIndicator
				,s.[Date]
				,s.DataSource
				,CONVERT(varchar,LEFT(DATENAME(MONTH,s.Date),3)) as [Month]		--[for bar graph visual]
				,CONVERT(varchar,DATENAME(MONTH,s.Date)) as MonthName			--[for slicer multi-select]
				,CONVERT(varchar,YEAR(s.Date)) as [Year]
				,s.EventDate
				,s.EventDateCombined							--[to highlight non-date (EventDate) answers in table visuals]
				,CASE WHEN s.EventDateNULL=1 THEN 1 ELSE 0 END AS EventDateNULL
				,s.ReportDate
				,s.E_EventDateT
				,s.E_ReportDateT
				,s.R_EventDateT
				,s.R_ReportDateT
				,s.SDVClassification
				,CASE WHEN CAST(s.EventDate as varchar) IS NULL THEN 'Unk' WHEN CAST(c.Seen7Days as varchar)='1' THEN 'Yes' ELSE 'No' END AS Seen7Days
				,CASE WHEN CAST(s.EventDate as varchar) IS NULL THEN 'Unk' WHEN CAST(c.Seen30Days as varchar)='1' THEN 'Yes' ELSE 'No' END AS Seen30Days
				,CASE WHEN s.VAProperty='Yes' THEN 'Yes' WHEN s.VAProperty='Unknown' THEN 'Unk' ELSE 'No' END AS VAProperty
				,CASE WHEN s.SevenDaysDx='Yes' THEN 'Yes'  WHEN s.SevenDaysDx='Unknown' THEN 'Unk' ELSE 'No' END AS SevenDaysDx
				,CASE WHEN s.SDVClassification LIKE '%Prep%' THEN 'Preparatory Behavior'	--[limit confusion on visual for prep behaviors]
					  WHEN s.Method1 = 'None Reported' THEN NULL							--[keep NULL method values per CSREs/SBORs to 
																							--encourage providers to update their data]
					  ELSE s.Method END AS MethodForVisuals		--[method for bar graph visual]
				,s.MethodNumber
				,CASE WHEN s.Method1=s.Method2 THEN 1 ELSE 0 END AS [Method1=Method2]		
				,CASE WHEN s.Method1=s.Method3 THEN 1 ELSE 0 END AS [Method1=Method3]		
				,CASE WHEN s.Method2=s.Method3 THEN 1 ELSE 0 END AS [Method2=Method3]		
				,s.Method1
				,s.Method2
				,s.Method3
				,s.Outcome
				,CASE WHEN s.Overdose=1 THEN 1 ELSE 0 END AS Overdose
				,CASE WHEN CAST(s.Fatal as varchar)=1 THEN 'Fatal' ELSE 'Non-Fatal' END AS FatalvNonFatal
				,CASE WHEN s.Fatal = 1 AND s.SDVClassification NOT IN ('Accidental Overdose, Fatal','Severe Adverse Drug Event, Fatal')
				THEN DATEADD (DAY, 30, s.ReportDate) ELSE NULL END AS BHAP_FITC_DueDate
				,CASE WHEN s.Fatal=1 THEN 1 ELSE 0 END AS Fatal
				,CASE WHEN s.PreparatoryBehavior=1 THEN 1 ELSE 0 END AS PreparatoryBehavior
				,CASE WHEN s.UndeterminedSDV=1 THEN 1 ELSE 0 END AS UndeterminedSDV
				,CASE WHEN s.SuicidalSDV=1 THEN 1 ELSE 0 END AS SuicidalSDV
				,CASE WHEN h.HRFType='Current Active PRF-Suicide'  THEN 'Current Active PRF-Suicide'
					  WHEN h.HRFType='Inactivated-Past Year' THEN 'Inactivated-Past Year'
					  WHEN h.HRFType='Inactivated-Over Year Ago' THEN 'Inactivated-Over Year Ago'
					  ELSE 'No History of PRF-Suicide' END AS HRFType
				,CASE WHEN m.MedType IS NULL THEN 'No Medications' ELSE m.MedType END AS MedType
				,CASE WHEN r.RV_Status = 'Top Risk Tier' THEN 'Top Risk Tier' 
					  WHEN r.RV_Status = 'Top Risk Tier-Past Year' THEN 'Top Risk Tier-Past Year'
					  ELSE 'No Top Risk Tier-Past Year' END AS RV_Status
			FROM #SBOSR s
			LEFT JOIN #HRF h ON s.MVIPersonSID=h.MVIPersonSID
			LEFT JOIN #Meds m ON s.MVIPersonSID=m.MVIPersonSID
			LEFT JOIN #REACH r ON s.MVIPersonSID=r.MVIPersonSID
			INNER JOIN #SBOSRContactTracking c ON s.PatientKey=c.PatientKey AND s.SDVCtnKey=c.SDVCtnKey
			WHERE s.Date<=GETDATE() 
			) Src;

	EXEC [Maintenance].[PublishTable] 'SBOSR.SDVDetails_PBI','#Final';

	END