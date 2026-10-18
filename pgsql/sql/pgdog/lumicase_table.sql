
-- Create schema
CREATE SCHEMA IF NOT EXISTS claimsprocess_humana;

-- Core table (no FK)
CREATE TABLE IF NOT EXISTS claimsprocess_humana.claim_core (
    claim_id                          varchar(12) NOT NULL,
    customer_id                       INTEGER NOT NULL,
    claim_sequence_id                 INTEGER NOT NULL,
    received_dt                       DATE NOT NULL,
    adjusted_dt                       DATE,
    usual_and_customary_amt           NUMERIC(12,2),
    awp_ingredient_cost_amt           NUMERIC(12,2),
    wac_ingredient_cost_amt           NUMERIC(12,2),
    submitted_dispense_as_written_ind BOOLEAN,
    refill_nbr                        INTEGER,
    cics_claim_status_cd              TEXT,
    process_create_ts                 TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    PRIMARY KEY (claim_id, customer_id)
);

-- Extension table (no FK)
CREATE TABLE IF NOT EXISTS claimsprocess_humana.claim_extension_1 (
    claim_id                    varchar(12) NOT NULL,
    customer_id                 INTEGER NOT NULL,
    submitted_incentive_fee_amt NUMERIC(12,2),
    prescriber_last_nm          TEXT,
    submitted_unit_dosage_cd    TEXT,
    medication_id               TEXT,
    contract_unit_price_amt     NUMERIC(12,4),
    contract_ingredient_amt     NUMERIC(12,4),
    PRIMARY KEY (claim_id, customer_id)
);

-- Error table (no FK)
CREATE TABLE IF NOT EXISTS claimsprocess_humana.claim_error (
    claim_id    varchar(12) NOT NULL,
    customer_id INTEGER NOT NULL,
    error_cd    TEXT,
    error_msg   TEXT,
    error_ts    TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (claim_id, customer_id)
);

-- Helpful indexes for your filter/join pattern
CREATE INDEX IF NOT EXISTS idx_claim_core_cust_ts
    ON claimsprocess_humana.claim_core (customer_id, process_create_ts);

CREATE INDEX IF NOT EXISTS idx_ce1_join
    ON claimsprocess_humana.claim_extension_1 (claim_id, customer_id);

CREATE INDEX IF NOT EXISTS idx_ce_join
    ON claimsprocess_humana.claim_error (claim_id, customer_id);



