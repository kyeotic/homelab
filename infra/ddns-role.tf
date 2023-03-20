resource "aws_iam_policy" "ddns-manager" {
  name        = "ddns-manager"
  description = "Manage Dynamic DNS deployments"
  # ... other configuration ...

  policy = data.aws_iam_policy_document.ddns.json
}

data "aws_iam_policy_document" "ddns" {
  statement {
    actions = [
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources",
      "route53:ChangeResourceRecordSets",
      "route53:ChangeTagsForResource",
      "route53:GetChange",
      "route53:GetDNSSEC",
      "route53:ListTagsForResource"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.kye_dev.zone_id}"
    ]
  }

  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:GetChange"
    ]
    resources = ["*"]
  }
}


