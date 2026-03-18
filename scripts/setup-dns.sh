#!/bin/bash
set -euo pipefail

# ============================================================
# Route 53 Wildcard DNS Setup
# Creates *.tunnel.example.com → ALB (ALIAS record)
# ============================================================

# Load config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo "Error: .env file not found. Copy .env.example to .env and configure it."
    exit 1
fi

DOMAIN="${TUNNEL_DOMAIN:?TUNNEL_DOMAIN not set in .env}"
HOSTED_ZONE_ID="${AWS_HOSTED_ZONE_ID:?AWS_HOSTED_ZONE_ID not set in .env}"
REGION="${AWS_REGION:-ap-northeast-1}"
ALB_DNS="${ALB_DNS_NAME:?ALB_DNS_NAME not set in .env}"
ALB_ZONE="${ALB_HOSTED_ZONE_ID:?ALB_HOSTED_ZONE_ID not set in .env}"

echo ""
echo "Setting up DNS records:"
echo "  ${DOMAIN}   → ${ALB_DNS} (ALIAS)"
echo "  *.${DOMAIN} → ${ALB_DNS} (ALIAS)"
echo "  Hosted Zone: ${HOSTED_ZONE_ID}"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create Route 53 change batch with ALIAS records pointing to ALB
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "sish tunnel wildcard DNS → ALB",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "${ALB_ZONE}",
          "DNSName": "dualstack.${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.${DOMAIN}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "${ALB_ZONE}",
          "DNSName": "dualstack.${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)

echo "Creating DNS records..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --query 'ChangeInfo.Id' \
    --output text \
    --region "$REGION")

echo "Change submitted: $CHANGE_ID"
echo "Waiting for DNS propagation..."

aws route53 wait resource-record-sets-changed \
    --id "$CHANGE_ID" \
    --region "$REGION"

echo ""
echo "============================================================"
echo "  DNS setup complete!"
echo ""
echo "  Records created (ALIAS → ALB):"
echo "    ${DOMAIN}   → ${ALB_DNS}"
echo "    *.${DOMAIN} → ${ALB_DNS}"
echo ""
echo "  Verify with:"
echo "    dig +short ${DOMAIN}"
echo "    dig +short test.${DOMAIN}"
echo ""
echo "  Make sure ALB has:"
echo "    - HTTPS:443 listener with ACM cert for *.${DOMAIN}"
echo "    - Target group forwarding to EC2:18081"
echo "============================================================"
