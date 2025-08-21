


CREATE VIEW [App].[vwPBILSVMembership]

AS  
/* This staging view is needed to create Row Level Security in PowerBI  -- DO NOT REMOVE */
SELECT p.LCustomerID as UserSID,
		p.Sta3n,
		p.ADAccount,
		c.ChecklistID             
FROM [LCustomer].[AllPermissions] as p
inner join LookUp.checklistID as c on p.sta3n = c.sta3n
Where  PHIPII = 1 ;