#!/usr/bin/env bash
set -euo pipefail

# Script utilitaire pour pousser des métriques vers Pushgateway
# Usage: ./metrics.sh [metric_name] [metric_value] [metric_type] [help_text]

METRIC_NAME="${1:-restic_custom_metric}"
METRIC_VALUE="${2:-1}"
METRIC_TYPE="${3:-gauge}"
HELP_TEXT="${4:-Custom metric from backup system}"
HOSTNAME_TAG="${BACKUP_HOSTNAME:-workflow}"

if [[ -z "${PUSHGATEWAY_URL:-}" ]]; then
    echo "ATTENTION: PUSHGATEWAY_URL non défini, métriques non exportées"
    exit 0
fi

echo "[metrics] Export de la métrique: $METRIC_NAME = $METRIC_VALUE"

cat <<EOF | curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/restic_custom/instance/${HOSTNAME_TAG}" --max-time 10 --silent
# TYPE ${METRIC_NAME} ${METRIC_TYPE}
# HELP ${METRIC_NAME} ${HELP_TEXT}
${METRIC_NAME} ${METRIC_VALUE}
EOF

echo "[metrics] Métrique exportée vers Pushgateway"
