To get the constraints on the table `claimsprocess_humana.a_claim_client_pricing_unit` in PostgreSQL, you can query the system catalogs or use the `information_schema` views.

Here are common ways to retrieve information about constraints on the table:

### Using `pg_constraint` and `pg_class` catalogs

```sql
SELECT conname AS constraint_name,
       contype AS constraint_type,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'claimsprocess_humana.a_claim_client_pricing_unit'::regclass;
```

- `contype` indicates the type of constraint:
  - `p` = primary key
  - `f` = foreign key
  - `u` = unique constraint
  - `c` = check constraint
  - `x` = exclusion constraint  

### Using `information_schema.table_constraints` and `information_schema.constraint_column_usage`

```sql
SELECT tc.constraint_name, tc.constraint_type, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name 
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'claimsprocess_humana'
  AND tc.table_name = 'a_claim_client_pricing_unit';
```

This will show the constraint names, types, and columns involved.

***

You can run either of these queries to retrieve full constraint details on your table.
