// retrive aws managed policy and merge with mfa condition
locals {
  _aws_managed_policy_json_object = {
    for k, v in data.aws_iam_policy.aws_managed_policies :
    k => jsondecode(v.policy)
  }
  aws_managed_policies = {
    for k, v in local._aws_managed_policy_json_object :
    k => jsonencode(
      merge(v, {
        Statement = [for statement in v["Statement"] : merge(statement,
          var.should_require_mfa ? {
            Condition = {
              Bool = {
                "aws:MultiFactorAuthPresent" = "true"
              }
            }
          } : {})
        ]
        }
      )
    )
  }
  aws_managed_policies_details = {
    full_access = {
      policy_arn         = "arn:aws:iam::aws:policy/AdministratorAccess"
      policy_description = "Same as AWS Managed AdministratorAccess policy, but can config with MFA."
    }
    billing = {
      policy_arn         = "arn:aws:iam::aws:policy/job-function/Billing"
      policy_description = "Same as AWS Managed Billing policy, but can config with MFA."
    }
    read_only = {
      policy_arn         = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      policy_description = "Same as AWS Managed Billing policy, but can config with MFA."
    }
  }
  //out-of-box IAM policies, which is used for attaching to groups
  output_policy_map = {
    for k, v in local.aws_managed_policies_details :
    k => merge(
      {
        for name, value in v :
        name => value
        if name != "policy_arn"
      },
      {
        policy_doc  = data.aws_iam_policy_document.aws_managed_policies_with_mfa_option[k].json
        policy_name = k
    })
  }
}

data "aws_iam_policy" "aws_managed_policies" {
  for_each = local.aws_managed_policies_details
  arn      = each.value.policy_arn
}
data "aws_iam_policy_document" "aws_managed_policies_with_mfa_option" {
  for_each      = local.aws_managed_policies
  source_json   = local.first_time_login_without_mfa_json
  override_json = each.value
}

