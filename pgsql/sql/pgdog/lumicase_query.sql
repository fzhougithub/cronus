select cc.claim_id,
    cc.customer_id,
    cc.claim_sequence_id,
    cc.received_dt,
    cc.adjusted_dt,
    cc.usual_and_customary_amt,
    cc.awp_ingredient_cost_amt,
    cc.wac_ingredient_cost_amt,
    cc.submitted_dispense_as_written_ind,
    cc.refill_nbr,
    cc.cics_claim_status_cd,
    ce1.submitted_incentive_fee_amt,
    ce1.prescriber_last_nm,
    ce1.submitted_unit_dosage_cd,
    ce1.medication_id,
    ce1.contract_unit_price_amt,
    ce1.contract_ingredient_amt
   FROM claimsprocess_humana.claim_core cc
     LEFT JOIN claimsprocess_humana.claim_extension_1 ce1 ON ce1.claim_id::text = cc.claim_id::text AND ce1.customer_id = cc.customer_id
     left join claimsprocess_humana.claim_error ce ON ce.claim_id::text = cc.claim_id::text AND ce.customer_id = cc.customer_id
where cc.customer_id = 320
and cc.process_create_ts between '2025-11-01 00:00:00.001 -0500'::timestamp and '2025-11-03 00:00:00.001 -0500'::timestamp;

