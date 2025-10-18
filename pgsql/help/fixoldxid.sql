SELECT 'vacuum(freeze,analyze,DISABLE_PAGE_SKIPPING) '||c.oid::regclass||';' 
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','m')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND c.relfrozenxid::text::bigint < :minxid
ORDER BY age(c.relfrozenxid) DESC;
