if (!require(pacman, quietly = TRUE)) {
  install.packages("pacman")
}

pacman::p_load(dplyr, readxl, writexl)

# load excel files
download_data <- function(file_path, skip_rows = 0, sheet = NULL) {
  # if no sheet given use first return 
  if (!is.null(sheet)) {
    return(read_excel(file_path, skip = skip_rows, sheet = sheet))
  }
  return(read_excel(file_path, skip = skip_rows))
}

# function to clean wrong waterscope account entries 
# (when the waterscope key id is missing)
# maybe ensure all the other ones are na as well so i dont accidently 
# remove the wrong column 
tidy_waterscope_data <- function(data) {
  data %>% filter(!is.na(`Consumer ID`))
}

# merge our 3 datasets on their key ids
# could give key ids as params to he fucntion as well... 
merge_datasets <- function(meter_data, waterscope_data, ub_data) {
  first_merge <- full_join(meter_data, waterscope_data, by = c("MeterSerial" = "VN ID"))
  print(sum(is.na(first_merge$MeterSerial)))  
  final_merge <- full_join(first_merge, ub_data, by = "Account")
  print(sum(is.na(final_merge$MeterSerial)))  
  return(final_merge)  
}


# flag missing key IDs across our 3 datasets
flag_missing_keys <- function(data) {
  data %>% mutate(
    missing_serial_num = ifelse(is.na(MeterSerial), "Yes", "No"),
    missing_waterscope_acc = ifelse(is.na(`Consumer ID`), "Yes", "No"),
    missing_ub_acc = ifelse(is.na(Account), "Yes", "No")
  )
}

# flag meter criteria
flag_meter_conditions <- function(data) {
  data %>% mutate(
    non_l_metron_post_2022 = ifelse(
      !is.na(InstallDate) & InstallDate > as.Date("2021-12-31") &
        !is.na(ManufDesc) & !ManufDesc %in% c("L METRON", "L-METRON") &
        !is.na(ManufCode) & !ManufCode %in% c("L", "A"), "Yes", "No"),
    non_3_serial_num_pre_2022 = ifelse(
      !is.na(InstallDate) & InstallDate <= as.Date("2021-12-31") &
        !is.na(MeterSerial) & !grepl("^3", MeterSerial), "Yes", "No"),
    installed_before_2020 = ifelse(!is.na(InstallDate) & InstallDate < as.Date("2020-01-01"), "Yes", "No"),
    m_OR_k_manufcode = ifelse(!is.na(ManufCode) & ManufCode %in% c("M", "K"), "Yes", "No")
  )
}

# flag program mismatches between our 3 datasets and mass install
flag_program_mismatches <- function(data, mii_data, oh_mii_data) {
  # grab all unique program numbers to match to our account numbers 
  # from both the on hold and remaining excel sheets
  
  # remaining programs
  unique_mii_programs <- unique(mii_data$ProgramNumber)
  # on hold programs
  unique_oh_mii_programs <- unique(oh_mii_data$ProgramNumber)
  # print(length(unique(mii_data$ProgramNumber)))
  # checking if there's a match between the account numbers from the datasets
  data <- data %>% mutate(
    flagged_mii_acc_remaining = if_else(Account %in% unique_mii_programs, "Yes", "No"),
    flagged_mii_acc_onhold = if_else(Account %in% unique_oh_mii_programs, "Yes", "No"))
  # including all the accounts from the mass install dataset by full joining
  data <- full_join(data, data.frame(Account = unique_mii_programs), by = "Account")
  data <- full_join(data, data.frame(Account = unique_oh_mii_programs), by = "Account")
  # print(sum(is.na(data$missing_from_mii_data)))
  
  # flagging all the na columns as well for program mismatches
  data %>% mutate(
    flagged_mii_acc_remaining = replace(flagged_mii_acc_remaining, is.na(flagged_mii_acc_remaining), "Yes"),
    flagged_mii_acc_onhold = replace(flagged_mii_acc_onhold, is.na(flagged_mii_acc_onhold), "Yes")
  )
}

# after the mass install data is merged fill in the other criteria columns
postmerge_fillna <- function(data) {
  data %>% mutate(
    missing_serial_num = if_else(is.na(missing_serial_num), "Yes", missing_serial_num),
    missing_waterscope_acc = if_else(is.na(missing_waterscope_acc), "Yes", missing_waterscope_acc), 
    missing_ub_acc = if_else(is.na(missing_ub_acc), "Yes", missing_ub_acc)
  )}


# final flag summary counts for all flag columns
# rows are flagged yes, even if they are na!!! since they are missing the
# criteria theyre being checked on
get_summary_counts <- function(data) {
  colSums(data[, c("missing_serial_num", "missing_waterscope_acc", "missing_ub_acc", 
                   "installed_before_2020", "m_OR_k_manufcode", "flagged_mii_acc_remaining", 
                   "flagged_mii_acc_onhold", "non_3_serial_num_pre_2022", "non_l_metron_post_2022", "flagged")] == "Yes", na.rm = TRUE)
}     



# all datasets that need to be merged 
ub_account_data <- download_data('data/All_UB_Accounts.xlsx')
meter_data <- download_data('data/All_In_Use_Meters.xlsx')
waterscope_accounts_data <- tidy_waterscope_data(download_data('data/All_WaterScope_Accounts.xls', skip = 5))
# remaining accounts mii datatset 
mii_data <- download_data('data/MII Remaining Meters.xls', skip = 1)
# on hold accounts mii datatset 
oh_mii_data <- download_data('data/MII Remaining Meters.xls', sheet = 'ON HOLD', skip = 1)

# processing the data...
merged_data <- merge_datasets(meter_data, waterscope_accounts_data, ub_account_data)
# accounts are adding 22 na w ub billing
# the increased null meter serials are the ones that dont matcvh tot he accoutn matching to waterscope
# and then just get added as rows 
print(sum(is.na(merged_data$MeterSerial)))
merged_data$InstallDate <- as.Date(merged_data$InstallDate)
merged_data <- flag_missing_keys(merged_data)
merged_data <- flag_meter_conditions(merged_data)
merged_data <- flag_program_mismatches(merged_data, mii_data, oh_mii_data)
print(sum(is.na(merged_data$MeterSerial)))
merged_data <- postmerge_fillna(merged_data)



merged_data <- merged_data %>%
  mutate(flagged = case_when(
    rowSums(across(c("missing_serial_num", "missing_waterscope_acc", "missing_ub_acc", 
                     "installed_before_2020", "m_OR_k_manufcode", "flagged_mii_acc_remaining", 
                     "flagged_mii_acc_onhold", "non_3_serial_num_pre_2022", "non_l_metron_post_2022"), 
                   ~ . == "Yes")) > 0 ~ "Yes",
    TRUE ~ "No"
  ))



# print some flag counts for final summary 
yes_counts <- get_summary_counts(merged_data)
print(yes_counts)


# save output
# write_xlsx(merged_data, "flagged_water_meter_data.xlsx")

# last bit todo:
# reorganize the code 
# case_when # .default
