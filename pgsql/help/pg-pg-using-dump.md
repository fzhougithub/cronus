Before upgrade to higher version, we have to facing PG-PG defect or bug that caused by FK constrains. The PG-PG replication initialization process always fail. 

This doc provide the way to build PG-PG replication using pg_dump to avoid subscription table initialization failure. 

Step 1: Check Publication and Recreate Replication Slot

You have to make sure the publication and the named replication slot is there before the operation. 

financials=# select * from pg_publication;
   oid   |        pubname        | pubowner | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot
---------+-----------------------+----------+--------------+-----------+-----------+-----------+-------------+------------
 4490617 | qc_finance_global_pub |       10 | f            | t         | t         | t         | t           | f

financials=# select pg_drop_replication_slot('qc_finance_global_sub');
 pg_drop_replication_slot
--------------------------

(1 row)

financials=# SELECT pg_create_logical_replication_slot('qc_finance_global_sub','pgoutput');
pg_create_logical_replication_slot
--------------------------------------
(qc_finance_global_sub,116/33000098)
(1 row)


financials=# select * from pg_replication_slots;
slot_name           | qc_finance_global_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16904
database            | financials
temporary           | f
active              | f
active_pid          |
xmin                |
catalog_xmin        | 121274324
restart_lsn         | 116/33000060
confirmed_flush_lsn | 116/33000098
wal_status          | reserved
safe_wal_size       | 10502537064
two_phase           | f




Create Assist Session

Using assist session to create snapshot and get the LSN number, which should be used by backup and the subscription advanced operation later

financials=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
financials=*# select pg_export_snapshot(),pg_current_wal_lsn();
 pg_export_snapshot  | pg_current_wal_lsn
---------------------+--------------------
 0000007F-00001449-1 | 116/33000000
(1 row)
Step 2: Create Replication Slot and advance it

Keep this session running until all of the maintenance completed. 

financials=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
financials=*# select pg_export_snapshot(),pg_current_wal_lsn();
 pg_export_snapshot  | pg_current_wal_lsn
---------------------+--------------------
 0000007F-0000144B-1 | 116/33000098
(1 row)
Step 3: Truncate tables, dump and load publication tables
Dump data from publication
pg_dump -h 10.222.73.109 -d financials --data-only --schema=finance_global --snapshot='00000083-00001A87-1' --format=plain -f /pg_backups/finance_global_pub.sql

psql -d ods_domani
>set search_path to finance_global;
>\i finance_global_pub.sql

Step 4: Advance Replication Slot
financials=# SELECT pg_replication_slot_advance('qc_finance_global_sub', '116/33000098');
     pg_replication_slot_advance
--------------------------------------
 (qc_finance_global_sub,116/33000098)
(1 row)
Step 5: Create Subscription 

Here, the trick is try to let the subscription use existing slot, instead of create new slot. 

ods_domani=# create subscription qc_finance_global_sub connection 'host=10.222.73.109,dbname=financials,port=5432' publication qc_finance_global_pub with (copy_data=false, slot_name = 'qc_finance_global_sub', create_slot = false);
CREATE SUBSCRIPTION
Step 6: check_count

check slot status, especially the LSN change

-[ RECORD 1 ]-------+----------------------
slot_name           | qc_finance_global_sub
plugin              | pgoutput
slot_type           | logical
datoid              | 16904
database            | financials
temporary           | f
active              | f
active_pid          |
xmin                |
catalog_xmin        | 121274324
restart_lsn         | 116/33000060
confirmed_flush_lsn | 116/33000098
wal_status          | reserved
safe_wal_size       | 10502537064
two_phase           | f

Check data count. 

                          tablename                           | pub_count | sub_count
--------------------------------------------------------------+-----------+-----------
 finance_global.journal_entry                                 |    578648 |    578648
 finance_global.payment_breakup                               |     46969 |     46969
 finance_global.payment                                       |     41558 |     41558
 finance_global.finance_file                                  |      7290 |      7290........
