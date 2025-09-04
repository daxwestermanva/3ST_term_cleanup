CREATE TABLE [LookUp].[SpatialData] (
    [STA6]                 FLOAT (53)        NULL,
    [STA6aid]              NVARCHAR (255)    NULL,
    [Station Name]         NVARCHAR (255)    NULL,
    [LOCATION OF FACILITY] NVARCHAR (255)    NULL,
    [CITY]                 NVARCHAR (255)    NULL,
    [STATE]                NVARCHAR (255)    NULL,
    [LAT (Zip)]            FLOAT (53)        NULL,
    [LON (Zip)]            FLOAT (53)        NULL,
    [SpatialData]          [sys].[geography] NULL,
    [Checklistid]          NVARCHAR (50)     NULL
)
WITH (DATA_COMPRESSION = PAGE);


GO
