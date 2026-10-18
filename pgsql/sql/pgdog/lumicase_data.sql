
DO $$
DECLARE
    -- Volume & ratios
    total_claims          INTEGER := 100;
    pct_with_extension    NUMERIC  := 0.70;
    pct_with_error        NUMERIC  := 0.20;

    -- Target customer and window
    cust_id               INTEGER := 320;
    start_ts              TIMESTAMP := '2025-11-01 00:00:00.001';
    end_ts                TIMESTAMP := '2025-11-03 00:00:00.001';

    -- 12-digit claim_id numeric range (LPAD to 12 chars)
    start_claim_num       BIGINT := 0;                -- e.g., 0 -> "000000000000"
    max_claim_num         BIGINT := 999999999999;     -- "999999999999"

    -- Randomization helpers
    status_codes          TEXT[] := ARRAY['P', 'A', 'R', 'D'];
    dosage_codes          TEXT[] := ARRAY['TAB', 'CAP', 'LIQ', 'INJ'];
    prescribers           TEXT[] := ARRAY['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis'];

    -- Per-row variables
    i                     INTEGER;
    claim_num             BIGINT;
    claim_txt             TEXT;
    ts_span_seconds       BIGINT;
    ts_value              TIMESTAMP;

    will_have_ext         BOOLEAN;
    will_have_err         BOOLEAN;

    random_status         TEXT;
    random_dosage         TEXT;
    random_prescriber     TEXT;
    refill                INTEGER;
    seq_id                INTEGER;
    received              DATE;
    adjusted              DATE;
    usual_amt             NUMERIC(12,2);
    awp_amt               NUMERIC(12,2);
    wac_amt               NUMERIC(12,2);
    daw_ind               BOOLEAN;
    incentive_fee         NUMERIC(12,2);
    contract_unit_price   NUMERIC(12,4);
    contract_ingredient   NUMERIC(12,4);

    jitter_seconds        INTEGER;
    offset_seconds        INTEGER;
BEGIN
    -- Safety: ensure we don't exceed the max 12-digit value
    IF start_claim_num + total_claims - 1 > max_claim_num THEN
        RAISE EXCEPTION 'Requested % claims starting at % exceeds max %',
            total_claims, start_claim_num, max_claim_num;
    END IF;

    -- Clear existing rows for repeatability
    DELETE FROM claimsprocess_humana.claim_error
     WHERE customer_id = cust_id;

    DELETE FROM claimsprocess_humana.claim_extension_1
     WHERE customer_id = cust_id;

    DELETE FROM claimsprocess_humana.claim_core
     WHERE customer_id = cust_id
       AND process_create_ts BETWEEN start_ts AND end_ts;

    ts_span_seconds := EXTRACT(EPOCH FROM (end_ts - start_ts));

    FOR i IN 1..total_claims LOOP
        -- Strict 12-digit numeric claim_id
        claim_num := start_claim_num + i - 1;
        claim_txt := LPAD(claim_num::TEXT, 12, '0');  -- e.g., "000000000123"

        -- Spread timestamps across the window (portable interval arithmetic)
        offset_seconds := (i * ts_span_seconds / total_claims)::INT;
        jitter_seconds := FLOOR(RANDOM() * 30)::INT;
        ts_value := start_ts
                  + (offset_seconds * INTERVAL '1 second')
                  + (jitter_seconds * INTERVAL '1 second');

        -- Randomized attributes
        seq_id            := 1 + (i % 5);
        refill            := (i % 4);
        random_status     := status_codes[1 + FLOOR(RANDOM() * ARRAY_LENGTH(status_codes,1))::INT];
        random_dosage     := dosage_codes[1 + FLOOR(RANDOM() * ARRAY_LENGTH(dosage_codes,1))::INT];
        random_prescriber := prescribers[1 + FLOOR(RANDOM() * ARRAY_LENGTH(prescribers,1))::INT];

        daw_ind   := (RANDOM() < 0.30);
        usual_amt := ROUND((50 + RANDOM() * 250)::NUMERIC, 2);
        awp_amt   := ROUND((40 + RANDOM() * 200)::NUMERIC, 2);
        wac_amt   := ROUND((30 + RANDOM() * 180)::NUMERIC, 2);

        received  := DATE(ts_value);
        adjusted  := CASE
                        WHEN RANDOM() < 0.50
                        THEN received + (FLOOR(RANDOM() * 5)::INT * INTERVAL '1 day')
                        ELSE NULL
                     END;

        will_have_ext := (RANDOM() < pct_with_extension);
        will_have_err := (RANDOM() < pct_with_error);

        INSERT INTO claimsprocess_humana.claim_core (
            claim_id, customer_id, claim_sequence_id, received_dt, adjusted_dt,
            usual_and_customary_amt, awp_ingredient_cost_amt, wac_ingredient_cost_amt,
            submitted_dispense_as_written_ind, refill_nbr, cics_claim_status_cd,
            process_create_ts
        ) VALUES (
            claim_txt, cust_id, seq_id, received, adjusted,
            usual_amt, awp_amt, wac_amt,
            daw_ind, refill, random_status,
            ts_value
        );

        IF will_have_ext THEN
            incentive_fee       := ROUND((1 + RANDOM() * 8)::NUMERIC, 2);
            contract_unit_price := ROUND((0.50 + RANDOM() * 5)::NUMERIC, 4);
            contract_ingredient := ROUND((10 + RANDOM() * 120)::NUMERIC, 4);

            INSERT INTO claimsprocess_humana.claim_extension_1 (
                claim_id, customer_id, submitted_incentive_fee_amt, prescriber_last_nm,
                submitted_unit_dosage_cd, medication_id, contract_unit_price_amt,
                contract_ingredient_amt
            ) VALUES (
                claim_txt, cust_id, incentive_fee, random_prescriber,
                random_dosage, LPAD((i % 500)::TEXT, 12, '0'),  -- optional: force 12-digit medication_id
                contract_unit_price, contract_ingredient
            );
        END IF;

        IF will_have_err THEN
            INSERT INTO claimsprocess_humana.claim_error (
                claim_id, customer_id, error_cd, error_msg, error_ts
            ) VALUES (
                claim_txt, cust_id,
                CASE WHEN RANDOM() < 0.5 THEN 'E001' ELSE 'E002' END,
                CASE WHEN RANDOM() < 0.5 THEN 'Invalid NDC' ELSE 'Eligibility mismatch' END,
                ts_value + (FLOOR(RANDOM() * 120)::INT * INTERVAL '1 minute')
            );
        END IF;
    END LOOP;
END $$;

