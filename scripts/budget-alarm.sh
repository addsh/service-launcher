#!/usr/bin/env bash
# Create a monthly AWS Budget that emails an address at 50, 80, and 100
# percent of actual spend, plus a forecast alert at 100 percent. This is a
# personal account, so the point is an early warning, not a hard cap.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <monthly-limit-usd> <notification-email>" >&2
  exit 1
fi

MONTHLY_LIMIT="$1"
NOTIFY_EMAIL="$2"
BUDGET_NAME="${BUDGET_NAME:-service-launcher-monthly}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUDGET_JSON=$(cat <<EOF
{
  "BudgetName": "${BUDGET_NAME}",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "${MONTHLY_LIMIT}",
    "Unit": "USD"
  }
}
EOF
)

notification() {
  local threshold="$1"
  local notification_type="$2"
  cat <<EOF
{
  "Notification": {
    "NotificationType": "${notification_type}",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": ${threshold},
    "ThresholdType": "PERCENTAGE"
  },
  "Subscribers": [
    {
      "SubscriptionType": "EMAIL",
      "Address": "${NOTIFY_EMAIL}"
    }
  ]
}
EOF
}

NOTIFICATIONS_JSON=$(python3 -c "
import json, sys
print(json.dumps([json.loads(arg) for arg in sys.argv[1:]]))
" "$(notification 50 ACTUAL)" "$(notification 80 ACTUAL)" "$(notification 100 ACTUAL)" "$(notification 100 FORECASTED)")

aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget "$BUDGET_JSON" \
  --notifications-with-subscribers "$NOTIFICATIONS_JSON"

echo "created budget ${BUDGET_NAME}: ${MONTHLY_LIMIT} USD monthly, alerts at 50/80/100 percent actual and 100 percent forecast to ${NOTIFY_EMAIL}"
