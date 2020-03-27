terraform {
  required_version = "= 0.12.19"
}

locals {
  //true for turning on mfa access for all policies.
  mfa_condition_block = var.should_require_mfa ? [{ "test" = "Bool", "variable" = "aws:MultiFactorAuthPresent", "values" = [true, ] }] : []
  //base policy for mfa, this policy is a source of each policy which is designed to support mfa access
  first_time_login_without_mfa_json = var.should_require_mfa ? data.aws_iam_policy_document.first_time_login_without_mfa_base.json : data.aws_iam_policy_document.disable_mfa.json

  //role_policies_map depend on predefined_role_policies_map
  //role_policies_map automatically filter empty identifiers out from predefined_role_policies_map
  predefined_role_policies_map = {
    read_only_access = {
      type                   = "AWS"
      identifiers            = var.allow_read_only_access_from_other_account_arns
      iam_policy_name        = "read_only_access"
      iam_policy_description = "Attach this policy to role in account B, it allow read only access from other accounts, such as account A."
      iam_policy             = data.aws_iam_policy.read_only_access_iam_policy_for_role.policy
    }
  }
  role_policies_map = {
    for k, v in local.predefined_role_policies_map :
    k => v
    if length(v.identifiers) != 0
  }

  output_role_policies_map = {
    for k, v in local.role_policies_map :
    k => merge(v, {
      assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policies[k].json
    })
  }

  output_group_assume_policies_map = data.aws_iam_policy_document.iam_policy_attach_to_group
}

// trust policy for roles
// generating by permission policies
data "aws_iam_policy_document" "instance_assume_role_policies" {
  for_each = local.role_policies_map

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = each.value.type
      identifiers = each.value.identifiers
    }

    dynamic "condition" {
      for_each = local.mfa_condition_block
      content {
        test     = condition.value["test"]
        variable = condition.value["variable"]
        values   = condition.value["values"]
      }
    }
  }
}

//read only access policy for roles
data "aws_iam_policy" "read_only_access_iam_policy_for_role" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

// an IAM policy which is attached to a group, this group is used for assuming roles in other accounts
data "aws_iam_policy_document" "iam_policy_attach_to_group" {
  for_each = var.across_account_access_role_arns_by_group
  statement {
    actions = ["sts:AssumeRole"]

    resources = each.value

    dynamic "condition" {
      for_each = local.mfa_condition_block
      content {
        test     = condition.value["test"]
        variable = condition.value["variable"]
        values   = condition.value["values"]
      }
    }
  }
}