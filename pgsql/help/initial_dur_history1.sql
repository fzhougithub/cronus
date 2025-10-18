-- DROP PROCEDURE stg_global.initial_dur_history1(text, text, text, text);

CREATE OR REPLACE PROCEDURE stg_global.initial_dur_history1(IN input_schema text, IN input_table text, IN input_customer text, IN input_set text)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    each_thread RECORD;
	customer_array INT[];
	v_customer INT;
	v_count INT8 := 0;
	target_schema text;
	target_table text;
	v_c52_lkp text;
	v_o59_lkp text;
	threads_table text;
BEGIN
	-- Set the time zone to America/Chicago
	PERFORM set_config('TimeZone', 'America/Chicago', true);
	
	-- Pharse the input customer LIST
	customer_array := array(SELECT unnest(string_to_array(input_customer, ','))::INT);
	
	-- Pharse the input schema
	IF input_schema in ('stg_customer','stg_global', 'stg_customer_320') 
		THEN target_schema := 'claimsprocess';
	ELSIF input_schema in ('stg_customer_humana','stg_global_humana') 
		THEN target_schema := 'claimsprocess_humana';
	ELSIF input_schema in ('stg_customer_other','stg_global_other') 
		THEN target_schema := 'claimsprocess_other';
	ELSIF input_schema in ('stg_customer_ddc','stg_global_ddc')
		THEN target_schema := 'claimsprocess_ddc';
	ELSIF input_schema in ('stg_customer_ssnc','stg_global_ssnc')  
		THEN target_schema := 'claimsprocess_ssnc';
	ELSE
		RETURN;
	END IF;
	

	--Start Looping by customer_id
	FOREACH v_customer IN ARRAY customer_array
	LOOP
		
		-- Pharse the target table
		/*if input_set ='1' 
			then target_table := 'dur_hist_3unlog320_99';
		else target_table := 'dur_hist_3unlog'||v_customer::text||'_'||input_set::text;
		end if;
		*/
		target_table := 'dur_hist_4unlog'||v_customer::text||'_'||input_set::text;
		--EXECUTE format('DROP TABLE IF EXISTS %I.%I', input_schema, target_table);
		EXECUTE format('CREATE UNLOGGED TABLE IF not EXISTS %I.%I (LIKE %I.claim_dur_history INCLUDING ALL)', target_schema, target_table, target_schema);
			
		RAISE NOTICE 'target table is %', target_table;
		
		threads_table:= 'dur_threads1_'||v_customer::text;

		v_c52_lkp := 'dur_c52_lkp_'||v_customer::text||'_'||input_set::text;
		v_o59_lkp := 'dur_o59_lkp_'||v_customer::text||'_'||input_set::text;
		-- Find all claims have not been loaded to target table for Looping
		FOR each_thread IN

			EXECUTE format('SELECT thread_value, customer_id, min_claim, max_claim, thread_count
							FROM %I.%I
							WHERE migrate_ind is null
							AND set_no::text = %L
							AND customer_id = %s
							ORDER BY thread_value
					', input_schema, threads_table, input_set, v_customer)
		
		LOOP
			
			RAISE NOTICE 'Start to refesh Customer% thread#%', each_thread.customer_id, each_thread.thread_value;
			
		
			-- Insert the claims of the thread to target table
			BEGIN
										
				EXECUTE format('INSERT INTO %I.%I
							  (customer_id
							  ,claim_id
							  ,process_create_ts
							  ,process_create_by_user_id
							  ,process_create_by_program_id
							  ,process_update_ts
							  ,process_update_by_user_id
							  ,process_update_by_program_id
							  ,process_action_ind
							  ,client_id
							  ,group_id
							  ,member_id
							  ,active_product_type
							  ,days_supply_cnt
							  ,fill_dt
							  ,metric_qty
							  ,prescriber_id
							  ,pharmacy_id
							  ,pharmacy_affiliate_id
							  ,stANDard_therapeutic_class_cd
							  ,special_therapeutic_class_cd_1
							  ,special_therapeutic_class_cd_2
							  ,special_therapeutic_class_cd_3
							  ,special_therapeutic_class_cd_4
							  ,special_therapeutic_class_cd_5
							  ,special_therapeutic_class_cd_6
							  ,special_therapeutic_class_cd_7
							  ,gcn_id
							  ,hic_list_cd_1
							  ,hic_list_cd_2
							  ,hic_list_cd_3
							  ,hic_list_cd_4
							  ,hic_list_cd_5
							  ,hic_list_cd_6
							  ,hic_list_cd_7
							  ,hic_list_cd_8
							  ,hic_list_cd_9
							  ,active_product_id
							  ,route_administration_cd
							  ,ndc_id
							  ,pharmacy_status_ind
							  ,postpay_ind_2
							  ,ndc_generic_product_ind
							  ,npi_prescriber_id
							  ,npi_pharmacy_id
							  ,adjudication_cd
							  ,cms_transition_cd
							  ,patient_location_cd
							  ,level_of_service_cd
							  ,dur_conflict_cd
							  ,therapy_class_specific_cd
							  ,authorization_nbr
							  ,associated_claim_id
							  ,claim_status_cd
							  ,npi_pharmacy_id_qualifier
							  ,refill_nbr
							  ,submitted_days_supply_cnt
							  ,gcn_sequence_nbr
							  ,fdb_hicl_sequence_nbr
							  ,generic_ind
							  ,post_pay_review_ind
							  ,health_insurance_claim_id
							  ,rail_road_benefit_id
							  ,prescription_id
							  ,submission_clarification_cd
							  ,drug_category_cd
							  ,coverage_code_1
							  ,coverage_code_2
							  ,copay_amt
							  ,tier_level_cnt
							  ,pharmacy_chain_id
							  ,pharmacy_network_id
							  ,ahfs_therapeutic_class_id
							  ,brAND_long_nm
							  ,core_9_cd
							  ,generic_therapeutic_class_id
							  ,generic_name_txt
							  ,medication_id
							  ,fill_type_cd
							  ,prescription_written_dt
							  ,added_dt
							  ,prescribed_quantity_cnt
							  ,dispensing_status_ind
							  ,relationship
							  ,record_source_ind
							  ,error_code_json
							  ,preauthorization_nbr
							  ,provider_status_cd
							  ,associated_prescription_nbr
							  ,associated_prescription_id
							  ,associated_prescription_service_dt
							  ,ndc_label_nm
							  ,postpay_ind_3
							  ,postpay_ind_4
							  ,compound_cd
							  ,hic_data_json
							  ,cob_ind
							  ,processed_cms_ind
							  ,submitted_total_prescription_cost_amt
							  ,partd_claim_process_cd
							  ,presumptive_eligibility_ind
							  ,drug_data_interaction_severity_level_cd
							  ,duplicate_allowance_cnt
							  ,drug_data_interaction_expANDed_cd
							  ,duplicate_therapy_class_id
							  ,diagnosis_cd
							  ,pharmacy_channel_cd
							  ,other_coverage_cd
							  ,dur_history_client_id)
						  SELECT dur_hist.cust_id
								,dur_hist.clm_id
								,dur_hist.prcs_add_tmsp
								,dur_hist.prcs_add_user_id
								,''DMCLAIM''
								,dur_hist.prcs_strt_tmsp
								,dur_hist.prcs_usr_id
								,NULL
								,dur_hist.prcs_actn_indr
								,CASE WHEN dur_hist.clnt_id = 9999 THEN COALESCE(o59.clnt_id,dur_hist.clnt_id) ELSE dur_hist.clnt_id END
								,dur_hist.grp_intl_id
								,dur_hist.mbr_id
								,dur_hist.actv_prd_typ
								,dur_hist.days_sply::smallint
								,dur_hist.fill_dte
								,dur_hist.mtrc_qnty
								,dur_hist.presbr_id
								,dur_hist.provr_id
								,dur_hist.provr_affl_id
								,dur_hist.std_tc_cde
								,dur_hist.spec_tc_cde_1
								,dur_hist.spec_tc_cde_2
								,dur_hist.spec_tc_cde_3
								,dur_hist.spec_tc_cde_4
								,dur_hist.spec_tc_cde_5
								,dur_hist.spec_tc_cde_6
								,dur_hist.spec_tc_cde_7
								,dur_hist.gcn
								,dur_hist.hic_list_cde_1
								,dur_hist.hic_list_cde_2
								,dur_hist.hic_list_cde_3
								,dur_hist.hic_list_cde_4
								,dur_hist.hic_list_cde_5
								,dur_hist.hic_list_cde_6
								,dur_hist.hic_list_cde_7
								,dur_hist.hic_list_cde_8
								,dur_hist.hic_list_cde_9
								,dur_hist.actv_prd_id
								,dur_hist.rte_adminn_cde
								,dur_hist.ndc
								,dur_hist.pharm_stat_indr
								,dur_hist.pay_educ_indr
								,dur_hist.gnrc_prod_indr
								,dur_hist.npi_presbr_id
								,dur_hist.npi_pharm_id
								,dur_hist.adjudn_cde
								,dur_hist.cms_transtn_cde
								,dur_hist.pat_locn_cde
								,dur_hist.lvl_of_serv_cde
								,dur_hist.dur_cfl_cde
								,dur_hist.ther_clas_cde_spec
								,dur_hist.auth_nbr
								,dur_hist.assocd_clm_id
								,COALESCE(NULLIF(TRIM(BOTH FROM dur_hist.clm_stat_cde),''''),''0'')::smallint
								,dur_hist.pharm_id_npi_qlfr
								,dur_hist.rfl_nbr::smallint
								,dur_hist.ucf_days_sply::smallint
								,dur_hist.gcn_seq_nbr
								,dur_hist.fdb_hicl_seq_nbr
								,dur_hist.gnrc_indr
								,dur_hist.pst_pay_rvw_indr
								,dur_hist.health_insurance_claim_id
								,dur_hist.rail_road_benefit_id
								,dur_hist.prescription_id
								,COALESCE(m49.submission_clarification_cd,ARRAY[dur_hist.submission_clarification_cd::smallint]) 
								,dur_hist.drug_category_cd
								,dur_hist.coverage_1_cd
								,dur_hist.coverage_2_cd
								,dur_hist.copay_at
								,dur_hist.tier_level_ct::smallint
								,dur_hist.pharm_chain_id
								,dur_hist.pharmacy_network_id
								,dur_hist.ahfs_therapeutic_class_id
								,dur_hist.brand_lng_nm
								,dur_hist.core_9_cd
								,dur_hist.generic_therapeutic_class_id::smallint
								,dur_hist.generic_name_tx
								,dur_hist.med_id
								,dur_hist.fill_type_cd
								,stg_global.verify_date_value(COALESCE(o59.rx_date_written,0)::integer) 
								,CURRENT_TIMESTAMP
								,c52.prescribed_quantity_ct
								,COALESCE(o59.dispg_stat_indr,''0'')
								,COALESCE(o59.relationship,''0'')  
								,COALESCE(o59.record_source_flag,'''') 
								,o59.error_code_json 
								,COALESCE(o59.pre_author_number,0)
								,COALESCE(o59.provider_status_code,'''')
								,COALESCE(o59.assocd_rx_nbr,''0'')  
								,COALESCE(o59.assocd_prescription_id,0)
								,stg_global.verify_date_value(COALESCE(o59.assocd_rx_serv_ste,0)::integer)
								,COALESCE(o59.ndc_label_name,'''')
								,COALESCE(o59.pst_pay_3_indr,'''')
								,COALESCE(o59.pst_pay_4_indr,'''')
								,COALESCE(o59.compound_code,0) 
								,c52_y08.hic_data_json 
								,COALESCE(o59.cob_flag,''0'') 
								,COALESCE(o59.prcsd_cms_flg,''Z'')  
								,COALESCE(o59.ucf_tot_presc_cost,0)
								,COALESCE(b45.process_as_cd,'' '') as process_as_cd
								,''N'' as presumptive_eligibility_ind
								,COALESCE(y18.ddi_severity_level_cd,'''')
								,COALESCE(y21.dpt_allowance_ct,0)
								,COALESCE(y18.ddi_expanded_cd,0) as drug_data_interaction_expanded_cd
								,COALESCE(y21.duplicate_therapy_class_id,0)
								,COALESCE(o59.diagnosis,'''')
								,'''' as pharmacy_channel_cd
								,COALESCE(c52.other_coverage_cd,0) 
								,dur_hist.clnt_id
							FROM %I.%I AS dur_hist
							LEFT JOIN %I.dur_b45_lkp as b45
							  ON dur_hist.cust_id = b45.customer_id
							 AND dur_hist.clm_id = b45.claim_id
							LEFT JOIN %I.%I o59
							  ON dur_hist.cust_id = o59.cust_id
							 AND dur_hist.clm_id = o59.document_no
							LEFT JOIN %I.dur_y18_lkp y18
							  ON dur_hist.gcn_seq_nbr = y18.gcn_seqno_id
							LEFT JOIN %I.dur_y21_lkp y21
							  ON dur_hist.gcn_seq_nbr = y21.gcn_seqno_id
							LEFT JOIN %I.%I c52
							  ON dur_hist.cust_id = c52.customer_id
							 AND dur_hist.clm_id = c52.claim_id
							LEFT JOIN %I.dur_y08_lkp c52_y08
							  ON c52.hic_external_seq_id = c52_y08.ingredient_list_id
							LEFT JOIN %I.dur_m49_lkp as m49
							  ON dur_hist.cust_id = m49.customer_id
							 AND dur_hist.clm_id = m49.claim_id
						   where dur_hist.clm_id BETWEEN %L AND %L
						   AND dur_hist.cust_id = %s
                           on conflict (customer_id, claim_id, process_create_ts) do nothing',
						   target_schema,target_table, input_schema, input_table, input_schema, input_schema, v_o59_lkp, input_schema, input_schema, input_schema, v_c52_lkp, input_schema, input_schema, 
						   each_thread.min_claim, each_thread.max_claim, each_thread.customer_id)
                        ;

				COMMIT;		
		
				RAISE NOTICE '% Cust_ID % Thread#% Inserted', CURRENT_TIMESTAMP, each_thread.customer_id, each_thread.thread_value;
			END;
								
			-- Mark the Thread set as "Y" in threads table
			BEGIN
			
				EXECUTE format('UPDATE %I.%I
								SET migrate_ind = ''Y''
								WHERE customer_id = %s
								  AND thread_value = %s
					', input_schema, threads_table, each_thread.customer_id, each_thread.thread_value);
				  
				COMMIT;
				--RAISE NOTICE '% Updated %.o59_threads.migrate_ind', CURRENT_TIMESTAMP, input_schema;
			END;
			

		END LOOP;  --All Threads 	
		RAISE NOTICE '% completed %.%', CURRENT_TIMESTAMP, target_schema, target_table;
		
	END LOOP; --All given customer_id(s)


END;
$procedure$
;
