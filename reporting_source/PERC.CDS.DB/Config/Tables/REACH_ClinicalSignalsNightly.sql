CREATE TABLE [Config].[REACH_ClinicalSignalsNightly] (
    [InstanceVariable]     VARCHAR (255) NULL,
    [PrintName]            VARCHAR (50)  NULL,
    [DashboardCategory]    VARCHAR (50)  NULL,
    [DashboardColumn]      VARCHAR (10)  NULL,
    [DisplayWithoutHeader] TINYINT       NULL
);






GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_REACH_ClinicalSignalsNightly]
    ON [Config].[REACH_ClinicalSignalsNightly];

