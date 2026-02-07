Created by Frank Zhou, last updated just a moment ago  7 minute read

HOLD: 
Issues: 
Part One: Use Shadow Table to Fix the Immutable Columnar Table Defect
Construct Demo Tables
Simulate Optimized CDC apply operation
Check The Report View Anytime
Part Two: Tested in HUAT with Real Data
Construct Shadow Table and Report View
Simulate CDC Apply Operation
Base Table Rebuild and Switchover
Conclusion
Appendix
Jira Tickets:
The Query for Base Datamart Table. 


HOLD: 
The solution is facing postgresql plan regression issue, the statistics change can ruin the best execution plan and make the view query stale. 

If could not stable it, have to looking for other solution. 

Issues: 
The largest datamart table we created contains more than 51 million recors, the table size is more than 510GB. 

Ad-hoc query are pretty slow for the view based on this table. Almost all of the jasper filter option does not work based on the query on low cardinality column in this table. 

To fix it, we introduced the columnar storage extension, it greatly improved the ad-hoc query performance, the same query speed got improved more than 10x times, the columnar table size got dropped down to 40GB compare with normal table 510GB. It help fixed almost all of the jasper filter consrtuction issues.

Then, the new issues come in like

The citus columnar table does not support update/delete, which block the cdc (change data capture) flow; 
The hydra columnar extension supports insert/delete on columnar table, but, the problem of hydra columnar extension are: 
The latest version of hydra extension is only for postgresql 15. hydra 15 does not support the postgresql 17 which we will upgrade to. 
After turn on existing cdc code, we found the error after apply change to hydra columnar table. The unique constraint does not work, we start to see duplicate key issue after apply cdc change. 
We have to keep going to do research on market to find the better columnar storage provider, but could not find the best. 

This paper is addressing above issue and provide new design that use citus columnar table plus shadow table to fix above issues.  

Part One: Use Shadow Table to Fix the Immutable Columnar Table Defect
Based on what we already built

Ability to construct large complicate datamart table
The absolute ability of columnar table for analytic job
The limit change data volume (2M transaction per day)
The change data is from logical subscription table, no need to run data integrity check, we just need to refresh the change to datamart table. 
We do have chance to keep changed data in shadow table and using view to mix immutable colunmar base table with shadow table to support end user ad-hoc queries. 

Here is the demo

Construct Demo Tables
We will create the base columnar table A and its normal shadow table A_shadow, and the relevant view. 



create table A(id int primary key, name varchar) using columnar;

create table A_shadow (like A including all);

alter table A_shadow add column action char(1);

create or replace view report as 
select A.* from A
where not exists ( select 1 from a_shadow where a_shadow.id=A.id)
union all
select id,name from a_shadow where action='i'
order by id;

INSERT INTO A (id, name)
SELECT generate_series, 'data_' || generate_series
FROM generate_series(1, 100);

select * from A where id>90

  id  |          name
-----+------------------------
  91 | data_91
  92 | data_91
  93 | data_93
  94 | data_94
  95 | data_95
  96 | data_96
  97 | data_97
  98 | data_98
  99 | data_99
 100 | data_100 
Simulate Optimized CDC apply operation
Instead of directly apply change to large immutable datamart table A, we apply the change to shadow table. Remember the A_shadow table also has primary key constraint, it is not like dynamic cdc history table which wrote by trigger on source table, which will keep multiple action for same PK row, in A_shadow table, any record will be unique, it will reply the final state of that record
The action field is for the desired change on base table, 'd' is for delete, 'i' is for insert, the update action required by cdc will be implement in A_shadow table as delete then insert. So, any record got changed, will be finally kept in A_shadow table with action value is either 'd' or 'i' 
At the begin, there is no record in A_shadow table, so, all of the CDC apply will use insert on conflict update statement, to make sure
create the change for certain record
keep the change to latest status. 


-- Per CDC required insert : the new value should be directly added into A_shadow table;

insert into A_shadow values(101,'pure insert','i') on conflict(id) do update set id=101,name='pure insert',action='i';

-- Per CDC required update: The update should be converted to delete first and on conflict update
-- 1. There is already insert records before, apply change flag to 'd'

insert into A_shadow values(92,'update required delete','d') on conflict(id) do update set id=92, name='update required delete',action='d';
insert into A_shadow values(92,'updated 92 new values','i') on conflict(id) do update set id=92,name='updated 92 new values',action='i';

-- 2. There is no that records, even the A table also does not contain that records, but, if not missing any cdc request, must be insert already run before. So, here, just use same logic.

insert into A_shadow values(102,'update required delete','d') on conflict(id) do update set id=102,name='update requred delete',action='d';
insert into A_shadow values(102,'updated 102 new values','i') on conflict(id) do update set id=102,name='updated 102 new values',action='i';

-- delete: Just add the delete operation using same statements.Suppose the original table should contain this record, if not, it will still keep data interg
rity because it is pure delete.

insert into A_shadow values(103,'pure delete','d') on conflict(id) do update set id=103,name='pure delete',action='d';
insert into A_shadow values(93,'pure delete','d') on conflict(id) do update set id=93,name='pure delete',action='d';


test=# select * from a_shadow;
 id  |          name          | action
-----+------------------------+--------
 101 | pure insert            | i
  92 | updated 92 new values  | i
 102 | updated 102 new values | i
 103 | pure delete            | d
  93 | pure delete            | d
(5 rows)


Check The Report View Anytime
Then, just check the report view, we can see it looks like all of the CDC change got applied to the base table correctly. 



test=# select * from report where id>90;
 id  |          name
-----+------------------------
  91 | data_91
  92 | updated 92 new values
  94 | data_94
  95 | data_95
  96 | data_96
  97 | data_97
  98 | data_98
  99 | data_99
 100 | data_100
 101 | pure insert
 102 | updated 102 new values
(11 rows)
id 93:  Got "deleted"

id 92:  Got "updated" 
....

id 101, 102: Got "inserted" and "updated" .... 

So, the solution works. 

Part Two: Tested in HUAT with Real Data
Here is the test in huat with the real data

Construct Shadow Table and Report View


set search_path to datamart_humana;

-- The claim table is columnar table with real data
ods_domani=# select count(1) from claim;
  count
----------
 51411921
(1 row)

create table claim_shadow (like claim including all);

create or replace view report as
select A.*,'' from datamart_humana.claim A
where not exists ( select 1 from datamart_humana.claim_shadow s where s.customer_id=A.customer_id and s.claim_id=A.claim_id)
union all
select * from datamart_humana.claim_shadow where action='i';

Simulate CDC Apply Operation
It is not easy to manually simulate cdc apply operation because table table has more than 1000 fields. Also, the test purpose is to confirm the performance acceptable, So, instead of one by one apply CDC change, we directly move data into claim_shadow table, to check view performance for certain critical queries



insert into claim_shadow select *,'i' from claim limit 10;

ods_domani=# select customer_id,claim_id from claim_shadow;
 customer_id |   claim_id
-------------+--------------
         319 | 187442723521
         319 | 187477782111
         319 | 187545650331
         319 | 194033525671
         319 | 194234171021
         319 | 194275176151
         319 | 194357502411
         319 | 194426388441
         319 | 194561607151
         319 | 194614296811
(10 rows)

update claim_shadow set action='d' where customer_id=319 and claim_id='194614296811';

ods_domani=# select count(1) from report where customer_id=319 and claim_id='194614296811';
 count
-------
     0
(1 row)

Time: 514.529 ms


select "report"."claim_id" as "report_claim_id",
"report"."client_id" as "report_client_id",
"customer_info"."customer_id" as "customer_info_customer_id"
from datamart_humana."report" "report"
inner join (select customr0.customer_no customer_id
, customr0.full_title customer_nm
, customr0.cust_strt_dte customer_effective_begin_dt
, customr0.customer_end_date customer_effective_end_dt
, e21.customer_set_id
, e21b.customer_set_id AS benefit_customer_set_id
from customer.customr0
inner join customer.e21
on customr0.customer_no = e21.customer_id
and customer_set_type_id = 2
left outer JOIN customer.e21 e21b
ON customr0.customer_no = e21b.customer_id
AND e21b.customer_set_type_id = 3
) "customer_info" on ("report"."customer_id" = "customer_info"."customer_id")
where (("report"."client_id" in (1)) and ("customer_info"."customer_id" in (319)))
limit 1000;

report_claim_id | report_client_id | customer_info_customer_id
-----------------+------------------+---------------------------
 266090038531    |                1 |                       319
 252302000011    |                1 |                       319
 252302000021    |                1 |                       319
 252302000031    |                1 |                       319
 266090038561    |                1 |                       319
 266090038771    |                1 |                       319
 266090038781    |                1 |                       319
 266090038791    |                1 |                       319
 266090038801    |                1 |                       319
(9 rows)

Time: 1014.192 ms (00:01.014)

ods_domani=# select postpay_ind_3 from report group by postpay_ind_3;
 postpay_ind_3
---------------


 1
 A
 B
 C
 E
 O
(8 rows)

Time: 34542.137 ms (00:34.542)

ods_domani=# update claim_shadow set postpay_ind_3='F' where customer_id=319 and claim_id='194357502411';
UPDATE 1
Time: 86.177 ms

ods_domani=# select postpay_ind_3 from report group by postpay_ind_3;
 postpay_ind_3
---------------


 1
 A
 B
 C
 E
 F
 O
(9 rows)

Time: 34531.300 ms (00:34.531)

ods_domani=# select distinct customer_id from report;
 customer_id
-------------
         320
         830
         829
         848
         544
         319
         828
(7 rows)

Time: 36275.683 ms (00:36.276)
ods_domani=# insert into claim_shadow(customer_id,claim_id,action) values(500,'999000999','i');
INSERT 0 1
Time: 85.119 ms
ods_domani=# select distinct customer_id from report;
 customer_id
-------------
         320
         830
         500
         829
         848
         544
         319
         828
(8 rows)

Time: 36226.591 ms (00:36.227)

The performance is almost same as query columnar table itself.  

Base Table Rebuild and Switchover
If the growth of shadow table greatly drop down the view report query performance, we can rebuild the base table and switchover them 

Two approaches for it

Parallel maintain existing CDC apply to normal datamart table ( The original writable table before we convert) when we turn on the columnar table and shadow table, no meaningful, suppose will not go this way
Keep running with shadow table and view solution, until we decide to rebuild, directly construct new base using data from report view. The logic like below, need to add the the detail later to prevent the data missing or override issue, etc. 


create table claim_new (like claim including all) using columnar;
create table claim_shadow_new (like claim_shadow including all);
insert into claim_new select * from report;

Then, mark the latested applied CDC record, switch over table and rebuild the report view. 

alter table claim rename to claim_old;
alter table claim_shadow rename to claim_shadow_old;
alter table claim_new rename to claim;
alter table claim_shadow_new rename to claim_shadow;

create or replace view report as
select A.*,'' from datamart_humana.claim A
where not exists ( select 1 from datamart_humana.claim_shadow s where s.customer_id=A.customer_id and s.claim_id=A.claim_id)
union all
select * from datamart_humana.claim_shadow where action='i';


Conclusion
The design can help us

Fixed the immutable columnar issue and allow keep apply CDC change to datamart table. 
Support our postgresql 17 upgrade
Greatly enhance analytic query performance
Easy for implementation and maintain
Satisfy customer before we get the more better solution. 
Appendix
Jira Tickets:
https://domanirx.atlassian.net/browse/DEVOPS-11718



The Query for Base Datamart Table. 
Very complex query which join about 50 tables from different schema, and the output is more than 1100 fields. 

https://domanirx.atlassian.net/browse/DEVOPS-7297


