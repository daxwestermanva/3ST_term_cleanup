


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	6/5/2025
-- Description:	To be used as Test Patient data for any Power BI Reports wanting to incorporate Demo Mode.
--
--
-- Modifications:
--
-- 6/26/2025 CW  Validation updates (TestPatient=1). Removing non-test patient.
-- 7/9/2025  CW  Adding TestPatient information for BHIP
-- 7/29/2025 CW  Adding additional BHIP info for BHIP consults
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_TestPatients] AS

WITH Location AS (
    SELECT 
          c.VISN
        , sc.Facility
        , sc.CheckListID
        , sc.Code
		, sta6a = ''
    FROM LookUp.ChecklistID c WITH (NOLOCK)
    INNER JOIN LookUp.StationColors sc WITH (NOLOCK) ON c.ChecklistID = sc.CheckListID
	INNER JOIN LookUp.Sta6a s6a WITH (NOLOCK) ON c.ChecklistID=s6a.ChecklistID
)
, TestPatient AS (
    SELECT 
          MVIPersonSID
        , PatientICN
		, PriorityGroup
		, PrioritySubGroup
        , FlowEligible = CASE 
            WHEN MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478) THEN 'Yes'
            ELSE 'No'
        END
        , HomelesSlicer = CASE 
            WHEN MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478) THEN 'No'
            ELSE 'Yes'
        END
        , FullPatientName = 'Patient Name (0000)'
		, PatientName = 'Patient Name'
		, LastFour = '0000'
        , MailAddress = '12345 Patient''s Mailing Address, City, State, Zip'
        , StreetAddress = '6789 Patient''s Street Address, City, State, Zip'
        , MailCityState = '(Mailing Address) City, State'
        , PhoneNumber = '(000) 000-0000'
        , Zip
		, Age
        , AgeSort = CASE
            WHEN age < 20 THEN 1
            WHEN age BETWEEN 20 AND 39 THEN 2
            WHEN age BETWEEN 40 AND 59 THEN 3
            WHEN age BETWEEN 60 AND 79 THEN 4
            WHEN age BETWEEN 80 AND 99 THEN 5
            WHEN age >= 100 THEN 6
        END
        , AgeCategory = CASE
            WHEN age < 20 THEN '<20'
            WHEN age BETWEEN 20 AND 39 THEN '20-39'
            WHEN age BETWEEN 40 AND 59 THEN '40-59'
            WHEN age BETWEEN 60 AND 79 THEN '60-79'
            WHEN age BETWEEN 80 AND 99 THEN '80-99'
            WHEN age >= 100 THEN '100+'
        END
        , BranchOfService
        , DateOfBirth = CAST('1864-08-22' AS date)
        , DisplayGender = CASE 
            WHEN DisplayGender = 'Man' THEN 'Male'
            WHEN DisplayGender = 'Woman' THEN 'Female'
            WHEN DisplayGender = 'Transgender Man' THEN 'Transgender Male'
            WHEN DisplayGender = 'Transgender Woman' THEN 'Transgender Female'
            ELSE DisplayGender
        END
        , Race
        , ServiceSeparationDate = CAST('1864-08-22' AS date)
        , DoDSeprationType = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'DoD Separation - Over Year Ago'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478,46455441,36668998) THEN 'DoD Separation - Past Year'
            ELSE 'No DoD Separation Date on File'
        END
        , PeriodOfService
        , COMPACTEligible = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678,9415243,9144260,46028037) THEN 'Not Verified as COMPACT Eligible'
            WHEN MVIPersonSID IN (49627276,13426804,16063576,42958478) THEN 'COMPACT Eligible Only'
            WHEN MVIPersonSID IN (49605020,9279280,46113976,46455441,36668998) THEN 'COMPACT Eligible'
            ELSE 'Active COMPACT Episode'
        END
        , BHIPAssessment = CASE
            WHEN MVIPersonSID IN (15258421, 9382966, 36728031, 13066049, 14920678, 9160057, 9097259, 40746866, 43587294, 42958478) THEN 'BHIP Assessment Past Year'
            ELSE 'No BHIP Assessment Past Year'
        END
    FROM Common.MasterPatient WITH (NOLOCK)
    WHERE TestPatient=1
)
, TestPatientDetails AS (
    SELECT 
          MVIPersonSID
        , Report = CASE
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Substance Use Population Mgmt'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'BHIP Care Coordination'
            WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'COMPACT Act Care Coordination'
            ELSE 'Syringe Services Program (Confirmed IDU)'
        END
        , ProviderName = 'Provider Name'
        , Team = 'Team Name'
        , TeamRole = 'Team Role'
		, TeamName = 'Team Name'
        , Clinic = 'Clinic Name/Location'
		, ActiveEpisode = 1
		, CurrentlyAdmitted='Yes'
		, FLOWEligible='Yes'
		, Homeless='Homeless Svcs or Dx'
		, BHIP_StartDate = CAST('1864-08-22' AS date)
		, LastBHIPContact = CAST('1864-08-22' AS date)
		, BHIPNoMHAppointment6mo = 0
		, BHIPRiskFactor= CASE
             WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049) THEN 'Most recent suicide attempt or overdose'
             WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Inpat MH Stay in past year'
             WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478,16063576) THEN 'MH-related ED/Urgent Care visit'
             WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'CSRE - Acute Risk'
             WHEN MVIPersonSID IN (46455441, 9415243,14920678) THEN 'High Risk Flag in past year'
             ELSE NULL END
		, BHIPEventValue=CASE
             WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049) THEN 'Suicide Attempt, With Injury, Interrupted by Self or Other, Overdose: Opioids'
             WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'HIGH INTENSITY GEN PSYCH INPAT'
             WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478,16063576) THEN 'Opioid dependence with intoxication, unspecified'
             WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'High'
             WHEN MVIPersonSID IN (46455441, 9415243,14920678) THEN 'New'
             ELSE NULL END
		, BHIPEventDate = DATEADD(day,-14,getdate())
		, BHIPActionable=1
		, BHIPActionLabel='Action Required'
		, BHIPOverdueFlag=0
		, BHIPOverdueforFill = 0
		, BHIPOverdueForLab = 0
		, BHIPOverdue_Any = 0
		, BHIPTotalMissedAppointments = 1
		, BHIPCancellationReason='Cancellation Reason'
		, BHIPCancellationReasonType='Patient'
		, BHIPCancellationRemarks='VEText Appt Cx: Clinic Name/Location appt. on 8/22/1964 14:00 was cancelled by the Patient.'
		, BHIPActionExpected='Case Review'
		, BHIPTobaccoPositiveScreen=1
		, BHIPAppointmentDate_Slicer= CASE
			WHEN MVIPersonSID IN (15258421,9382966) THEN GETDATE() + 7
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN GETDATE() + 7
			WHEN MVIPersonSID IN (42958478,46455441,16063576) THEN GETDATE() + 14
			WHEN MVIPersonSID IN (49627276,13426804) THEN GETDATE() + 14
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN GETDATE() + 21
			WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN GETDATE() + 21
			WHEN MVIPersonSID IN (13066049,14920678) THEN GETDATE() + 28
			WHEN MVIPersonSID IN (36728031,43587294) THEN GETDATE() + 28
			ELSE GETDATE() + 35 END
		, BHIPAppointmentDayFormatted= CASE
			WHEN MVIPersonSID IN (15258421,9382966) THEN CAST(FORMAT(GETDATE() + 7, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN CAST(FORMAT(GETDATE() + 7, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (42958478,46455441,16063576) THEN CAST(FORMAT(GETDATE() + 14, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (49627276,13426804) THEN CAST(FORMAT(GETDATE() + 14, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN CAST(FORMAT(GETDATE() + 21, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN CAST(FORMAT(GETDATE() + 21, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (13066049,14920678) THEN CAST(FORMAT(GETDATE() + 28, ('ddd')) as varchar)
			WHEN MVIPersonSID IN (36728031,43587294) THEN CAST(FORMAT(GETDATE() + 28, ('ddd')) as varchar)
			ELSE CAST(FORMAT(GETDATE() + 35, ('ddd')) as varchar) END
		, BHIPAcuteEventScore= CASE
			WHEN MVIPersonSID IN (15258421,9382966) THEN 3
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 3
			WHEN MVIPersonSID IN (42958478,46455441) THEN 2
			WHEN MVIPersonSID IN (49627276,13426804) THEN 4
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 5
			WHEN MVIPersonSID IN (49605020,9279280,46113976,16063576) THEN 6
			WHEN MVIPersonSID IN (13066049,14920678) THEN 2
			WHEN MVIPersonSID IN (36728031,43587294) THEN 6
			ELSE 1 END
		, BHIPChronicCareScore= CASE
			WHEN MVIPersonSID IN (15258421,9382966) THEN 3
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 3
			WHEN MVIPersonSID IN (42958478,46455441) THEN 3
			WHEN MVIPersonSID IN (49627276,13426804) THEN 3
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 2
			WHEN MVIPersonSID IN (49605020,9279280,46113976,16063576) THEN 2
			WHEN MVIPersonSID IN (13066049,14920678) THEN 2
			WHEN MVIPersonSID IN (36728031,43587294) THEN 2
			ELSE 1 END
		, BHIPToRequestServiceName= 'To Request Service Name'
		, BHIPRequestDateTime= CAST('1864-08-22' AS date) 
		, BHIPCPRSStatus='ACTIVE'
		, BHIPProvisionalDiagnosis = CASE
			WHEN MVIPersonSID IN (15258421,9382966,9415243,9144260,46028037) THEN 'Major Depressive Disorder, Recurrent, unspecified'
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 'Depressive Disorder NOS'
			WHEN MVIPersonSID IN (42958478,46455441,16063576) THEN 'Post Traumatic Stress Disorder, Chronic'
			WHEN MVIPersonSID IN (49627276,13426804) THEN 'Generalized Anxiety Disorder'
			ELSE 'Adjustment Disorder NOS' 
		END
		, BHIPConsultActivityComment = 'Consult Activity Comment'
		, BHIPActivityDateTime= CAST('1864-08-22' AS date) 
		, LastEvent = CAST('1864-08-22' AS date)
        , AppointmentDate = CAST('1864-08-22' AS date)
		, AppointmentDateTime = CAST('1864-08-22' AS datetime2)
        , AppointmentPrintName = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Primary Care Appointment'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'MH Appointment'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'Homeless Appointment'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'Specialty Pain'
            WHEN MVIPersonSID IN (46455441) THEN 'Peer Support'
            ELSE 'Emergency Room'
        END
        , AppointmentStopCodeName = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'PCMHI IND Assessment'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'MH TH Video Home'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'HCHV/HCMI INDIV'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'PAIN CLINIC'
            WHEN MVIPersonSID IN (46455441) THEN 'TELEPHONE CASE MANAGEMENT'
            ELSE 'EMERGENCY DEPT'
        END
        , AppointmentLabel = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Last VA Contact'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Last VA Contact'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'Future Appointments'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'Future Appointments'
            WHEN MVIPersonSID IN (46455441) THEN 'Future Appointments'
            ELSE 'Last VA Contact'
        END
        , AppointmentInfo = '(640) 8/22/1862 | Appt Service Name'
        , AppointmentSlicer = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'No Appointment in Next 365 days'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Next 7 days'
            WHEN MVIPersonSID IN (49627276,13426804,49605020) THEN 'Next 8-30 days'
            WHEN MVIPersonSID IN (9279280,46113976,42958478) THEN 'Next 31-90 days'
            WHEN MVIPersonSID IN (46455441,9144260) THEN 'Next 91-180 days'
            ELSE 'Next 181-365 days'
        END
        , AppointmentSort = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 1
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 2
            WHEN MVIPersonSID IN (49627276,13426804,49605020) THEN 3
            WHEN MVIPersonSID IN (9279280,46113976,42958478) THEN 4
            WHEN MVIPersonSID IN (46455441,9144260) THEN 5
            ELSE 6
        END
        , FlagDate = CAST('1864-08-22' AS date)
        , FlagType = CASE 
            WHEN MVIPersonSID IN (15258421,9382966) THEN 'Active Behavioral'
            WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 'Active Missing Patient'
            WHEN MVIPersonSID IN (42958478,46455441) THEN 'Active PRF HRS'
            WHEN MVIPersonSID IN (49627276,13426804) THEN 'Community Care Treatment'
            WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Currently Identified in REACH VET: Yes'
            WHEN MVIPersonSID IN (9415243,9144260) THEN 'Inactive Behavioral'
            WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN 'Inactive PRF HRS'
            WHEN MVIPersonSID IN (13066049,14920678,46028037) THEN 'Overdose Event'
            ELSE 'Suicide Event'
        END
        , FlagInfo = CASE 
            WHEN MVIPersonSID IN (15258421,9382966) THEN 'VA Healthcare Facility Info'
            WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 'VA Healthcare Facility Info'
            WHEN MVIPersonSID IN (42958478,46455441) THEN 'VA Healthcare Facility Info'
            WHEN MVIPersonSID IN (49627276,13426804) THEN 'Outpatient - Mental Health (F68.8)'
            WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Currently Identified in REACH VET: Yes'
            WHEN MVIPersonSID IN (9415243,9144260) THEN 'VA Healthcare Facility Info | REACH VET Provider: Name, Provider'
            WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN 'VA Healthcare Facility Info'
            WHEN MVIPersonSID IN (13066049,14920678,46028037) THEN 'Suicide Attempt, With Injury, Interrupted by Self or Other  |  Overdose: Rx Opioids'
            ELSE 'Suicide Attempt, Without Injury  |  Physical Injury: Jump in front of Auto/Train'
        END
        , FlagInfo2 = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Outpatient - Possible Overdose Event'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Inactive COMPACT Episode'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'Emergency Visit'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'Outpatient - Chronic Pain'
            WHEN MVIPersonSID IN (46455441) THEN 'Active COMPACT Episode'
            ELSE 'Outpatient - Mental Health'
        END
        , ICDCatetory = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Adverse Event'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Substance Use Disorder'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'Medical'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'Mental Health'
            WHEN MVIPersonSID IN (46455441) THEN 'Social'
            ELSE 'Chronic Respiratory Diseases'
        END
        , ICDDate = CAST('1864-08-22' AS date)
        , ICDDetails = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN '(W01.198D) Fall on same level from slipping, tripping and stumbling with subsequent striking against other object, subsequent encounter'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN '(F10.24) Alcohol dependence with alcohol-induced mood disorder'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN '(G89.4) Chronic pain syndrome'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN '(F43.12) Post-traumatic stress disorder, chronic'
            WHEN MVIPersonSID IN (46455441) THEN '(Z59.01) Sheltered homelessness'
            ELSE '(J44.9) Chronic obstructive pulmonary disease, unspecified'
        END
        , ICDPrintName = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Related to sedatives'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Alcohol Use Disorder'
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 'Chronic Pain'
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 'PTSD'
            WHEN MVIPersonSID IN (46455441) THEN 'Homeless'
            ELSE 'Chronic Respiratory Diseases'
        END
        , ICDSort = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 1
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 2
            WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478) THEN 3
            WHEN MVIPersonSID IN (9279280,46113976,9144260) THEN 4
            WHEN MVIPersonSID IN (46455441) THEN 5
            ELSE 7
        END
        , AMADischarge = 0
        , Census = CASE WHEN MVIPersonSID IN (49627276,13426804,49605020,42958478,16063576) THEN 1 ELSE 0 END
        , DischargeDate = CAST('1864-08-22' AS date)
        , AdmitDate = CAST('1864-08-22' AS date)
        , InpatientType = CASE 
            WHEN MVIPersonSID IN (49627276) THEN 'Acute MH Inpatient'
            WHEN MVIPersonSID IN (13426804) THEN 'MH Residential'
            WHEN MVIPersonSID IN (49605020) THEN 'Inpatient Medical/Surgical'
            ELSE 'Acute MH Inpatient'
        END
        , BedSectionName = 'Bed Section Name'
        , AdmitDx = '(ICD10 Code) ICD 10 Diagnosis'
        , PlaceOfDisposition = 'RETURN TO COMMUNITY-INDEPENDENT'
        , InptDates = CONCAT(CAST('1864-08-22' AS date), ' - ', CAST('1864-08-22' AS date))
        , MedType = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'Buprenorphine'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'Antipsychotic'
            WHEN MVIPersonSID IN (49627276,13426804,49605020) THEN 'Mood Stabilizer'
            WHEN MVIPersonSID IN (9279280,46113976) THEN 'Opioid'
            WHEN MVIPersonSID IN (46455441,36668998) THEN 'Antidepressant'
            WHEN MVIPersonSID IN (14920678,46028037,9415243) THEN 'Stimulant'
            ELSE 'Anxiolytic or Benzodiazepine' 
        END
        , DrugNameWithDose = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,16063576) THEN 'BUPRENORPHINE 100MG/0.5ML INJ,SA,SYRINGE,0.5ML'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294) THEN 'QUETIAPINE FUMARATE 100MG TAB'
            WHEN MVIPersonSID IN (49627276,13426804,49605020) THEN 'GABAPENTIN 300MG CAP'
            WHEN MVIPersonSID IN (9279280,46113976) THEN 'METHADONE HCL 10MG TAB'
            WHEN MVIPersonSID IN (46455441,36668998) THEN 'SERTRALINE HCL 100MG TAB'
            WHEN MVIPersonSID IN (14920678,46028037,9415243) THEN 'AMPHETAMINE/DEXTROAMPHETAMINE RESIN COMPLEX 30MG CAP,SA'
            ELSE 'CLONAZEPAM 0.5MG TAB'
        END
        , IssueDate = CAST('1864-08-22' AS date)
        , LastReleaseDate = CAST('1864-08-22' AS date)
        , RxStatus = 'Active'
        , PrescriberName = 'Prescriber Name'
        , TimelineEventType = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'MH Admission'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'Psychotherapy'
            WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Psychotropic Medications' 
            ELSE 'Suicide Event or Overdose' 
        END
        , TimelineEventCategory = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Residential'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'EBP_CBTPTSD_Template'
            WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Mood Stabilizer' 
            ELSE 'Suicide Event' 
        END
        , TimelineEventDetails = CASE 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'AL-PSYCH RESID REHAB PROG'
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'EBP_CBTPTSD_Template'
            WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'TOPIRAMATE' 
            ELSE 'Suicide Attempt, With Injury' 
        END
        , TimelineStartDate = CAST('1864-08-22' AS date)
        , TimelineEndDate = CAST('1864-08-22' AS date)
        , TimelineLabel = CASE 
            WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'MPR: 100%'
            ELSE '8/22/1864' 
        END		
        , TimelineEventSort = CASE 
            WHEN MVIPersonSID IN (49605020,9279280,46113976,46455441,36668998) THEN 1 
            WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 2
            WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 3
            ELSE 4
        END
        , ScreenCategory = CASE 
            WHEN MVIPersonSID=15258421 THEN 'AUDIT-C | Positive-Mild (Raw Score: 3)'
            WHEN MVIPersonSID=9382966  THEN 'Food Insecurity | Positive'
            WHEN MVIPersonSID=36728031 THEN 'C-SSRS | Positive (Raw Score: 11)'
            WHEN MVIPersonSID=13066049 THEN 'CIWA | Positive (Raw Score: 10)'
            WHEN MVIPersonSID=14920678 THEN 'Cocaine (Positive)'
            WHEN MVIPersonSID=9160057  THEN 'Homeless | Positive'
            WHEN MVIPersonSID=9097259  THEN 'Oxycodone (Positive)'
            WHEN MVIPersonSID=40746866 THEN 'PHQ-9 | Positive-Moderate (Raw Score: 13)'
            WHEN MVIPersonSID=43587294 THEN 'Suicide'
            WHEN MVIPersonSID=42958478 THEN 'PC-PTSD-5 | Positive (Raw Score: 21)'
            WHEN MVIPersonSID=46455441 THEN 'Suicide'
            WHEN MVIPersonSID=49627276 THEN 'COWS | Positive (Raw Score: 23)'
            WHEN MVIPersonSID=13426804 THEN 'Codeine (Positive)'
            WHEN MVIPersonSID=16063576 THEN 'C-SSRS | Positive (Raw Score: 6)'
            WHEN MVIPersonSID=9415243  THEN 'AUDIT-C | Positive-Severe (Raw Score: 25)'
            WHEN MVIPersonSID=9144260  THEN 'Amphetamine (Positive)'
            WHEN MVIPersonSID=46028037 THEN 'Depression'
            WHEN MVIPersonSID=49605020 THEN 'Cannabinoid (Positive)'
            WHEN MVIPersonSID=9279280  THEN 'CIWA | Positive (Raw Score: 21)'
            ELSE 'Fentanyl (Positive)'
        END
        , ScreenScore = 'Positive'
        , ScreenType = CASE 
            WHEN MVIPersonSID=15258421 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=9382966  THEN 'Social Drivers of Health'
            WHEN MVIPersonSID=36728031 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=13066049 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=14920678 THEN 'Positive Drug Screen'
            WHEN MVIPersonSID=9160057  THEN 'Social Drivers of Health'
            WHEN MVIPersonSID=9097259  THEN 'Positive Drug Screen'
            WHEN MVIPersonSID=40746866 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=43587294 THEN 'Potential Screening Need'
            WHEN MVIPersonSID=42958478 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=46455441 THEN 'Potential Screening Need'
            WHEN MVIPersonSID=49627276 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=13426804 THEN 'Positive Drug Screen'
            WHEN MVIPersonSID=16063576 THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=9415243  THEN 'Mental Health Screenings'
            WHEN MVIPersonSID=9144260  THEN 'Positive Drug Screen'
            WHEN MVIPersonSID=46028037 THEN 'Potential Screening Need'
            WHEN MVIPersonSID=49605020 THEN 'Positive Drug Screen'
            WHEN MVIPersonSID=9279280  THEN 'Mental Health Screenings'
            ELSE 'Positive Drug Screen'
        END
        , ScreenDate = CAST('1864-08-22' AS date)
		, EBPType= CASE 
			WHEN MVIPersonSID=15258421	THEN 'CBT-SUD'
			WHEN MVIPersonSID=9382966	THEN 'CPT'
			WHEN MVIPersonSID=36728031	THEN 'PE'
			WHEN MVIPersonSID=13066049	THEN 'EMDR'
			WHEN MVIPersonSID=14920678	THEN 'PEI'
			WHEN MVIPersonSID=9160057	THEN 'BFT'
			WHEN MVIPersonSID=9097259	THEN 'WNE'
			WHEN MVIPersonSID=40746866	THEN 'CBT-I'
			WHEN MVIPersonSID=43587294	THEN 'CBT-PTSD'
			WHEN MVIPersonSID=42958478	THEN 'CBT-D' 
			WHEN MVIPersonSID=46455441	THEN 'WET'
			WHEN MVIPersonSID=36668998	THEN 'CBT-SP'
			WHEN MVIPersonSID=49627276	THEN 'ACT'
			WHEN MVIPersonSID=13426804	THEN 'SST'
			WHEN MVIPersonSID=16063576	THEN 'IBCT'
			WHEN MVIPersonSID=9415243	THEN 'DBT'
			WHEN MVIPersonSID=9144260	THEN 'PST'
			WHEN MVIPersonSID=46028037	THEN 'IPT'
			WHEN MVIPersonSID=49605020	THEN 'CM' 				 
			WHEN MVIPersonSID=9279280	THEN 'CBT-SUD'
			ELSE 'CBT-SUD' 
		END	
		, SUDRiskFactorsType= CASE 
			WHEN MVIPersonSID IN (15258421,9382966) THEN 'Detox/Withdrawal Health Factor'
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN '> 2 Adverse Events'
			WHEN MVIPersonSID IN (42958478,46455441) THEN 'Confirmed IDU'
			WHEN MVIPersonSID IN (49627276,13426804) THEN 'Detox/Withdrawal Note Mentions'
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'CIWA'
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Hx of SUD Dx | No SUD Tx'
			WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN 'Positive Audit-C'
			WHEN MVIPersonSID IN (13066049,14920678) THEN 'IVDU Note Mentions'
			WHEN MVIPersonSID IN (36728031,43587294) THEN 'COWS'
			ELSE 'Positive Drug Screen' 
		END
		, SUDType= CASE 
			WHEN MVIPersonSID IN (15258421,9382966) THEN 'Other Psychoactive Use'
			WHEN MVIPersonSID IN (9160057,9097259,40746866) THEN 'Hallucinogen Use'
			WHEN MVIPersonSID IN (42958478,46455441) THEN 'Opioid Use'
			WHEN MVIPersonSID IN (49627276,13426804) THEN 'Amphetamine Use'
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Sedative, Hypnotic or Anxiolytic Use'
			WHEN MVIPersonSID IN (9415243,9144260,46028037) THEN 'Cocaine Use'
			WHEN MVIPersonSID IN (49605020,9279280,46113976) THEN 'Inhalant Use'
			WHEN MVIPersonSID IN (13066049,14920678) THEN 'Tobacco Use'
			WHEN MVIPersonSID IN (36728031,43587294) THEN 'Alcohol Use'
			ELSE 'Cannabis Use' 
		END		
		, SUDTypeSort=1
		, SuicideODType= CASE 
			WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Overdose - Past Year'
			WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'CSRE Acute Risk (Intermed/High) - Past Year'
			WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Current Active PRF - Suicide' 
			ELSE 'Suicide Event - Past Year' 
		END
		, SDHType= CASE 
			WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Justice Involvement - Past Year'
			WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'Food Insecurity - Positive Screen Past Year'
			WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Relationship Health and Safety - Positive Screen Past Year' 
			ELSE 'Homeless - Positive Screen Past Year' 
		END
		, LabGroup= CASE 
			WHEN MVIPersonSID=15258421	THEN 'Buprenorphine'
			WHEN MVIPersonSID=9382966	THEN 'Amphetamine'
			WHEN MVIPersonSID=36728031	THEN 'Methadone'
			WHEN MVIPersonSID=13066049	THEN 'Dihydrocodeine'
			WHEN MVIPersonSID=14920678	THEN 'Oxycodone'
			WHEN MVIPersonSID=9160057	THEN 'Tramadol'
			WHEN MVIPersonSID=9097259	THEN 'Codeine'
			WHEN MVIPersonSID=40746866	THEN 'Phencyclidine (PCP)'
			WHEN MVIPersonSID=43587294	THEN 'Cannabinoid'
			WHEN MVIPersonSID=42958478	THEN 'Barbiturate' 
			WHEN MVIPersonSID=46455441	THEN 'Hydromorphone'
			WHEN MVIPersonSID=49627276	THEN 'Fentanyl'
			WHEN MVIPersonSID=13426804	THEN 'Benzodiazepine'
			WHEN MVIPersonSID=16063576	THEN 'Heroin'
			WHEN MVIPersonSID=9415243	THEN 'Morphine'
			WHEN MVIPersonSID=9144260	THEN 'Oxymorphone'
			WHEN MVIPersonSID=46028037	THEN 'Hydrocodone'
			WHEN MVIPersonSID=49605020	THEN 'Meprobamate' 				 
			WHEN MVIPersonSID=9279280	THEN 'Cocaine'
			ELSE 'Ethanol' 
		END
		, VisitSlicer= CASE 
			WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Past 3 Months'
			WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478) THEN 'None in Past Year'
			WHEN MVIPersonSID IN (49627276,13426804,16063576,9415243,9144260,46028037) THEN 'Past 6 Months' 
			ELSE 'Past Year' 
		END
		, VisitSlicerSort=1
		, RiskTypeCount=4
		, DoDSlicer= CASE 
			WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'DoD Separation - Over Year Ago'
			WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478,46455441) THEN 'DoD Separation - Past Year'
			ELSE 'No DoD Separation Date on File' 
		END
		, SUDDxSlicer= CASE 
			WHEN MVIPersonSID IN (15258421,9382966,36728031,13066049,14920678) THEN 'Substance Use Disorder - Past 5 Years (Excluding Past Year)'
			WHEN MVIPersonSID IN (9160057,9097259,40746866,43587294,42958478,46455441) THEN 'Rule / Out Recent Substance Use'
			ELSE 'Substance Use Disorder - Past Year' 
		END
        , ReportMode = 'Demo Mode'
    FROM Common.MasterPatient  WITH (NOLOCK)
    WHERE TestPatient=1
)
SELECT DISTINCT
      tp.MVIPersonSID
    , tp.PatientICN
	, tp.PriorityGroup
	, tp.PrioritySubGroup
    , c1.CheckListID
    , c1.VISN
    , c1.Facility
    , c1.Sta6a
    , c1.Code
    , tpd.ProviderName
    , tpd.Team
    , tpd.TeamRole
	, tpd.TeamName
    , tpd.Clinic
    , tpd.ReportMode
    , tpd.Report
    , tp.FlowEligible
    , tp.HomelesSlicer
    , tp.FullPatientName
	, tp.PatientName
	, tp.LastFour
    , tp.MailAddress
    , tp.StreetAddress
    , tp.MailCityState
    , tp.PhoneNumber
    , tp.Zip
	, tp.Age
	, tp.AgeCategory
    , tp.AgeSort
    , tp.BranchOfService
    , tp.DateOfBirth
    , tp.DisplayGender
    , tp.Race
    , tp.ServiceSeparationDate
    , tp.DoDSeprationType
    , tp.PeriodOfService
    , tp.COMPACTEligible
    , tp.BHIPAssessment
	, tpd.CurrentlyAdmitted
	, tpd.Homeless
	, tpd.BHIP_StartDate
	, tpd.LastBHIPContact
	, tpd.BHIPRiskFactor
	, tpd.BHIPEventValue
	, tpd.BHIPEventDate
	, tpd.BHIPActionable
	, tpd.BHIPOverdueFlag
	, tpd.BHIPActionExpected
	, tpd.BHIPActionLabel
	, tpd.BHIPTobaccoPositiveScreen
	, tpd.BHIPAppointmentDate_Slicer
	, tpd.BHIPAcuteEventScore
	, tpd.BHIPChronicCareScore
	, tpd.BHIPAppointmentDayFormatted
	, tpd.BHIPOverdueforFill
	, tpd.BHIPNoMHAppointment6mo
	, tpd.BHIPTotalMissedAppointments
	, tpd.BHIPCancellationReason
	, tpd.BHIPCancellationReasonType
	, tpd.BHIPCancellationRemarks
	, tpd.BHIPOverdueForLab
	, tpd.BHIPToRequestServiceName
	, tpd.BHIPRequestDateTime
	, tpd.BHIPCPRSStatus
	, tpd.BHIPProvisionalDiagnosis 
	, tpd.BHIPConsultActivityComment
	, tpd.BHIPActivityDateTime
	, tpd.ActiveEpisode
	, tpd.LastEvent
    , tpd.AppointmentDate
	, tpd.AppointmentDateTime
    , tpd.AppointmentInfo
    , tpd.AppointmentSlicer
    , tpd.AppointmentSort
    , tpd.AppointmentLabel
    , tpd.AppointmentPrintName
    , tpd.AppointmentStopCodeName
    , tpd.FlagDate
    , tpd.FlagType
    , tpd.FlagInfo
    , tpd.FlagInfo2
    , tpd.AMADischarge
    , tpd.Census
    , tpd.DischargeDate
    , tpd.AdmitDate
    , tpd.InpatientType
    , tpd.BedSectionName
    , tpd.AdmitDx
    , tpd.PlaceOfDisposition
    , tpd.InptDates
    , tpd.MedType
    , tpd.DrugNameWithDose
    , tpd.IssueDate
    , tpd.LastReleaseDate
    , tpd.RxStatus
    , tpd.PrescriberName
    , tpd.TimelineEventType
    , tpd.TimelineEventCategory
    , tpd.TimelineEventDetails
    , tpd.TimelineStartDate
    , tpd.TimelineEndDate
    , tpd.TimelineLabel
    , tpd.TimelineEventSort
    , tpd.ScreenDate
    , tpd.ScreenType
    , tpd.ScreenScore
    , tpd.ScreenCategory
	, tpd.ICDCatetory
	, tpd.ICDPrintName
	, tpd.ICDDate
	, tpd.ICDDetails
	, tpd.ICDSort
	, tpd.EBPType
	, tpd.SUDRiskFactorsType
	, tpd.SUDType
	, tpd.SUDTypeSort
	, tpd.SuicideODType
	, tpd.SDHType
	, tpd.LabGroup
	, tpd.VisitSlicer
	, tpd.VisitSlicerSort
	, tpd.RiskTypeCount
	, tpd.DoDSlicer
	, tpd.SUDDxSlicer
FROM TestPatient tp
LEFT JOIN TestPatientDetails tpd ON tp.MVIPersonSID = tpd.MVIPersonSID
INNER JOIN Location c1 ON LEN(c1.ChecklistID) >= 3