
-- =============================================
-- Author:		Meenah Paik
-- Create date: 2023-03-22
-- Description: Quick View patient info - 1 row per patient location; Runs after Code.PDSI_PatientDetails
-- Updates: 
		-- 2024-06-04	MCP: Added most recent stimulant rx details
		-- 2025-01-06	MCP: Adding Phase 6 details
		-- 2025-01-30	MCP: Adding Inpatient and Outpatient code group types
		-- 2025-02-20	MCP: Adding last UDS (in past year) and Vitals date (in past 6 months) for STIMRX1
		-- 2025-04-21	MCP: Adding AUDIT-C scores for sorting
		-- 2025-07-10	MCP: Bug fix for outpatient and inpatient GroupID
-- =============================================
CREATE PROCEDURE [Code].[PDSI_PatientQuickView]

AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PDSI_PatientQuickView', @Description = 'Execution of Code.PDSI_PatientQuickView SP'


--Get Measures Unmet Cohort
DROP TABLE IF EXISTS #MeasuresUnmet
SELECT MVIPersonSID
	  ,max([SUD16]) AS [SUD16]
	  ,max([ALC_top1]) AS [ALC_top1]
	  ,max([GBENZO1]) AS [GBENZO1]
	  ,max([BENZO_Opioid_OP]) AS [BENZO_Opioid_OP]
	  ,max([BENZO_PTSD_OP]) AS [BENZO_PTSD_OP]
	  ,max([BENZO_SUD_OP]) AS [BENZO_SUD_OP]
	  ,max([PDMP_Benzo]) AS [PDMP_Benzo]
	  ,max([Naloxone_StimUD]) AS [Naloxone_StimUD]
	  ,max([STIMRX1]) AS [STIMRX1]
	  ,max([CoRx-RxStim]) AS [CoRx_RxStim]
	  ,max([EBP_StimUD]) AS [EBP_StimUD]
	  ,max([Off_Label_RxStim]) AS [Off_Label_RxStim]
	  ,max([CLO1]) AS [CLO1]
	  ,max([APDEM1]) AS [APDEM1]
	  ,max([APGLUC1]) AS [APGLUC1]
INTO #MeasuresUnmet
FROM (
	SELECT MVIPersonSID
		,Measure
		,MeasureUnmet
	FROM [PDSI].[PatientDetails] --select distinct measure from pdsi.patientdetails 
	WHERE MeasureUnmet>0
  ) AS a
PIVOT (count(MeasureUnmet) 
		FOR Measure IN ([SUD16],[ALC_top1],[GBENZO1],[BENZO_Opioid_OP],[BENZO_PTSD_OP],[BENZO_SUD_OP],[PDMP_Benzo],[Naloxone_StimUD],[STIMRX1],[CoRx-RxStim],[EBP_StimUD],[Off_Label_RxStim],[CLO1],[APDEM1],[APGLUC1])) AS pvt
GROUP BY MVIPersonSID

--Future Appointments (borrowed from STORM OTTR View code)
DROP TABLE IF EXISTS #appt
SELECT * INTO #appt FROM (
	SELECT MVIPersonSID
		  ,AppointmentDatetime
		  ,AppointmentID
		  ,AppointmentType
		  ,AppointmentLocation
		  ,AppointmentLocationName
		  ,AppointmentStop 
		  ,RN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,AppointmentID ORDER BY AppointmentDateTime)
	FROM [PDSI].[PatientDetails]
	WHERE AppointmentID in (1,3) AND AppointmentDatetime is not null
	) AS a
WHERE RN=1;

/*Providers Per Location*/

--PDSI Prescribers: Many pts have multiple prescribers - for quick view, we'll show the most recent
DROP TABLE IF EXISTS #RecentPresc
SELECT * INTO #RecentPresc
FROM (
SELECT d.MVIPersonSID
	,c.ChecklistID
	,d.GroupID
	,d.GroupType
	,d.ProviderName
	,d.ProviderSID
	,d.ProviderLocation -- checklistid or providerlocation needs to go - they're the same
	,RN=row_number() OVER (PARTITION BY c.MVIPersonSID,c.ChecklistID ORDER BY m.IssueDate desc)
FROM [PDSI].[PatientDetails] d
INNER JOIN [Present].[StationAssignments] c ON d.MVIPersonSID=c.MVIPersonSID AND d.ProviderLocation=c.ChecklistID
INNER JOIN [Present].[Medications] m ON d.MVIPersonSID=m.MVIPersonSID AND d.ProviderSID=PrescriberSID --need extra requirements for drug name/sid here?
WHERE ProviderSID>0 and GroupID = 1 and PDSIrelevant_Rx = 1 -- for PDSI Prescribers only
) AS a WHERE RN = 1

--Keep all outpatient and inpatient and pivot 
DROP TABLE IF EXISTS #OutInpat
SELECT DISTINCT d.MVIPersonSID
	,c.ChecklistID
	,d.GroupID
	,d.GroupType
	,d.ProviderName
	,d.ProviderSID
	,d.ProviderLocation 
INTO #OutInpat
FROM [PDSI].[PatientDetails] d
INNER JOIN [Present].[StationAssignments] c ON d.MVIPersonSID=c.MVIPersonSID AND d.ProviderLocation=c.ChecklistID
WHERE ProviderSID>0 and GroupID > 5

 --Dynamic Pivot to create a wide table to pull all outpatient and inpatient event types into 1 row
		DROP TABLE IF EXISTS ##outinpivot

		DECLARE @MaxColumns INT
		DECLARE @Columns NVARCHAR(MAX)
		DECLARE @Wide NVARCHAR(MAX)

		-- Step 2.
		SELECT @MaxColumns = MAX(Cnt)
		FROM (
  		  SELECT MVIPersonSID
    		,COUNT(*) AS 'Cnt'
  		  FROM #OutInpat WITH (NOLOCK)
  		  GROUP BY MVIPersonSID, ChecklistID, GroupID
  		  ) AS EpsOfCare

		-- Step 3.
		SET @Columns = ''
		DECLARE @i INT = 1
		WHILE @i <= @MaxColumns
		BEGIN
  		  SET @Columns = @Columns + '[Inpatsid' + CAST(@i AS VARCHAR(10)) + '],'
  		  SET @Columns = @Columns + '[Outpatsid' + CAST(@i AS VARCHAR(10)) + '],'
  		  SET @i = @i + 1
		END

		SET @Columns = LEFT(@Columns, LEN(@Columns) - 1)

		-- Step 4.
		SET @Wide = N'
  		  ;WITH NumberedEps AS (
    		SELECT MVIPersonSID
      		  ,ChecklistID
      		  ,GroupID
			  ,ProviderName
			  ,ProviderSID
      		  ,CAST(ROW_NUMBER() OVER (PARTITION BY MVIPersonSID,ChecklistID,GroupID ORDER BY ProviderSID) AS NVARCHAR(10)) AS ''RowNum''
    		FROM #OutInpat
  		  )
  		  SELECT MVIPersonSID, ChecklistID, ' + @Columns + '
	INTO ##outinpivot  		  
		FROM
  		  (
    		SELECT MVIPersonSID
      		  ,''Inpatsid'' + RowNum AS ''ColumnName''
			  ,ChecklistID
      		  ,ProviderSID AS ''Value''
    		FROM NumberedEps
			WHERE GroupID = 6
    		UNION
    		SELECT MVIPersonSID
      		  ,''Outpatsid'' + RowNum AS ''ColumnName''
			  ,ChecklistID
      		  ,ProviderSID AS ''Value''
    		FROM NumberedEps
			WHERE GroupID = 7
  		  ) AS source
  		  PIVOT
  		  (
    		MAX(Value)
    		FOR ColumnName IN (' + @Columns + ')
  		  ) AS pvt;
		'

		-- Step 5.
		EXEC sp_executesql @wide

--Other Providers Per Location
--Note: No patients have multiple BHIP,MHTC,PACT,PCP assignments per checklistID
DROP TABLE IF EXISTS #uniqueprov;
SELECT * INTO #uniqueprov	
FROM (
	SELECT d.MVIPersonSID
		,c.ChecklistID
		,d.GroupID
		,d.GroupType
		,d.ProviderName
		,d.ProviderSID
		,d.ProviderLocation 
		,RN=row_number() OVER (PARTITION BY c.MVIPersonSID,ChecklistID,GroupID,GroupType ORDER BY ProviderSID)
	FROM [PDSI].[PatientDetails] d
	INNER JOIN [Present].[StationAssignments] c ON d.MVIPersonSID=c.MVIPersonSID AND d.ProviderLocation=c.ChecklistID
	WHERE ProviderSID>0 and GroupID > 1 and GroupID < 6 -- exclude PDSI prescriber and inpat/outpat that were separated out above
) AS a WHERE RN=1

--Union all groupID providers
DROP TABLE IF EXISTS #AllProv
SELECT *
	INTO #AllProv
	FROM #uniqueprov
UNION ALL
SELECT *
	FROM #RecentPresc

DROP TABLE IF EXISTS #pivot;
SELECT MVIPersonSID
	  ,ChecklistID
	  ,max([PDSI Prescriber]) AS Prescribersid
	  ,max([PACT Team]) AS PACTsid
	  ,max([Primary Care Provider]) AS PCPsid
	  ,max([MH Tx Coordinator]) AS MHTCsid
	  ,max([BHIP TEAM]) AS BHIPsid
	  --,max([Outpatient Stop Codes]) AS Outpatsid
	  --,max([Inpatient]) AS Inpatsid
INTO #pivot
FROM #AllProv AS a
	PIVOT (max(ProviderSID) FOR GroupType in (
		[PDSI Prescriber],[PACT Team],[Primary Care Provider],[MH Tx Coordinator],[BHIP TEAM]/*,[Outpatient Stop Codes],[Inpatient]*/) 
  )AS p
 GROUP BY MVIPersonSID,ChecklistID


DROP TABLE IF EXISTS #AllTogether
SELECT CASE WHEN a.MVIPersonSID IS NULL THEN b.MVIPersonSID ELSE a.MVIPersonSID END MVIPersonSID
	  ,CASE WHEN a.ChecklistID IS NULL THEN b.ChecklistID ELSE a.ChecklistID END ChecklistID
	  ,a.Prescribersid
	  ,a.PACTsid
	  ,a.PCPsid
	  ,a.MHTCsid
	  ,a.BHIPsid
	  ,b.Inpatsid1
	  ,b.Outpatsid1
	  ,b.Inpatsid2
	  ,b.Outpatsid2
	  ,b.Inpatsid3
	  ,b.Outpatsid3
INTO #AllTogether
FROM #pivot a
FULL OUTER JOIN ##outinpivot b
	ON a.MVIPersonSID=b.MVIPersonSID AND a.ChecklistID=b.ChecklistID

--------------------------------
---------------------------------

DROP TABLE IF EXISTS #providers
SELECT DISTINCT z.*
	  ,t.ProviderName AS Prescriber
	  ,u.ProviderName AS PACT 
	  ,v.ProviderName AS PCP 
	  ,w.ProviderName AS MHTC 
	  ,x.ProviderName AS BHIP 
	  ,y.ProviderName AS Outpat
	  ,a.ProviderName AS Inpat
INTO #providers
FROM #AllTogether AS z
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #AllProv) AS t ON t.ProviderSID=Prescribersid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #AllProv) AS u ON u.ProviderSID=PACTsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #AllProv) AS v ON v.ProviderSID=PCPsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #AllProv) AS w ON w.ProviderSID=MHTCsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #AllProv) AS x ON x.ProviderSID=BHIPsid
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #outinpat WHERE GroupID = 7) AS y ON y.ProviderSID=z.Outpatsid1 OR y.ProviderSID=z.Outpatsid2 OR y.ProviderSID=z.Outpatsid3
LEFT JOIN (SELECT DISTINCT ProviderSID,ProviderName FROM #outinpat WHERE GroupID = 6) AS a ON a.ProviderSID=Inpatsid1 OR a.ProviderSID=Inpatsid2 OR a.ProviderSID=Inpatsid3
;
------------------- 
--CREATE TABLE TO CHECK FOR ASSIGNMENTS AT OTHER STATIONS IF PROVIDER IS NULL
DROP TABLE IF EXISTS #AnyProv
SELECT MVIPersonSID
	  ,max([PACT Team]) AS PACT
	  ,max([Primary Care Provider]) AS PCP
	  ,max([PDSI Prescriber]) AS Prescriber
	  ,max([MH Tx Coordinator]) AS MHTC
	  ,max([BHIP TEAM]) AS BHIP 
	  ,min([Outpatient Stop Codes]) AS Outpat
	  ,max([Inpatient]) AS Inpat
INTO #AnyProv
FROM (
	SELECT MVIPersonSID
		,GroupType
		,ProviderSID
		,ProviderName
	FROM [PDSI].[PatientDetails] 
	WHERE ProviderSID>0
  ) AS a
PIVOT (count(ProviderName) 
		FOR GroupType IN ([Primary Care Provider],[PACT Team],[BHIP TEAM],[MH Tx Coordinator],[PDSI Prescriber],[Outpatient Stop Codes],[Inpatient])) AS pvt
GROUP BY MVIPersonSID

-------------------
--Get Stimulant Rx details 
DROP TABLE IF EXISTS #StimRx1
SELECT 
	  MVIPersonSID
	 ,DrugName
	 ,PrescriberName
	 ,MedDrugStatus
	 ,MedRxStatus
	 ,MedReleaseDate
	 ,MedIssueDate
	 ,CASE WHEN MedReleaseDate is null THEN MedIssueDate ELSE MedReleaseDate END MedDate
	 INTO #StimRx1 
FROM [PDSI].[PatientDetails] a
WHERE StimulantADHD_rx = 1

DROP TABLE IF EXISTS #StimRx2
SELECT 
	  MVIPersonSID
	 ,DrugName
	 ,PrescriberName
	 ,MedDrugStatus
	 ,MedRxStatus
	 ,MedReleaseDate
	 ,MedIssueDate
	 ,MedDate
INTO #StimRx2
FROM (
	SELECT 
		  MVIPersonSID
		 ,DrugName
		 ,PrescriberName
		 ,MedDrugStatus
		 ,MedRxStatus
		 ,MedReleaseDate
		 ,MedIssueDate
		 ,MedDate
		 ,row_number() over (partition by MVIPersonSID order by MedDate desc) as rn
	FROM #StimRx1
	) as a WHERE a.rn = 1

--Get Vitals/UDS dates
DROP TABLE IF EXISTS #Monitoring
SELECT 
	  MVIPersonSID
	 ,DetailsDate as UDSDate
	 ,VitalsDate
INTO #Monitoring
FROM [PDSI].[PatientDetails] a
WHERE MeasureID = '5163' and (VitalsDate is not null or UDS = 1) and MeasureUnmet = 1

--Get AUDIT-C scores/dates
DROP TABLE IF EXISTS #AUDC
SELECT
	 MVIPersonSID
	,DetailsText as AUDCScore
	,DetailsDate as AUDCDate
INTO #AUDC
FROM [PDSI].[PatientDetails] a
WHERE MeasureID = '5119' and DetailsText is not null and MeasureUnmet = 1

--Combine for staging table
DROP TABLE IF EXISTS #PDSIQuickView;
SELECT a.MVIPersonSID
	  ,s.ChecklistID
	  ,b.Facility
	  ,[SUD16]
	  ,[ALC_top1]
	  ,[GBENZO1]
	  ,[BENZO_Opioid_OP]
	  ,[BENZO_PTSD_OP]
	  ,[BENZO_SUD_OP]
	  ,[PDMP_Benzo]
	  ,[Naloxone_StimUD]
	  ,[STIMRX1]
	  ,[CoRx_RxStim]
	  ,[EBP_StimUD]
	  ,[Off_Label_RxStim]
	  ,[CLO1]
	  ,[APDEM1]
	  ,[APGLUC1]
	  ,pc.AppointmentDatetime AS ApptDateTime_PC
	  ,CASE WHEN pc.AppointmentLocation<>s.ChecklistID THEN pc.AppointmentLocationName END AS ApptLocation_PC
	  ,pc.AppointmentStop AS ApptStop_PC
	  ,mh.AppointmentDatetime AS ApptDateTime_MH
	  ,CASE WHEN mh.AppointmentLocation<>s.ChecklistID THEN mh.AppointmentLocationName END AS ApptLocation_MH
	  ,mh.AppointmentStop AS ApptStop_MH
	  ,CASE WHEN p.PCP IS NULL AND a.PCP>0 THEN 'OTHER STATION'
		WHEN p.PCP IS NULL THEN 'UNASSIGNED' 
		ELSE LEFT(p.PCP,CHARINDEX(',',p.PCP + ',')-1)+', '+RIGHT(p.PCP,len(p.PCP)-CHARINDEX(',',p.PCP)) 
		END AS PCP
	  ,CASE WHEN p.PCPsid IS NULL THEN -1 ELSE p.PCPsid END AS PCPsid
	  ,CASE WHEN p.MHTC IS NULL AND a.MHTC>0 THEN 'OTHER STATION'
		WHEN p.MHTC IS NULL THEN 'UNASSIGNED' 
		ELSE LEFT(p.MHTC,CHARINDEX(',',p.MHTC + ',')-1)+', '+RIGHT(p.MHTC,len(p.MHTC)-CHARINDEX(',',p.MHTC)) 
		END AS MHTC
	  ,CASE WHEN p.MHTCsid IS NULL THEN -1 ELSE p.MHTCsid END AS MHTCsid
	  ,CASE WHEN p.BHIP IS NULL AND a.BHIP>0 THEN 'OTHER STATION'
		WHEN p.BHIP IS NULL THEN 'UNASSIGNED'
		ELSE p.BHIP END AS BHIP
	  ,CASE WHEN p.BHIPsid IS NULL THEN -1 ELSE p.BHIPsid END AS BHIPsid
	  ,CASE WHEN p.PACT IS NULL AND a.PACT>0 THEN 'OTHER STATION'
		WHEN p.PACT IS NULL THEN 'UNASSIGNED' 
		ELSE p.PACT END AS PACT
	  ,CASE WHEN p.PACTsid IS NULL THEN -1 ELSE p.PACTsid END AS PACTsid
	  ,CASE WHEN p.PrescriberSID IS NULL THEN -1 ELSE p.PrescriberSID END AS PrescriberSID 
	  ,CASE WHEN p.Prescriber IS NULL AND a.Prescriber>0 THEN 'OTHER STATION'
		WHEN p.Prescriber IS NULL THEN 'NONE' 
		ELSE p.Prescriber END AS Prescriber
	  ,CASE WHEN p.Outpat like 'Gen MH Outpatient' THEN 1 
	   WHEN p.Outpat like 'Primary Care' THEN 2
	   WHEN p.Outpat like 'SUD Outpatient' THEN 3 
	   ELSE -1 END AS OutpatSID
	  ,CASE WHEN p.Outpat IS NULL AND a.Outpat>0 THEN 'OTHER STATION'
	    WHEN p.Outpat IS NULL THEN 'NONE'
		ELSE p.Outpat END AS Outpat
	  ,CASE WHEN p.Inpat like 'Residential' THEN 1 
	   WHEN p.Inpat like 'Med/Surg' THEN 2
	   WHEN p.Inpat like 'CLC' THEN 3
	   WHEN p.Inpat like 'Mental Health' THEN 4
	   WHEN p.Inpat like 'Domiciliary' THEN 5
	   ELSE -1 END AS InpatSID
	  ,CASE WHEN p.Inpat IS NULL AND a.Inpat>0 THEN 'OTHER STATION'
	    WHEN p.Inpat IS NULL THEN 'NONE'
		ELSE p.Inpat END AS Inpat
	  ,st.DrugName
	  ,st.PrescriberName
	  ,st.MedDrugStatus
	  ,st.MedRxStatus
	  ,st.MedIssueDate
	  ,st.MedReleaseDate
	  ,mo.UDSDate
	  ,mo.VitalsDate
	  ,ac.AUDCScore
	  ,ac.AUDCDate
INTO #PDSIQuickView
FROM #MeasuresUnmet AS m
INNER JOIN (
	SELECT MVIPersonSID, ChecklistID, PDSI
	FROM [Present].[StationAssignments] 
	WHERE PDSI = 1 
	) AS s ON s.MVIPersonSID = m.MVIPersonSID 
INNER JOIN [LookUp].[ChecklistID] AS b ON s.ChecklistID = b.ChecklistID
LEFT JOIN #PROVIDERS AS p ON p.MVIPersonSID=m.MVIPersonSID AND p.ChecklistID=s.ChecklistID
LEFT JOIN #AnyProv AS a ON a.MVIPersonSID=m.MVIPersonSID
LEFT JOIN #appt AS pc ON pc.MVIPersonSID=m.MVIPersonSID AND pc.AppointmentID=3
LEFT JOIN #appt AS mh ON mh.MVIPersonSID=m.MVIPersonSID AND mh.AppointmentID=1
LEFT JOIN #StimRx2 AS st ON st.MVIPersonSID=m.MVIPersonSID 
LEFT JOIN #Monitoring AS mo ON mo.MVIPersonSID=m.MVIPersonSID
LEFT JOIN #AUDC AS ac ON ac.MVIPersonSID=m.MVIPersonSID

------

EXEC [Maintenance].[PublishTable] 'PDSI.PatientQuickView', '#PDSIQuickView'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END