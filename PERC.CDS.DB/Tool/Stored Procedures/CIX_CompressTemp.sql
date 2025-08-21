-- =============================================
-- Author:		David Wright
-- Create date: 9/9/2014
-- Description:	exec OMHO_DAG.dag.MyCompress '[App].[OMHO_IRA_IRA_IRAFY13Q3]', 'scrssn'
-- =============================================
CREATE PROCEDURE [Tool].[CIX_CompressTemp] 
          @database varchar(100),
		  @IndexColumn varchar(50)

AS
BEGIN
        declare @sql varchar(1000) 
		set @sql= '
		CREATE CLUSTERED INDEX my_indx 
		ON '+@database+ ' ('+@IndexColumn +' ASC)
		WITH (   SORT_IN_TEMPDB   = ON, 
				 ONLINE           = OFF, 
				 FILLFACTOR       = 100, 
				 DATA_COMPRESSION = PAGE) 
			  '
		
		exec(@sql)
END