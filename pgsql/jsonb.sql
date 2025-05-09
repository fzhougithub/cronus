CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    data JSONB
);
-- General-purpose GIN index (good for containment queries)
CREATE INDEX idx_data_jsonb ON test_data USING GIN (data);
INSERT INTO test_data (data) VALUES
  ('{"name": "Alice", "age": 30, "skills": ["SQL", "Python"]}'),
  ('{"name": "Bob", "age": 25, "skills": ["Java", "Kotlin"]}'),
  ('{"name": "Charlie", "age": 35, "active": true}');
SELECT data->'name' AS name_json FROM test_data;
explain analyze SELECT data->'name' AS name_json FROM test_data;
SELECT data->>'name' AS name_text FROM test_data;
-- Get the second skill of the first user
SELECT data#>'{skills,1}' AS second_skill FROM test_data WHERE id = 1;
SELECT data#>>'{skills,0}' AS first_skill FROM test_data WHERE id = 1;
explain analyze SELECT data#>>'{skills,0}' AS first_skill FROM test_data WHERE id = 1;
explain analyze SELECT data#>>'{skills,0}' AS first_skill FROM test_data;
explain (analyze true,buffers true) SELECT data#>>'{skills,0}' AS first_skill FROM test_data;
-- Find rows where the data contains this exact key-value
SELECT * FROM test_data WHERE data @> '{"age": 30}';
explain SELECT * FROM test_data WHERE data @> '{"age": 30}';
SELECT * FROM test_data WHERE data ? 'active';
SELECT * FROM test_data WHERE data ?| array['active', 'skills'];
explain SELECT * FROM test_data WHERE data ?| array['active', 'skills'];
SELECT * FROM test_data WHERE jsonb_exists(data, 'name');
SELECT * FROM test_data WHERE jsonb_exists_any(data, ARRAY['skills', 'active']);
SELECT * FROM test_data WHERE jsonb_exists_all(data, ARRAY['name', 'age']);
\s

alter table test_data rename to test_data1;
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    data JSONB
);
INSERT INTO test_data (data)
SELECT jsonb_build_object(
    'name', 'User' || gs,
    'age', (random() * 50 + 20)::int,
    'active', (random() > 0.5),
    'tags', to_jsonb(array[
        CASE WHEN random() > 0.5 THEN 'dev' ELSE 'sales' END,
        CASE WHEN random() > 0.7 THEN 'admin' ELSE 'user' END
    ])
)
FROM generate_series(1, 10000) AS gs;



fzhou=> -- No index on JSONB field
EXPLAIN ANALYZE
WITH filtered AS (
    SELECT * FROM test_data
    WHERE data @> '{"active": true}' -- JSONB containment
)
SELECT
    id,
    data->>'name' AS username,
    RANK() OVER (ORDER BY (data->>'age')::int DESC) AS age_rank
FROM filtered
WHERE data->>'tags' LIKE '%dev%';
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 WindowAgg  (cost=343.01..347.88 rows=178 width=48) (actual time=17.121..21.939 rows=2516 loops=1)
   ->  Sort  (cost=342.99..343.43 rows=178 width=101) (actual time=17.101..17.600 rows=2516 loops=1)
         Sort Key: (((test_data.data ->> 'age'::text))::integer) DESC
         Sort Method: quicksort  Memory: 391kB
         ->  Seq Scan on test_data  (cost=0.00..336.33 rows=178 width=101) (actual time=0.060..15.535 rows=2516 loops=1)
               Filter: ((data @> '{"active": true}'::jsonb) AND ((data ->> 'tags'::text) ~~ '%dev%'::text))
               Rows Removed by Filter: 7484
 Planning Time: 0.744 ms
 Execution Time: 22.422 ms
(9 rows)


CREATE INDEX idx_jsonb_data ON test_data USING GIN (data);

fzhou=> CREATE INDEX idx_jsonb_data ON test_data USING GIN (data);
CREATE INDEX
fzhou=>
fzhou=>
fzhou=>
fzhou=>
fzhou=> EXPLAIN ANALYZE
WITH filtered AS (
    SELECT * FROM test_data
    WHERE data @> '{"active": true}'
)
SELECT
    id,
    data->>'name' AS username,
    RANK() OVER (ORDER BY (data->>'age')::int DESC) AS age_rank
FROM filtered
WHERE data->>'tags' LIKE '%dev%';
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 WindowAgg  (cost=343.01..347.88 rows=178 width=48) (actual time=17.890..20.097 rows=2516 loops=1)
   ->  Sort  (cost=342.99..343.43 rows=178 width=101) (actual time=17.875..18.125 rows=2516 loops=1)
         Sort Key: (((test_data.data ->> 'age'::text))::integer) DESC
         Sort Method: quicksort  Memory: 391kB
         ->  Seq Scan on test_data  (cost=0.00..336.33 rows=178 width=101) (actual time=0.046..16.250 rows=2516 loops=1)
               Filter: ((data @> '{"active": true}'::jsonb) AND ((data ->> 'tags'::text) ~~ '%dev%'::text))
               Rows Removed by Filter: 7484
 Planning Time: 0.730 ms
 Execution Time: 20.335 ms
(9 rows)


📊 Key JSONB Operators/Features Used:
@> → jsonb containment

->> → extract text from JSONB

CTE for modular filtering

RANK() OVER → window function for ranking users by age


fzhou=> SELECT pg_size_pretty(pg_relation_size('idx_jsonb_data'));
 pg_size_pretty
----------------
 888 kB
(1 row)

fzhou=> update test_data set data='{"age": 53, "name": "User26", "tags": ["dev", "admin"], "active": "please carefully told the story and follow up with the real confirmation, it is so important to keep that in mind that what ever you told will be trace back" }' where id=30;

fzhou=>              select * from test_data where id=30;
 id |                                                                                                               data

----+--------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------
 30 | {"age": 53, "name": "User26", "tags": ["dev", "admin"], "active": "please carefully told the story and follow up with the real confirmation, it is so i
mportant to keep that in mind that what ever you told will be trace back"}
(1 row)

-- ⚠️ Warning: This will add 250,000 rows and grow table to ~1GB+

INSERT INTO test_data (data)
SELECT jsonb_build_object(
    'user_id', gs,
    'active', (random() > 0.5),
    'profile', jsonb_build_object(
        'name', md5(random()::text),
        'bio', repeat(md5(random()::text), 20), -- ~640 bytes
        'tags', jsonb_agg(to_jsonb(md5(random()::text)))
    ),
    'logs', jsonb_agg(
        jsonb_build_object(
            'event', md5(random()::text),
            'timestamp', now() - (random() * interval '365 days')
        )
    )
)
FROM generate_series(10001, 250000) gs;

Then, generate prett slow query

-- ⚠️ This query is intentionally slow
WITH filtered AS (
    SELECT *
    FROM test_data
    WHERE data->'profile'->>'bio' ILIKE '%abc%'  -- This will NOT use GIN index
)
SELECT
    id,
    data->>'user_id' AS user_id,
    data->'profile'->>'name' AS name,
    data->'profile'->>'bio' AS bio,
    jsonb_array_length(data->'logs') AS log_count,
    RANK() OVER (ORDER BY jsonb_array_length(data->'logs') DESC) AS log_rank
FROM filtered
WHERE jsonb_array_length(data->'logs') > 5
ORDER BY log_rank
LIMIT 100;


fzhou=> explain analyze -- ⚠️ This query is intentionally slow
WITH filtered AS (
    SELECT *
    FROM test_data
    WHERE data->'profile'->>'bio' ILIKE '%abc%'  -- This will NOT use GIN index
)
SELECT
    id,
    data->>'user_id' AS user_id,
    data->'profile'->>'name' AS name,
    data->'profile'->>'bio' AS bio,
    jsonb_array_length(data->'logs') AS log_count,
    RANK() OVER (ORDER BY jsonb_array_length(data->'logs') DESC) AS log_rank
FROM filtered
WHERE jsonb_array_length(data->'logs') > 5
ORDER BY log_rank
LIMIT 100;
                                                                           QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------
---
 Limit  (cost=40022.52..40022.77 rows=100 width=112) (actual time=1881.676..1892.567 rows=100 loops=1)
   ->  Sort  (cost=40022.52..40030.85 rows=3333 width=112) (actual time=1881.674..1892.549 rows=100 loops=1)
         Sort Key: (rank() OVER (?))
         Sort Method: top-N heapsort  Memory: 125kB
         ->  WindowAgg  (cost=39398.76..39895.14 rows=3333 width=112) (actual time=1858.236..1891.502 rows=1927 loops=1)
               ->  Gather Merge  (cost=39398.63..39786.81 rows=3333 width=1095) (actual time=1858.197..1872.547 rows=1927 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     ->  Sort  (cost=38398.61..38402.08 rows=1389 width=1095) (actual time=1838.497..1838.591 rows=642 loops=3)
                           Sort Key: (jsonb_array_length((test_data.data -> 'logs'::text))) DESC
                           Sort Method: quicksort  Memory: 742kB
                           Worker 0:  Sort Method: quicksort  Memory: 750kB
                           Worker 1:  Sort Method: quicksort  Memory: 674kB
                           ->  Parallel Seq Scan on test_data  (cost=0.00..38326.10 rows=1389 width=1095) (actual time=4.035..1836.457 rows=642 loops=3)
                                 Filter: ((((data -> 'profile'::text) ->> 'bio'::text) ~~* '%abc%'::text) AND (jsonb_array_length((data -> 'logs'::text)) > 5
))
                                 Rows Removed by Filter: 82691
 Planning Time: 0.430 ms
 Execution Time: 1892.722 ms
(18 rows)



Fast one

explain analyze -- Fast GIN-optimized query
WITH filtered AS (
    SELECT *
    FROM test_data
    WHERE data @> '{"profile": {"tags": ["devops"]}}'
)
SELECT
    id,
    data->>'user_id' AS user_id,
    data->'profile'->>'name' AS name,
    jsonb_array_length(data->'logs') AS log_count,
    RANK() OVER (ORDER BY jsonb_array_length(data->'logs') DESC) AS log_rank
FROM filtered
WHERE jsonb_array_length(data->'logs') > 5
ORDER BY log_rank
LIMIT 100;


fzhou=> explain analyze -- Fast GIN-optimized query
WITH filtered AS (
    SELECT *
    FROM test_data
    WHERE data @> '{"profile": {"tags": ["devops"]}}'
)
SELECT
    id,
    data->>'user_id' AS user_id,
    data->'profile'->>'name' AS name,
    jsonb_array_length(data->'logs') AS log_count,
    RANK() OVER (ORDER BY jsonb_array_length(data->'logs') DESC) AS log_rank
FROM filtered
WHERE jsonb_array_length(data->'logs') > 5
ORDER BY log_rank
LIMIT 100;
                                                                      QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=38966.49..38966.74 rows=100 width=80) (actual time=447.903..454.264 rows=0 loops=1)
   ->  Sort  (cost=38966.49..38968.57 rows=833 width=80) (actual time=447.900..454.260 rows=0 loops=1)
         Sort Key: (rank() OVER (?))
         Sort Method: quicksort  Memory: 25kB
         ->  WindowAgg  (cost=38814.86..38934.65 rows=833 width=80) (actual time=447.892..454.252 rows=0 loops=1)
               ->  Gather Merge  (cost=38814.73..38911.74 rows=833 width=1095) (actual time=447.887..454.245 rows=0 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     ->  Sort  (cost=37814.70..37815.57 rows=347 width=1095) (actual time=432.604..432.605 rows=0 loops=3)
                           Sort Key: (jsonb_array_length((test_data.data -> 'logs'::text))) DESC
                           Sort Method: quicksort  Memory: 25kB
                           Worker 0:  Sort Method: quicksort  Memory: 25kB
                           Worker 1:  Sort Method: quicksort  Memory: 25kB
                           ->  Parallel Seq Scan on test_data  (cost=0.00..37800.06 rows=347 width=1095) (actual time=432.300..432.301 rows=0 loops=3)
                                 Filter: ((data @> '{"profile": {"tags": ["devops"]}}'::jsonb) AND (jsonb_array_length((data -> 'logs'::text)) > 5))
                                 Rows Removed by Filter: 83333
 Planning Time: 0.596 ms
 Execution Time: 454.367 ms
(18 rows)


The other fast one

WITH filtered AS (                                                                                                                                               SELECT *                                                                                                                                                     FROM test_data                                                                                                                                               WHERE data->'profile'->>'bio' ILIKE '%abc%'  -- This will NOT use GIN index                                                                              )                                                                                                                                                            SELECT                                                                                                                                                           id,                                                                                                                                                          data->>'user_id' AS user_id,                                                                                                                                 data->'profile'->>'name' AS name,                                                                                                                            data->'profile'->>'bio' AS bio,                                                                                                                              jsonb_array_length(data->'logs') AS log_count,                                                                                                               RANK() OVER (ORDER BY jsonb_array_length(data->'logs') DESC) AS log_rank                                                                                 FROM filtered                                                                                                                                                WHERE jsonb_array_length(data->'logs') > 5 and data->'profile'->'keywords' ? 'abc'
ORDER BY log_rank
 LIMIT 100;


Use the ilike in CTE part, check the inside content, then filtering, slow, use contain @> to detect there is value, prepare CTE, then, in main query, use where like 
WHERE data->'profile'->'keywords' ? 'abc'

Why?
ILIKE '%abc%':

Requires PostgreSQL to extract the value from the JSONB field (->>'bio'), convert it to text, and do a substring match.

GIN index on JSONB only indexes keys and values, not their internal substrings.

Therefore: GIN is not used, and you get a sequential scan.

ALTER TABLE test_data
ADD COLUMN bio_text TEXT GENERATED ALWAYS AS (data->'profile'->>'bio') STORED;


CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- If not created yet:
ALTER TABLE stock.test_data
ADD COLUMN bio_text TEXT GENERATED ALWAYS AS (data->'profile'->>'bio') STORED;

CREATE INDEX bio_text_trgm_idx
ON test_data
USING gin (bio_text gin_trgm_ops);


fzhou=# set enable_bitmapscan=off;
SET
fzhou=# EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stock.test_data
WHERE bio_text ILIKE '%abc%';
                                                    QUERY PLAN
-------------------------------------------------------------------------------------------------------------------
 Seq Scan on test_data  (cost=0.00..65652.94 rows=5050 width=1735) (actual time=0.185..3300.520 rows=1927 loops=1)
   Filter: (bio_text ~~* '%abc%'::text)
   Rows Removed by Filter: 248073
   Buffers: shared hit=62528
 Planning:
   Buffers: shared hit=1
 Planning Time: 3.492 ms
 Execution Time: 3301.005 ms
(8 rows)




fzhou=# SHOW enable_bitmapscan;
 enable_bitmapscan
-------------------
 off
(1 row)

                              ^
fzhou=# set enable_bitmapscan=on;
SET
fzhou=# EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stock.test_data
WHERE bio_text ILIKE '%abc%';
                                                           QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on test_data  (cost=43.46..15465.31 rows=5050 width=1735) (actual time=2.268..30.144 rows=1927 loops=1)
   Recheck Cond: (bio_text ~~* '%abc%'::text)
   Heap Blocks: exact=1908
   Buffers: shared hit=1912
   ->  Bitmap Index Scan on bio_text_trgm_idx  (cost=0.00..42.19 rows=5050 width=0) (actual time=1.331..1.332 rows=1927 loops=1)
         Index Cond: (bio_text ~~* '%abc%'::text)
         Buffers: shared hit=4
 Planning:
   Buffers: shared hit=24 dirtied=2
 Planning Time: 5.340 ms
 Execution Time: 30.377 ms
(11 rows)




