SELECT
	    c.customer_id ,
	    h87.full_title AS customer_name,
	     c.client_id ,
	    -- cl.full_title as client_name,
	    trim(TO_CHAR(c.pharmacy_id, '0000000')) AS pharmacy_id,
	  --  c.pharmacy_affiliation_id,
	    c.npi_prescriber_id,
	    c.fill_dt,
	    c.prescription_id,
	    c.specific_therapy_class_cd,
	    c.gcn_id,
	    c.claim_status_cd,
	    c.claim_id,
	    c.total_paid_amt,
	  --  c.pharmacy_chain_id,
	    (   SELECT
	            COALESCE(S50C.postal_st_cd, s.postal_st_cd)
	        FROM customer.s50            s
	        LEFT OUTER JOIN customer.s50 S50C
	            ON  S50C.PHARMACY_ID = S.PHARMACY_ID
	            AND S50C.RECORD_TYPE_CD = 'C'
	            AND S50C.CUSTOMER_SET_ID = e21.customer_set_id
	        WHERE s.pharmacy_id::INT = c.pharmacy_id
	        AND s.postal_st_cd IS NOT NULL
	        AND s.RECORD_TYPE_CD IN ( 'A',
	                                 'M' )
	        LIMIT 1) AS pharmacy_address_state , a10a.claim_error_cd_01 , a10a.claim_error_cd_02 ,
	    a10a.claim_error_cd_03 , a10a.claim_error_cd_04 , a10a.claim_error_cd_05 ,
	    a10a.claim_error_cd_06 , a10a.claim_error_cd_07 , a10a.claim_error_cd_08 ,
	    a10a.claim_error_cd_09 , a10a.claim_error_cd_10
	FROM claimsprocess_humana.claim_core     c
	INNER JOIN customer.customr0 h87
	    ON  h87.CUSTOMER_NO = c.customer_id
	INNER JOIN customer.e21 e21
	    ON  e21.customer_id = c.customer_id
	    AND e21.customer_set_type_id = 2
	INNER JOIN
	    (   SELECT
	            a10.customer_id,
	            a10.claim_id ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 1)  AS claim_error_cd_01 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 2)  AS claim_error_cd_02 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 3)  AS claim_error_cd_03 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 4)  AS claim_error_cd_04 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 5)  AS claim_error_cd_05 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 6)  AS claim_error_cd_06 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 7)  AS claim_error_cd_07 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 8)  AS claim_error_cd_08 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 9)  AS claim_error_cd_09 ,
	            split_part(string_agg(a10.claim_error_cd, ','), ',', 10) AS claim_error_cd_10
	        FROM claimsprocess_humana.claim_error                                         a10
	        WHERE a10.customer_id = $1
	        GROUP BY a10.customer_id,
	            a10.claim_id) a10a
	    ON  1 = 1
	    AND a10a.customer_id = c.customer_id
	    AND a10a.claim_id = c.claim_id
	WHERE 1 = 1
		AND
		 c."customer_id" =  $2
		 AND c.pharmacy_id > 0
		 --and c.client_id  = 6
	    AND (c.claim_status_cd IN ('10', '11') and $3 = 'paid'
	          or c.claim_status_cd in ('70', '71') and $4 = 'denied'
	          or c.claim_status_cd  in ('10', '11', '70', '71') and $5 = 'all')
		 AND ( c."fill_dt" >= $6 AND c."fill_dt" <= $7 )
		 AND EXISTS (SELECT 1 FROM claimsprocess_humana.CLAIM_ERROR A10 WHERE 1 = 1
	    AND a10.customer_id = c.customer_id
	    AND a10.claim_id = c.claim_id
	    AND 0 = 0
	                             )
	      ORDER BY customer_id ,  c.client_id ,
	    c.pharmacy_id,
	    claim_id;




Thanks for sharing the full query — now the root cause is very clear.

👉 **Your 17‑hour runtime is 100% expected with this design.**  
There are **two major performance killers** in your query:

***

# 🔥 1. WORST offender: correlated subquery

This part:

```sql
(SELECT
    COALESCE(S50C.postal_st_cd, s.postal_st_cd)
 FROM customer.s50 s
 LEFT JOIN customer.s50 S50C ...
 WHERE s.pharmacy_id::INT = c.pharmacy_id
 ...
 LIMIT 1)
```

## ❌ Why it’s killing you

*   Runs **once per row of `claim_core`**
*   If `claim_core` has millions of rows → **millions of executions**
*   Each execution scans `customer.s50`

💥 This alone can turn a seconds query into **hours**

***

# 🔥 2. Hidden problem: `pharmacy_id::INT`

```sql
s.pharmacy_id::INT = c.pharmacy_id
```

👉 This forces:

*   full scan
*   index unusable

***

# 🔥 3. Weak aggregation subquery

```sql
string_agg(...) + split_part(...)
```

👉 This:

*   builds string for *all rows*
*   then splits 10 times
*   very expensive per group

***

# ✅ ✅ FIX: rewrite to JOIN (set-based)

## 🎯 Replace the correlated subquery completely

***

### ✅ Optimized version (core fix)

```sql
LEFT JOIN customer.s50 s
  ON s.pharmacy_id::INT = c.pharmacy_id
 AND s.postal_st_cd IS NOT NULL
 AND s.record_type_cd IN ('A','M')

LEFT JOIN customer.s50 s50c
  ON s50c.pharmacy_id = s.pharmacy_id
 AND s50c.record_type_cd = 'C'
 AND s50c.customer_set_id = e21.customer_set_id
```

Then replace:

```sql
(SELECT ...) AS pharmacy_address_state
```

with:

```sql
COALESCE(s50c.postal_st_cd, s.postal_st_cd) AS pharmacy_address_state
```

***

# ✅ ✅ FULL rewritten query (optimized)

Here’s your fixed version (core changes only):

```sql
SELECT
    c.customer_id,
    h87.full_title AS customer_name,
    c.client_id,
    trim(to_char(c.pharmacy_id, '0000000')) AS pharmacy_id,
    c.npi_prescriber_id,
    c.fill_dt,
    c.prescription_id,
    c.specific_therapy_class_cd,
    c.gcn_id,
    c.claim_status_cd,
    c.claim_id,
    c.total_paid_amt,

    COALESCE(s50c.postal_st_cd, s.postal_st_cd) AS pharmacy_address_state,

    a10a.claim_error_cd_01,
    a10a.claim_error_cd_02,
    a10a.claim_error_cd_03,
    a10a.claim_error_cd_04,
    a10a.claim_error_cd_05,
    a10a.claim_error_cd_06,
    a10a.claim_error_cd_07,
    a10a.claim_error_cd_08,
    a10a.claim_error_cd_09,
    a10a.claim_error_cd_10

FROM claimsprocess_humana.claim_core c

JOIN customer.customr0 h87
  ON h87.customer_no = c.customer_id

JOIN customer.e21 e21
  ON e21.customer_id = c.customer_id
 AND e21.customer_set_type_id = 2

LEFT JOIN customer.s50 s
  ON s.pharmacy_id::INT = c.pharmacy_id
 AND s.postal_st_cd IS NOT NULL
 AND s.record_type_cd IN ('A','M')

LEFT JOIN customer.s50 s50c
  ON s50c.pharmacy_id = s.pharmacy_id
 AND s50c.record_type_cd = 'C'
 AND s50c.customer_set_id = e21.customer_set_id

JOIN (
    SELECT
        a10.customer_id,
        a10.claim_id,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 1)  AS claim_error_cd_01,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 2)  AS claim_error_cd_02,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 3)  AS claim_error_cd_03,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 4)  AS claim_error_cd_04,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 5)  AS claim_error_cd_05,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 6)  AS claim_error_cd_06,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 7)  AS claim_error_cd_07,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 8)  AS claim_error_cd_08,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 9)  AS claim_error_cd_09,
        split_part(string_agg(a10.claim_error_cd, ','), ',', 10) AS claim_error_cd_10
    FROM claimsprocess_humana.claim_error a10
    WHERE a10.customer_id = $1
    GROUP BY a10.customer_id, a10.claim_id
) a10a
  ON a10a.customer_id = c.customer_id
 AND a10a.claim_id = c.claim_id

WHERE
    c.customer_id = $2
    AND c.pharmacy_id > 0
    AND (
        (c.claim_status_cd IN ('10','11') AND $3 = 'paid') OR
        (c.claim_status_cd IN ('70','71') AND $4 = 'denied') OR
        (c.claim_status_cd IN ('10','11','70','71') AND $5 = 'all')
    )
    AND c.fill_dt BETWEEN $6 AND $7

ORDER BY
    c.customer_id,
    c.client_id,
    c.pharmacy_id,
    c.claim_id;
```

***

# ✅ EXTRA CRITICAL FIXES (huge impact)

## ✅ 1. Fix index usage

Create indexes:

```sql
-- critical one
CREATE INDEX ON customer.s50 (pharmacy_id);

CREATE INDEX ON customer.s50 (pharmacy_id, record_type_cd, customer_set_id);

CREATE INDEX ON claimsprocess_humana.claim_error (customer_id, claim_id);

CREATE INDEX ON claimsprocess_humana.claim_core (customer_id, fill_dt);
```

***

## ✅ 2. REMOVE this cast if possible

```sql
s.pharmacy_id::INT = c.pharmacy_id
```

👉 Better:

*   make both columns same type
*   or cast the **smaller side**

***

## ✅ 3. Remove useless EXISTS

You have:

```sql
AND EXISTS (SELECT 1 FROM claim_error ...)
```

👉 But you're already JOINING `a10a`

✅ Remove it → saves another scan

***

# 🚀 Expected improvement

After these fixes:

| Before                 | After             |
| ---------------------- | ----------------- |
| 17 hours               | seconds → minutes |
| millions of subqueries | 1 join            |
| repeated scans         | indexed joins     |

***

# ✅ Bottom line

Your slowdown comes from:

1.  ❌ correlated subquery (main problem)
2.  ❌ cast breaking index
3.  ❌ redundant EXISTS
4.  ❌ heavy string aggregation pattern

***

If you want next step, I can:

*   rewrite the `string_agg` part into a **much faster window function version**
*   analyze `EXPLAIN PLAN` with you
*   show how to make it run **under 10 seconds**

Just say 👍

