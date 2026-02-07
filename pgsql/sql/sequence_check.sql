create or replace function get_table_max_id(schema_name text, table_name text, column_name text)
returns bigint as $$
declare
    max_id bigint;
begin
    execute format('select coalesce(max(%I), 0) from %I.%I', column_name, schema_name, table_name) into max_id;
    return max_id;
end;
$$ language plpgsql volatile;

create or replace function get_sequence_current_val(sequence_name text)
returns bigint as $$
declare
    seq_schema text;
    seq_name text;
    current_val bigint;
begin
    IF position('.' in sequence_name) > 0 then
        seq_schema := split_part(sequence_name, '.', 1);
        seq_name := split_part(sequence_name, '.', 2);
    else
        seq_schema := 'public'; -- Default schema
        seq_name := sequence_name;
    end IF;

    -- Quote schema and sequence separately
    execute format('select last_value from %I.%I', seq_schema, seq_name) into current_val;
    return current_val;
end;
$$ language plpgsql volatile;

select
    n.nspname as schema_name,
    c.relname as table_name,
    a.attname as column_name,
    pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname) as sequence_name,
    get_table_max_id(n.nspname, c.relname, a.attname) as max_table_id,
    get_sequence_current_val(pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname)) as current_seq_val,
    case
        -- Fix 1: Close quotes + pass sequence name to format()
        when get_table_max_id(n.nspname, c.relname, a.attname) = 0 then
            format('select setval(%L, 1, false); -- Table is empty', 
                   pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname))
        -- Fix 2: Correct format() arguments and syntax
        when get_sequence_current_val(pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname)) < get_table_max_id(n.nspname, c.relname, a.attname) then
            format('select setval(%L, %s, true); -- Sync to max ID: %s', 
                   pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname), 
                   get_table_max_id(n.nspname, c.relname, a.attname), 
                   get_table_max_id(n.nspname, c.relname, a.attname))
        when get_sequence_current_val(pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname)) > get_table_max_id(n.nspname, c.relname, a.attname) then
            format('-- Sequence is bigger than maxid, current: %s > maxid: %s',
                   get_sequence_current_val(pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname)),
                   get_table_max_id(n.nspname, c.relname, a.attname))
        else
            '-- No fix needed (sequence is aligned)'
    end as fix_statement
from pg_class c
join pg_namespace n ON c.relnamespace = n.oid
join pg_attribute a ON c.oid = a.attrelid
where
    c.relkind = 'r'
    and a.attnum > 0
    and a.attisdropped = false
    and pg_get_serial_sequence(n.nspname || '.' || c.relname, a.attname) IS NOT NULL
order by n.nspname, c.relname;

drop function if exists get_table_max_id(text, text, text);
drop function if exists get_sequence_current_val(text);
