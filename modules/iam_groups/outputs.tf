output "name_of_group_arr" {
  value = values(aws_iam_group.groups)[*].name
}

output "user_login_keys" {
  value = {
    for user_name, profile in aws_iam_user_login_profile.user_login_profiles :
    user_name => {
      encrypted_password          = profile.encrypted_password
      group                       = var.iam_users[user_name].group_name_arr
      access_key_id               = lookup(aws_iam_access_key.credentials, user_name, { id = "" }).id
      encrypted_secret_access_key = lookup(aws_iam_access_key.credentials, user_name, { encrypted_secret = "" }).encrypted_secret
    }
  }
}
