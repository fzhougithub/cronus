\timing on
\set ON_ERROR_STOP on

BEGIN;
LOCK TABLE datamart_humana.claim IN ACCESS EXCLUSIVE MODE;
SELECT columnar.vacuum('datamart_humana.claim',100);
commit;
