Merged the 3 Water and Sewer Dep. datasets with both of Mass Install Inc.’s into one file that contains 15604 entries. 

Each entry has been flagged based on the following criteria:
- missing_serial_num → Flagged as "Yes" if the meter serial number is missing.
- missing_waterscope_acc → Flagged as "Yes" if the Waterscope account is missing.
- missing_ub_acc → Flagged as "Yes" if the utility billing account is missing.
-	non_l_metron_post_2022 → Flagged as "Yes" if installed in 2022 or later and is not an L Metron.
-	non_3_serial_num_pre_2022 → Flagged as "Yes" if installed before 2022 and the meter’s serial number does not start with a 3.
-	installed_before_2020 → Flagged as "Yes" if installed before 2020.
-	m_OR_k_manufcode → Flagged as "Yes" if the manufacture code is M or K
-	flagged_mii_acc_remaining → Flagged as "Yes" if a ‘remaining’ Mass Install Inc. account still requires a meter replacement (needs review)
-	flagged_mii_acc_onhold → Flagged as "Yes" if an ‘on hold’ Mass Install Inc. account still requires a meter replacement (needs review)
- flagged → Flagged as "Yes" if at least one of the above conditions applies across all datasets (ours and Mass Install Inc.'s)
