CREATE TABLE [COMPACT].[ORB_Copay_Review] (
    [MVIPersonSID]                                 INT           NOT NULL,
    [EventDateTime]                                DATETIME2 (7) NULL,
    [LocalDrugNameWithDose]                        VARCHAR (100) NULL,
    [RxNumber]                                     VARCHAR (50)  NULL,
    [PrescribingProvider]                          VARCHAR (100) NULL,
    [Sta6a]                                        VARCHAR (50)  NULL,
    [CPTCode]                                      VARCHAR (50)  NULL,
    [ICD10Code]                                    VARCHAR (50)  NULL,
    [VisitSID]                                     BIGINT        NULL,
    [COMPACTActEligibilityRXCopayExemptionEndDate] DATE          NULL,
    [ARBillNumber]                                 VARCHAR (50)  NULL,
    [IBActionSID]                                  BIGINT        NULL,
    [COMPACTCategory]                              VARCHAR (50)  NULL,
    [COMPACTAction]                                VARCHAR (50)  NULL,
    [PATS_R_Status]                                VARCHAR (50)  NULL
);

