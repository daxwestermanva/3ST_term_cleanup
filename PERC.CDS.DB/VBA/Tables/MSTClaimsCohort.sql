CREATE TABLE [VBA].[MSTClaimsCohort] (
    [MVIPersonSID]      INT           NOT NULL,
    [StaPa_PCP]         NVARCHAR (30) NULL,
    [StaPa_MHTC]        NVARCHAR (30) NULL,
    [StaPa_Homestation] NVARCHAR (30) NULL,
    [Unassigned]        INT           NOT NULL,
    [EventsCount]       INT           NULL,
    [FirstEventDate]    DATE          NULL,
    [LatestEventDate]   DATE          NULL,
    [DropOffDate]       DATE          NULL,
    [Stapa_Note]        NVARCHAR (30) NULL,
    [NoteCount]         INT           NULL,
    [FirstNoteDate]     DATE          NULL,
    [LatestNoteDate]    DATE          NULL,
    [NoteNeededDate]    DATE          NULL
);




GO
