# Notes

# Tables Involved

Present.NLP_Variables - Does this get pushed to Cristal?
Config.NLP_3ST_subclass_labels - Which Server/Database is this?
Dim.TIUStandardTitle - Which Server/Database is this?
Dim.TIUDocumentDefinition - Which Server/Database is this?
Config.NLP_3ST_TIUStandardTitle - Which Server/Database is this?
PDW.HDAP_NLP_OMHSP - Main Table
Common.vwMVIPersonSIDPatientPersonSID 
Common.MasterPatient - Which Server/Database is this?


```sql
USE [OMHSP_PERC_PDW1]
GO

/****** Object:  Table [App].[HDAP_NLP_OMHSP_001]    Script Date: 8/21/2025 11:01:54 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [App].[HDAP_NLP_OMHSP_001](
	[Label] [varchar](150) NULL,
	[SnippetID] [varchar](150) NULL,
	[Term] [varchar](150) NULL,
	[PatientSID] [bigint] NULL,
	[Sta3n] [int] NULL,
	[ReferenceDateTime] [datetime] NULL,
	[TIUdocumentSID] [bigint] NULL,
	[NoteAndSnipOffset] [varchar](200) NULL,
	[TargetClass] [varchar](150) NULL,
	[TIUstandardTitle] [varchar](150) NULL,
	[Snippet] [varchar](8000) NULL,
	[VisitSID] [varchar](150) NULL,
	[TargetSubClass] [varchar](150) NULL,
	[TermID] [varchar](150) NULL,
	[OpCode] [varchar](2) NULL,
	[FileDate] [date] NULL
) ON [DefFG]
GO
```

Two levels of filtering: term level and HDAP_NLP_OMHSP level.

- [ ] **Priority** - Need ability to track whether or not a term should be included for reporting.
- [ ] **May be needed** - Need ability to track whether or not an entry in HDAP_NLP_OMHSP should be included for reporting, based on associated TermID

Questions:

- [ ] What has been done?  Which areas?  Retrospective or prospective?
- [ ] What are the priorities for the terms?
- [ ] This approach requires an audit table; is it appropriate to place in same location as HDAP_NLP_OMHSP?  Or, should it go in OMHSP_PERC_NLP?


