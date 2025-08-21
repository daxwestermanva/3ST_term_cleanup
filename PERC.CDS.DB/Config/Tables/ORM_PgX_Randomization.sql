CREATE TABLE [Config].[ORM_PgX_Randomization] (
    [Sta3n]           VARCHAR (10)  NULL,
    [StaPA]           VARCHAR (10)  NULL,
    [InstitutionName] VARCHAR (100) NULL,
    [PHASER_status]   VARCHAR (100) NULL,
    [Randomization]   INT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_ORM_PgX_Randomization]
    ON [Config].[ORM_PgX_Randomization];

