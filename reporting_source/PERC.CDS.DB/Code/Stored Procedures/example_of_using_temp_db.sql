drop table #hdap_nlp_omhsp

select top 100000 nlp.*, subclass.INSTANCE_ID, ISNUMERIC(nlp.TargetSubClass) as TargetSubClass_is_numeric
INTO #hdap_nlp_omhsp
from [OMHSP_PERC_PDW].[App].[HDAP_NLP_OMHSP] nlp with (nolock)
	left join [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping] subclass with (nolock)
		on nlp.TargetSubClass = cast(subclass.INSTANCE_ID as varchar)
where nlp.ReferenceDateTime >= dateadd(DAY, -30, CURRENT_TIMESTAMP) 
		and nlp.[Label] = 'POSITIVE'
		

create nonclustered index idx_target_class__INSTANCE_ID on #hdap_nlp_omhsp(TargetClass, INSTANCE_ID)
create nonclustered index idx_target_class__TargetSubClass on #hdap_nlp_omhsp(TargetClass, TargetSubClass)


select count(1)
from #hdap_nlp_omhsp nlp
where	
	(nlp.TargetClass IN ('PPAIN','CAPACITY') AND nlp.INSTANCE_ID IS NOT NULL)
	OR (nlp.TargetClass IN ('XYLA') AND (nlp.TargetSubClass='SUS' OR nlp.TargetSubClass='SUS-P'))
	OR nlp.TargetClass IN (
		'LIVESALONE'
		,'LONELINESS'
		,'DETOX'
		,'IDU'
		,'CAPACITY'
		,'JOBINSTABLE'
		,'JUSTICE'
		,'SLEEP'
		,'FOODINSECURE'
		,'DEBT'
		,'HOUSING'
	)