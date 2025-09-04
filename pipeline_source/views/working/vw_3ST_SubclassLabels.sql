/*****************************************************************************
 * 
 * File: vw_3ST_SubclassLabels.sql  
 * 
 * Purpose: View to map 3ST subclass instance IDs to preferred labels
 * 
 * TODOs: 
 *   - [ ] Does Config.NLP_3ST_subclass_labels map to [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping]?
 *
 *****************************************************************************/
CREATE VIEW vw_3ST_SubclassLabels
AS
    SELECT Instance_ID, Class, SUBCLASS, Preferred_Label, SUBCLASS_GROUPING
    FROM [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping] WITH (NOLOCK)
    WHERE Polarity = 'indicates_presence'
        AND (Class = 'Psychological Pain'
        AND Subclass IN ('Pain exceeds tolerance','Housing issues',
                            'Sleep issues','Financial issues','Legal issues')
        OR Class = 'Capacity for Suicide');
