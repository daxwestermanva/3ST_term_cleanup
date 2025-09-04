CREATE TABLE [Present].[GroupAssignments] (
    [MVIPersonSID] INT           NULL,
    [PatientICN]   VARCHAR (50)  NULL,
    [GroupType]    VARCHAR (25)  NULL,
    [GroupID]      INT           NULL,
    [ProviderSID]  INT           NOT NULL,
    [ProviderName] VARCHAR (100) NOT NULL,
    [ChecklistID]  NVARCHAR (30) NULL,
    [Sta3n]        SMALLINT      NULL,
    [VISN]         INT           NULL
);


















GO



GO



GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_GroupAssignments]
    ON [Present].[GroupAssignments];

