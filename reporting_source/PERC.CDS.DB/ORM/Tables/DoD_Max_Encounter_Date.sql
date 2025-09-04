CREATE TABLE [ORM].[DoD_Max_Encounter_Date] (
    [edipi]           VARCHAR (50) NULL,
    [MaxDoDEncounter] DATE         NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DoD_Max_Encounter_Date]
    ON [ORM].[DoD_Max_Encounter_Date];

