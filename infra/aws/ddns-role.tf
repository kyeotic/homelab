data "aws_iam_user" "homelab" {
  user_name = "homelab"
}

resource "aws_iam_policy" "ddns-manager" {
  name        = "ddns-manager"
  description = "Manage Dynamic DNS deployments, including Caddy"

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
      "route53:ListHostedZonesByName",
      "route53:ListHostedZones",
      "route53:GetChange"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy_attachment" "proxmox-attach" {
  user       = data.aws_iam_user.homelab.user_name
  policy_arn = aws_iam_policy.ddns-manager.arn
}