-- DROP PROCEDURE stg_global.clm_refresh_claim_core_320(text, text, text, text);

CREATE OR REPLACE PROCEDURE stg_global.clm_refresh_claim_core_320(IN input_schema text, IN input_customer text, IN input_table text, IN target_table text)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    each_thread RECORD;
	customer_array INT[];
	v_customer INT;
	v_count INT8 := 0;
	target_schema text;
	--target_table text;
	thread_table text;
	v_core_ee1_lkp text;
	v_ext1_o60_lkp text;
	v_modify_type text;				   
				
BEGIN
	-- Set the time zone to America/Chicago
	--PERFORM set_config('TimeZone', 'America/Chicago', true);
	
	-- Pharse the input customer LIST
	customer_array := array(SELECT unnest(string_to_array(input_customer, ','))::INT);
	
	-- Pharse the input schema
	IF input_schema in ('stg_customer','stg_global') 
		THEN target_schema := 'claimsprocess';
	ELSIF input_schema in ('stg_customer_humana','stg_global_humana','stg_customer_320','stg_customer_initial') 
		THEN target_schema := 'claimsprocess_humana';
	ELSIF input_schema in ('stg_customer_other','stg_global_other') 
		THEN target_schema := 'claimsprocess_other';
	ELSE
		RETURN;
	END IF;
	
	thread_table := input_table::text ||'_threads';
	
	--target_table := 'claim_error';   --||substr(input_table,4,8);
	v_core_ee1_lkp := 'ee1';
	--v_err_a10_lkp := 'err_a10_lkp'||substr(input_table,8,4);
	v_modify_type := replace(input_table::text,'_320_','');    --'o59s10-400'
	
	INSERT INTO stg_customer_320.a_domani_migration_count (table_nm,modify_type_txt,modify_record_cnt,process_create_ts,process_create_by_user_id,process_create_by_program_id)
		VALUES (target_table,v_modify_type,0,CURRENT_TIMESTAMP,'AUDIT','DMCLAIM'); 
	
	--Start Looping by customer_id
	FOREACH v_customer IN ARRAY customer_array
	LOOP													   
		-- Find all claims have not been loaded to target table for Looping
		FOR each_thread IN

			EXECUTE format('SELECT thread_value, customer_id, min_claim, max_claim, thread_count
							FROM %I.%I
							WHERE migrate_ind = ''1''								
							AND customer_id = %s
							ORDER BY thread_value
					', input_schema, thread_table, v_customer)
		
		LOOP
			
			RAISE NOTICE '% Start on % thread#%', CURRENT_TIMESTAMP, thread_table, each_thread.thread_value;

			
			-- Refresh source.core_ee1_lkp 
			/*BEGIN
				--TRUNCATE TABLE source.core_ee1_lkp;
				EXECUTE format('TRUNCATE TABLE %I.%I', input_schema, v_core_ee1_lkp);

				EXECUTE format('INSERT INTO %I.%I
									(customer_id,claim_id,received_dt,reversal_pos_id)
								SELECT customer_id
									,claim_id
									,received_dt
									,reversal_pos_id
								FROM %I.ee1 as ee1
								WHERE customer_id = %s
								AND claim_id BETWEEN %L AND %L
							', input_schema, v_core_ee1_lkp, input_schema, each_thread.customer_id, each_thread.min_claim, each_thread.max_claim);	
				
				COMMIT;
				
				RAISE NOTICE '% Refreshed %.core_ee1_lkp', CURRENT_TIMESTAMP, input_schema;

			END;   -- End of refreshing core_ee1_lkp
			*/
			
			-- Insert the claims of the thread to target table
			BEGIN
										
				EXECUTE format('INSERT INTO %I.%I
								(active_ind
								,adjudicated_amt
								,adjudication_applied_amt
								,adjudication_cd
								,adjusted_dt
								,administrative_fee_amt
								,ahfs_therapy_class
								,alternate_business
								,alternate_dispense_fee_amt
								,alternate_ingredient_cost_amt
								,alternate_member_id
								,alternate_patient_pay_amt
								,alternate_sales_tax_amt
								,alternate_total_paid_amt
								,approved_amt
								,associated_claim_id
								,associated_prescription_id
								,associated_prescription_service_dt
								,awp_ingredient_cost_amt
								,basis_calculated_copay_cd
								,basis_calculated_dispense_fee_cd
								,basis_of_cost
								,benefit_plan_id
								,calculated_submitted_balance_amt
								,case_id
								,chronic_medication_scripts
								,cics_claim_status_cd
								,city_cd
								,claim_added_category
								,claim_id
								,claim_sequence_id
								,claim_status_cd
								,claim_type_cd
								,claim_updated_category
								,client_id
								,clinic_id
								,cms_processed_ind
								,cms_transaction_reference_nbr
								,cms_transition_cd
								,cob_applied_amt
								,cob_ind
								,compound_cd
								,compound_dispense_form_ind
								,compound_dosage_description_cd
								,compound_route_of_administration_cd
								,copay_source_cd
								,cost_plan_nm
								,coverage_cd_1
								,coverage_cd_2
								,credit_card_expiration_dt
								,credit_card_nbr
								,customer_calculated_copay_amt
								,customer_calculated_dispense_fee_amt
								,customer_calculated_ingredient_cost_amt
								,customer_calculated_sales_tax_amt
								,customer_id
								,customer_processing_amt
								,customized_authorization_nbr
								,customized_formulary_ind
								,dea_cd
								,deductible_applied_dispense_fee_amt
								,deductible_applied_ingredient_cost_amt
								,deductible_applied_sales_tax_amt
								,deductible_excluded_amt
								,deductible_specific_amt
								,deductible_specific_excluded_amt
								,deductible_status_ind
								,deductible_status_ind_2
								,deductible_system_ind
								,delete_ind
								,diagnosis_cd
								,dispensing_status_ind
								,dosage_range_check_ind
								,dosage_strength
								,drug_age_conflict_ind
								,drug_allergy_ind
								,drug_class_cd
								,drug_discount_ind
								,drug_disease_ind
								,drug_interaction_ind
								,drug_list_table_nm
								,drug_of_preference_ind
								,dual_coverage_ind
								,dual_member_ind
								,duplicate_therapy_ind
								,dur_co_agent_id_1
								,dur_co_agent_id_2
								,dur_co_agent_id_3
								,dur_co_agent_id_4
								,dur_co_agent_id_5
								,dur_co_agent_id_6
								,dur_co_agent_id_7
								,dur_co_agent_id_8
								,dur_co_agent_id_9
								,dur_co_agent_qualifier_1
								,dur_co_agent_qualifier_2
								,dur_co_agent_qualifier_3
								,dur_co_agent_qualifier_4
								,dur_co_agent_qualifier_5
								,dur_co_agent_qualifier_6
								,dur_co_agent_qualifier_7
								,dur_co_agent_qualifier_8
								,dur_co_agent_qualifier_9
								,dur_conflict_cd_1
								,dur_conflict_cd_2
								,dur_conflict_cd_3
								,dur_conflict_cd_4
								,dur_conflict_cd_5
								,dur_conflict_cd_6
								,dur_conflict_cd_7
								,dur_conflict_cd_8
								,dur_conflict_cd_9
								,dur_intervention_cd_1
								,dur_intervention_cd_2
								,dur_intervention_cd_3
								,dur_intervention_cd_4
								,dur_intervention_cd_5
								,dur_intervention_cd_6
								,dur_intervention_cd_7
								,dur_intervention_cd_8
								,dur_intervention_cd_9
								,dur_outcome_cd_1
								,dur_outcome_cd_2
								,dur_outcome_cd_3
								,dur_outcome_cd_4
								,dur_outcome_cd_5
								,dur_outcome_cd_6
								,dur_outcome_cd_7
								,dur_outcome_cd_8
								,dur_outcome_cd_9
								,dur_pps_level_effort_1
								,dur_pps_level_effort_2
								,dur_pps_level_effort_3
								,dur_pps_level_effort_4
								,dur_pps_level_effort_5
								,dur_pps_level_effort_6
								,dur_pps_level_effort_7
								,dur_pps_level_effort_8
								,dur_pps_level_effort_9
								,ect_batch_nbr
								,file_nm
								,fill_dt
								,flex_report_cd
								,formatted_diagnosis_cd_1
								,formatted_diagnosis_cd_2
								,formatted_diagnosis_cd_3
								,formatted_diagnosis_cd_4
								,formatted_diagnosis_cd_5
								,formatted_diagnosis_cd_qualifier_1
								,formatted_diagnosis_cd_qualifier_2
								,formatted_diagnosis_cd_qualifier_3
								,formatted_diagnosis_cd_qualifier_4
								,formatted_diagnosis_cd_qualifier_5
								,formulary_ind
								,fsa_applied_amt
								,gcn_id
								,generic_ind
								,generic_product_ind
								,generic_therapy_class_cd
								,gpi_claim_status_ind
								,group_id
								,hold_status_ind
								,hra_applied_amt
								,hsa_applied_amt
								,incentive_paid_amt
								,income_ind
								,inquiry_access_ind
								,institutional_cd
								,institutional_effective_begin_dt
								,intended_to_be_dispensed_days_supply_cnt
								,intended_to_be_dispensed_qty
								,internal_processing_amt
								,julian_date_partition_txt
								,level_of_service_cd
								,lics_ind
								,line_of_business_cd
								,lis_amt
								,lis_cd
								,lis_deductible_cost_amt
								,lis_effective_begin_dt
								,lis_effective_end_dt
								,lis_level
								,mac_ingredient_cost_amt
								,mac_unit_cost
								,manufacturer_administrative_fee_ind
								,match_control_nbr
								,match_ind
								,match_line_nbr
								,match_received_dt
								,match_received_julian_dt
								,matched_dt
								,medicaid_agency_id
								,medicaid_claim_id
								,medicaid_cost_amt
								,medicaid_patient_id
								,medicaid_patient_id_qualifier
								,member_birth_dt
								,member_cardholder_nm
								,member_deductible_applied_amt
								,member_deductible_cost_amt
								,member_deductible_plan_ind
								,member_effective_begin_dt
								,member_effective_end_dt
								,member_gender
								,member_history_created_ind
								,member_id
								,member_miscellaneous_data_1
								,member_miscellaneous_data_2
								,member_miscellaneous_data_3
								,member_network_ind
								,member_patient_nm
								,member_pay_difference_amt
								,member_record_status_ind
								,member_reimbursement_ind
								,member_relationship_cd
								,mop_specific_amt
								,mop_specific_excluded_amt
								,mpd_applied_to_deductible_amt
								,mpd_applied_to_mop_amt
								,mpp_specific_excluded_amt
								,mtm_cd
								,mtm_effective_begin_dt
								,ndc_amt
								,ndc_drug_category_cd
								,ndc_format_ind
								,ndc_id
								,ndc_label_nm
								,ndc_manufacturer_nm
								,network_differential_amt
								,network_id
								,network_ind
								,nightly_process_ind
								,npi_pharmacy_id
								,npi_prescriber_id
								,orange_book_cd
								,original_plan_allowed_amt
								,originating_region
								,other_payer_recognized_amt
								,other_troop_amt
								,override_copay_amt
								,override_copay_ind
								,override_copay_prct
								,override_module_nm
								,override_module_version
								,package_size
								,paid_professional_service_amt
								,partial_fill_claim_id
								,partial_fill_copay_ind
								,partial_fill_dispense_fee_amt
								,pca_allowance_amt
								,pca_allowance_percent_amt
								,pca_rollover_amt
								,pcp_id
								,pcp_suffix
								,pharmacy_affiliation_id
								,pharmacy_chain_id
								,pharmacy_id
								,pharmacy_id_qualifier
								,pharmacy_nm
								,pharmacy_plan_id
								,plan_calculated_copay_plus_coins_amt
								,plan_client_administrative_expense_amt
								,plan_copay_amt
								,plan_days_supply_cnt
								,plan_deductible_applied_amt
								,plan_dispense_fee_amt
								,plan_group_cd
								,plan_ingredient_cost_amt
								,plan_maximum_specific_amt
								,plan_metric_decimal_qty
								,plan_prescriber_id
								,plan_withhold_fee_amt
								,plro_amt
								,pos_rebate_amt
								,pos_rebate_contract_id
								,post_processing_fee_amt
								,postpay_ind_1
								,postpay_ind_2
								,postpay_ind_3
								,postpay_ind_4
								,preauthorization_nbr
								,prepay_review_ind
								,prescriber_id_qualifier_cd
								,prescriber_plan_id
								,prescriber_specialty_cd
								,prescription_id
								,prescription_origin_cd
								,prescription_reason_cd
								,prescription_written_dt
								,presented_for_billing_ind
								,price_source_ind
								,pricing_module_program
								,pricing_module_version
								,pricing_type_ind
								,primary_prescriber
								,prior_authorization_cd
								,process_create_by_device
								,process_create_by_program_id
								,process_create_by_user_id
								,process_create_ts
								,process_update_by_device_id
								,process_update_by_program_id
								,process_update_by_user_id
								,process_update_ts
								,product_service_id
								,product_service_id_qualifier
								,protocol_type_cd_01
								,protocol_type_cd_02
								,protocol_type_cd_03
								,protocol_type_cd_04
								,protocol_type_cd_05
								,protocol_type_cd_06
								,protocol_type_cd_07
								,protocol_type_cd_08
								,protocol_type_cd_09
								,protocol_type_cd_10
								,provider_status_cd
								,prudential_branch_nbr
								,prudential_charts_plan
								,prudential_contract_nbr
								,prudential_division_cd
								,prudential_medicare_ind
								,prudential_product_cd
								,quantity_rounding_cd
								,rebate_ind
								,rebate_invoice_manufacturer_amt
								,rebate_price_source_ind
								,rebate_used_pct
								,received_dt
								,record_source_ind
								,refill_nbr
								,refill_too_soon_ind
								,refills_authorized
								,report_exclusion_ind
								,report_for_rebate_ind
								,restricted_authorization_nbr
								,reversal_pos_id
								,reversal_pos_ts
								,savings_fee_amt
								,scp_id
								,scp_suffix
								,spap_applied_amt
								,specialty_drug_ind
								,specific_therapy_class_cd
								,standard_class_cd
								,standard_package_ind
								,standard_therapy_class_cd
								,submitted_balance_amt
								,submitted_birth_dt
								,submitted_copay_amt
								,submitted_days_supply_cnt
								,submitted_dispense_as_written_ind
								,submitted_dispense_fee_amt
								,submitted_incentive_amt
								,submitted_ingredient_cost_amt
								,submitted_member_id
								,submitted_member_person_cd
								,submitted_metric_decimal_qty
								,submitted_preauthorization_nbr
								,submitted_prescriber_id
								,submitted_professional_service_fee_amt
								,submitted_sales_tax_amt
								,submitted_total_prescription_cost_amt
								,supplemental_reporting_ind
								,therapy_protocol_ind
								,therapy_protocol_nm
								,tier_nbr
								,total_cob_applied_amt
								,total_member_liability_amt
								,total_paid_amt
								,total_plan_liability_amt
								,troop_applied_amt
								,troop_eligibility_ind
								,used_external_group
								,usual_and_customary_amt
								,wac_ingredient_cost_amt
								,wc_claim_representative
								,wc_employer
								,wc_file_nbr
								,wc_injury_dt)
							SELECT o59.active_indicator
								,o59.adjudicated_amt
								,o59.adj_appld_amt
								,substring(o59.pru_control_no,1,2)
								,stg_global.verify_date_value(o59.adjusted_date::integer)
								,o59.adminv_fee_amt
								,o59.am_hosp_fomulary
								,o59.alternate_business
								,o59.alt_disp_fee_amt
								,o59.alt_ingr_cost_amt
								,o59.alternate_member_id
								,o59.alt_pat_pay_amt
								,o59.alt_sales_tax_amt
								,o59.alt_tot_pd_amt
								,o59.amount_approved
								,o59.associated_document_no
								,o59.assocd_prescription_id
								,stg_global.verify_date_value(o59.assocd_rx_serv_ste::integer)
								,o59.awp_ingr_cost
								,o59.bsiscalc_copay_cde
								,o59.bsiscalc_d_fee_cde
								,o59.basis_of_cost
								,o59.benefit_plan_id
								,o59.c_s_balance
								,o59.member_case_id_data
								,o59.chronic_meds_scripts
								,o59.cics_claim_status
								,o59.cty_cde
								,o59.claim_added_category
								,o59.document_no
								,0
								,o59.claims_status
								,o59.claim_type
								,o59.claim_updated_category
								,o59.clnt_id
								,o59.clinic
								,o59.prcsd_cms_flg
								,o59.cms_xact_ref_nbr
								,o59.cms_transtn_cde
								,o59.cob_appld_amt
								,o59.cob_flag
								,o59.compound_code
								,o59.cmpd_disp_frm_indr
								,o59.cmpd_dos_descn_cde
								,o59.cmpd_rte_admin_cde
								,o59.co_pay_srce_cde
								,o59.cost_plan_name
								,o59.coverage_code_1
								,o59.coverage_code_2
								,o59.credit_card_exp_date
								,o59.credit_card_no
								,o59.cust_calc_copay
								,o59.cust_calc_disp_fee
								,o59.cust_calc_ingr_cost
								,o59.cust_calc_sales_tax
								,o59.cust_id
								,o59.cust_prcsg_amt
								,o59.customized_auth_no
								,substring(o59.pru_control_no,3,1)
								,o59.ndc_dea_code
								,o59.ded_appl_disp_fee
								,o59.ded_appl_ingr_cost
								,o59.ded_appl_sales_tax
								,o59.ded_excld_amt
								,o59.dedbl_spec_amt
								,o59.ded_spec_excld_amt
								,o59.deductible_stat_ind
								,o59.deduct_stat_indr_2
								,o59.dedbl_syst_indr
								,o59.delete_ind
								,o59.diagnosis
								,o59.dispg_stat_indr
								,o59.dosage_range_check_ind
								,o59.dosage_strength
								,o59.drug_age_conflict_ind
								,o59.drug_allergy_ind
								,o59.ndc_drug_class
								,o59.drg_disc_flg
								,o59.drug_disease_ind
								,o59.drug_interaction_ind
								,o59.drg_list_tbl_nme
								,o59.drug_of_preference_ind
								,o59.dual_cover_ind
								,o59.dual_member_ind
								,o59.duplicate_therapy_ind
								,o59.dur_coagnt_id
								,o59.dur_coagnt_id_2
								,o59.dur_coagnt_id_3
								,o59.dur_coagnt_id_4
								,o59.dur_coagnt_id_5
								,o59.dur_coagnt_id_6
								,o59.dur_coagnt_id_7
								,o59.dur_coagnt_id_8
								,o59.dur_coagnt_id_9
								,o59.dur_coagnt_qlfr
								,o59.dur_coagnt_qlfr_2
								,o59.dur_coagnt_qlfr_3
								,o59.dur_coagnt_qlfr_4
								,o59.dur_coagnt_qlfr_5
								,o59.dur_coagnt_qlfr_6
								,o59.dur_coagnt_qlfr_7
								,o59.dur_coagnt_qlfr_8
								,o59.dur_coagnt_qlfr_9
								,o59.dur_conflict_code
								,o59.dur_cfl_cde_2
								,o59.dur_cfl_cde_3
								,o59.dur_cfl_cde_4
								,o59.dur_cfl_cde_5
								,o59.dur_cfl_cde_6
								,o59.dur_cfl_cde_7
								,o59.dur_cfl_cde_8
								,o59.dur_cfl_cde_9
								,o59.dur_intervention_code
								,o59.dur_intrvn_cde_2
								,o59.dur_intrvn_cde_3
								,o59.dur_intrvn_cde_4
								,o59.dur_intrvn_cde_5
								,o59.dur_intrvn_cde_6
								,o59.dur_intrvn_cde_7
								,o59.dur_intrvn_cde_8
								,o59.dur_intrvn_cde_9
								,o59.dur_outcome_code
								,o59.dur_otcm_cde_2
								,o59.dur_otcm_cde_3
								,o59.dur_otcm_cde_4
								,o59.dur_otcm_cde_5
								,o59.dur_otcm_cde_6
								,o59.dur_otcm_cde_7
								,o59.dur_otcm_cde_8
								,o59.dur_otcm_cde_9
								,o59.dur_pps_lvl_efrt
								,o59.dur_pps_lvl_efrt_2
								,o59.dur_pps_lvl_efrt_3
								,o59.dur_pps_lvl_efrt_4
								,o59.dur_pps_lvl_efrt_5
								,o59.dur_pps_lvl_efrt_6
								,o59.dur_pps_lvl_efrt_7
								,o59.dur_pps_lvl_efrt_8
								,o59.dur_pps_lvl_efrt_9
								,o59.ect_batch_no
								,o59.file_nm
								,case when trim(o59.date_filled::text) = '''' then null else stg_global.verify_date_value(o59.date_filled::integer) end  
								,o59.flex_report_code
								,o59.frmtd_dx_cde
								,o59.frmtd_dx_cde_2
								,o59.frmtd_dx_cde_3
								,o59.frmtd_dx_cde_4
								,o59.frmtd_dx_cde_5
								,o59.frmtd_dx_cde_qlfr
								,o59.frmtd_dx_cde_qlfr2
								,o59.frmtd_dx_cde_qlfr3
								,o59.frmtd_dx_cde_qlfr4
								,o59.frmtd_dx_cde_qlfr5
								,substring(o59.pricing_type_flag,2,1)
								,o59.fsa_appld_amt
								,case when trim(o59.ndc_cls_gen::text) = '''' then null else o59.ndc_cls_gen::integer end as new_gcn_id
								,o59.ndc_generic_ind
								,o59.ndc_gen_prod_ind
								,o59.ndc_therap_clss_gen
								,o59.gpi_clm_stat_indr
								,o59.grp_intl_id
								,o59.hold_status_ind
								,o59.hra_appld_amt
								,o59.hsa_appld_amt
								,o59.incntv_pd_amt
								,o59.income_indr
								,o59.inquiry_access_ind
								,o59.instnl_cde
								,stg_global.verify_date_value(o59.instnl_effv_dt::integer)
								,o59.ds_intd_2_be_disp
								,o59.qty_intd_2_be_disp
								,o59.arg_prcsg_amt
								,o59.julian_date_partition_tx
								,o59.lvl_of_serv_cde
								,substring(o59.pru_control_no,4,1)
								,o59.lob_cde
								,o59.lis_amt
								,o59.lis_cde
								,o59.lis_ded_cst
								,stg_global.verify_date_value(o59.lis_effv_dte::integer)
								,null
								,case when substring(trim(o59.lis_cde),4,1) = '''' then null else cast(substring(o59.lis_cde,4,1) as integer) end
								,o59.mac_ingre_cost
								,o59.mac_unit_cost
								,o59.mfr_adminv_fee_flg
								,o59.match_control_number
								,o59.match_indicator
								,o59.match_line_number
								,stg_global.verify_julian_date_value(o59.match_received_date::integer)
								,o59.y2_mtch_recv_dte
								,stg_global.verify_date_value(o59.date_matched::integer)
								,o59.mdcd_agncy_id
								,o59.mdcd_clm_id
								,o59.medicaid_cost
								,o59.mdcd_pat_id
								,o59.mdcd_pat_id_qlfr
								,stg_global.verify_date_value(o59.birthdate::integer)
								,o59.member_cardholder_name
								,o59.mbr_ded_applied
								,o59.mbr_ded_cost
								,o59.mbr_ded_plan_ind
								,stg_global.verify_cyymmdd_date_value(o59.member_start_date::integer)
								,stg_global.verify_cyymmdd_date_value(o59.member_end_date::integer)
								,o59.sex
								,o59.member_history_created
								,o59.member_id
								,o59.mbr_misc_data_1
								,o59.mbr_misc_data_2
								,o59.mbr_misc_data_3
								,o59.mbr_netowrk_indicator
								,o59.member_patient_name
								,o59.mbr_pay_diff_amt
								,o59.mbr_rec_status_ind
								,o59.member_reimb_ind
								,o59.relationship
								,o59.mop_spec_amt
								,o59.mop_spec_excld_amt
								,o59.mpd_appl_2_ded_amt
								,o59.mpd_appl_2_mop_amt
								,o59.mpp_spec_excld_amt
								,o59.mtm_cde
								,stg_global.verify_date_value(o59.mtm_effv_dte::integer)
								,o59.ndc_amount
								,o59.ndc_drug_cat_code
								,o59.ndc_format_ind
								,o59.ndc
								,o59.ndc_label_name
								,o59.ndc_manuf_name
								,o59.ntwk_diffrntl_amt
								,o59.network_id
								,o59.network_indicator
								,o59.nightly_process_ind
								,o59.npi_pharm_id
								,o59.npi_presbr_id
								,o59.orn_bk_cde
								,o59.origl_pln_alwd_amt
								,o59.originating_region
								,o59.oth_payr_recog_amt
								,o59.othr_troop_amt
								,o59.ovr_co_pay_amt
								,o59.ovr_co_pay_ind
								,o59.ovr_co_pay_pcnt
								,o59.bene_cst_ovrd_mod_nme
								,o59.bene_cst_ovrd_mod_vers_nbr
								,o59.package_size
								,o59.prfnl_srv_pd_amt
								,o59.ptl_fill_clm_id
								,substring(o59.prov_vendor_id::text, 3, 1)
								,o59.ptl_fill_d_fee_amt
								,o59.pca_alwnc_amt
								,o59.pca_alwnc_prct_amt
								,o59.pca_rlovr_amt
								,o59.pcp_id
								,o59.pcp_suffix
								,o59.provider_affiliation_id
								,o59.pharm_chn_id
								,o59.provider_id
								,o59.serv_provr_id_qlfr
								,o59.provider_name
								,o59.pharmacy_plan_id
								,o59.plan_co_pay
								,o59.plan_cae
								,o59.pln_copay_amt
								,o59.plan_days_supplied
								,o59.pln_ded_applied
								,o59.plan_disp_fee
								,o59.pln_grp_cde
								,o59.plan_ingre_cost
								,o59.pln_max_spec_amt
								,o59.plan_metric_decimal_qty
								,o59.plan_prescriber
								,o59.plan_withold_fee
								,o59.plro_amt
								,o59.pos_reb_amt
								,o59.pos_reb_contr_id
								,o59.pst_prcsg_fee_amt
								,substring(o59.original_claim_no,1,1)
								,o59.pst_pay_2_indr
								,o59.pst_pay_3_indr
								,o59.pst_pay_4_indr
								,o59.pre_author_number
								,substring(o59.original_claim_no,2,1)
								,o59.presbr_id_qlfr
								,o59.prescriber_plan_id
								,o59.prescriber_specialty_code
								,o59.prescription_id
								,substring(o59.member_id_format,1,1)
								,substring(o59.member_id_format,2,2)
								,stg_global.verify_date_value(o59.rx_date_written::integer)
								,o59.presented_for_billing_ind
								,substring(o59.pricing_type_flag,1,1)
								,o59.pricing_module_program
								,o59.pricing_module_version
								,o59.PRICING_TYPE_FLAG
								,o59.primary_presc
								,o59.prior_auth_code
								,o59.device_added as process_create_by_device_id
								,''DMCLAIM'' as process_create_by_program_id
								,coalesce(o59.oper_added,'' '') as process_create_by_user_id
								,coalesce(stg_global.verify_date_value(o59.date_added::integer) + stg_global.verify_time_value(o59.time_added::integer),''1900-01-01 00:00:00'') as process_create_ts
								,o59.device_updated as process_update_by_device_id
								,o59.program_updated as process_update_by_program_id
								,o59.oper_updated as process_update_by_user_id
								,(stg_global.verify_date_value(o59.date_updated::integer) + stg_global.verify_time_value(o59.time_updated::integer)) as process_update_ts
								,o59.prod_serv_id
								,o59.prod_serv_id_qlfr
								,o59.proto_type_cd_01
								,o59.proto_type_cd_02
								,o59.proto_type_cd_03
								,o59.proto_type_cd_04
								,o59.proto_type_cd_05
								,o59.proto_type_cd_06
								,o59.proto_type_cd_07
								,o59.proto_type_cd_08
								,o59.proto_type_cd_09
								,o59.proto_type_cd_10
								,o59.provider_status_code
								,o59.pru_branch_no
								,o59.pru_charts_plan
								,o59.pru_contract_no
								,o59.pru_division_code
								,o59.pru_medicare_flag
								,o59.pru_product_code
								,o59.qty_rd_cde
								,o59.reb_indr
								,o59.reb_invc_mfr_amt
								,o59.reb_prc_src_indr
								,o59.reb_prctg_used
								,ee1.received_dt
								,o59.record_source_flag
								,o59.refill_number
								,o59.refill_to_soon_ind
								,o59.refills
								,o59.report_exclusion_flag
								,o59.rpt_for_rebate_sw
								,o59.restricted_auth_no
								,ee1.reversal_pos_id
								,null
								,o59.savegs_fee_amt
								,o59.scp_id
								,o59.scp_suffix
								,o59.spap_appld_amt
								,o59.spclty_drg_flg
								,o59.therp_class_specific
								,o59.ndc_cls_std
								,o59.std_package_ind
								,o59.ndc_therap_clss_std
								,o59.ucf_balance
								,stg_global.verify_date_value(o59.submitted_birthdate::integer)
								,o59.ucf_co_pay
								,o59.ucf_days_supply
								,o59.ucf_disp_as_writ_ind
								,o59.ucf_disp_fee
								,o59.sbmd_incntv_amt
								,o59.ucf_ingr_cost
								,o59.submitted_member_id
								,o59.submitted_member_person_cod
								,o59.ucf_metric_decimal_qty
								,o59.submitted_pre_auth_number
								,o59.submitted_prescriber_id
								,o59.sbmd_prfnl_srv_amt
								,o59.ucf_sales_tax
								,o59.ucf_tot_presc_cost
								,substring(o59.pru_control_no,5,1)
								,o59.therapy_protocol_ind
								,o59.thery_proto_nme
								,case when substring(trim(o59.prov_vendor_id::text), 4, 2) = '''' then null else cast(substring(o59.prov_vendor_id::text, 4, 2) as integer) end
								,o59.tot_cob_appld_amt
								,o59.tot_mbr_lblty_amt
								,o59.total_paid
								,o59.tot_pln_lblty_amt
								,o59.troop_appld_amt
								,o59.troop_elig_flg
								,o59.group_ext_used
								,o59.usual_and_customary_amt
								,o59.wac_ingr_cost_amt
								,o59.wc_claims_rep
								,o59.wc_employer
								,o59.wc_file_number
								,stg_global.verify_date_value(o59.wc_injury_date::integer)
						from %I.%I as o59
						left join %I.ee1 as ee1
								on o59.cust_id = ee1.customer_id  
								and o59.document_no = ee1.claim_id
						WHERE o59.cust_id = %s
						and o59.document_no BETWEEN %L AND %L
						ON CONFLICT (customer_id,claim_id,process_create_ts) DO NOTHING
						', target_schema, target_table, input_schema, input_table, input_schema, each_thread.customer_id, each_thread.min_claim, each_thread.max_claim);
						-- 
				COMMIT;		
		
				RAISE NOTICE '% Cust_ID % Thread#% Inserted % records', CURRENT_TIMESTAMP, each_thread.customer_id, each_thread.thread_value, each_thread.thread_count;
			END;
			

						
			-- Mark the Thread set as "Y" in threads table
			BEGIN
			
				EXECUTE format('UPDATE %I.%I
								SET migrate_ind = ''Y''
								WHERE customer_id = %s
								  AND thread_value = %s
					', input_schema, thread_table, each_thread.customer_id, each_thread.thread_value);
				  
				COMMIT;
				--RAISE NOTICE '% Updated %.o59_threads.migrate_ind', CURRENT_TIMESTAMP, input_schema;
			END;
			
			-- Get the count of updated records
			v_count := v_count + each_thread.thread_count;

		END LOOP;  --All Threads 	
		
		update stg_customer_320.a_domani_migration_count set modify_record_cnt = v_count, process_update_ts = CURRENT_TIMESTAMP, process_update_by_user_id = CURRENT_USER 	
		where modify_type_txt = v_modify_type and table_nm = target_table;
		commit;
  
	END LOOP; --All given customer_id(s)
	
	RAISE NOTICE '% Loaded % records of customer_id % to %.claim_core', CURRENT_TIMESTAMP, v_count, input_customer, target_schema;

END;
$procedure$
;

