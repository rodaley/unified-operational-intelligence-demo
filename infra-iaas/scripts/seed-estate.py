#!/usr/bin/env python3
"""
Seed the synthetic insurance estate history into Azure Monitor custom tables.

Design notes that matter:

* This runs ON an estate virtual machine and authenticates through IMDS using
  the machine's system-assigned identity. There is no secret anywhere in this
  file, no service principal, and nothing to leak. That also sidesteps the fact
  that the operator's CLI is signed in to a different directory than the one
  owning this subscription.

* Only the Python 3 standard library is used. The estate deliberately installs
  no packages, so the seeder must work on a bare Ubuntu image.

* Seeding is deterministic. Every record derives from a fixed random seed and a
  fixed anchor time, so re-running produces byte-identical content rather than a
  new, different story. Note honestly what that does and does not give you: the
  Logs Ingestion API has no upsert, so running this twice writes the same rows
  twice. The workbook therefore de-duplicates on AlertId, and the reset runbook
  is the supported way to start clean.

* Every record carries IsSynthetic=True and DataClassification. Financial
  figures are labelled "Illustrative Sample Data, not a customer estimate."
  per the specification. This is enforced centrally in `stamp()` so no record
  can be emitted without it.

The narrative is the alert-storm correlation: a storage latency fault in the
data tier propagates upward, and a large number of related alerts across the
estate are correlated into ONE actionable incident. They are related alerts,
not false positives, and correlation indicates relationship rather than proven
causation. The wording below is deliberate and should not be "improved".
"""

import argparse
import gzip
import json
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

IMDS_TOKEN_URL = (
    "http://169.254.169.254/metadata/identity/oauth2/token"
    "?api-version=2018-02-01&resource=https://monitor.azure.com/"
)

SYNTHETIC_LABEL = "Synthetic Demo Data"
FINANCIAL_LABEL = "Illustrative Sample Data, not a customer estimate."

# A fixed seed and a fixed anchor make every run reproduce the same estate.
RANDOM_SEED = 20260916

SERVICES = [
    ("Policy Administration", "web", 4200, 18500.0),
    ("Claims Intake", "web", 3100, 24000.0),
    ("Quote Engine", "app", 1850, 9700.0),
    ("Billing and Payments", "app", 2600, 31000.0),
    ("Document Archive", "data", 640, 4100.0),
]

# Which estate machines carry which service tier. These are the real VM names,
# so synthetic business records join cleanly to genuine InsightsMetrics rows.
TIER_HOSTS = {
    "web": ["vm-web-01", "vm-web-02"],
    "app": ["vm-app-01", "vm-app-02"],
    "data": ["vm-sql-01", "vm-sql-02"],
}

# Illustrative observability spend. Not a quote, not a customer estimate.
COST_ROWS = [
    ("Existing APM tool", "Application monitoring", 41000.0, 210.0, 34.0),
    ("Existing log platform", "Log analytics", 28500.0, 340.0, 41.0),
    ("Infrastructure monitoring", "Infrastructure", 12250.0, 95.0, 22.0),
    ("Synthetic monitoring", "Digital experience", 6400.0, 12.0, 8.0),
    ("Azure Monitor", "Unified platform", 19800.0, 480.0, 0.0),
]

INCIDENT_ID = "INC-2026-0916-001"

# The headline figure. 150 related alerts correlated into 1 actionable incident.
# They are related alerts, not false positives, and the correlation indicates a
# relationship rather than proven causation.
TOTAL_ALERTS = 150


def stamp(record, financial=False):
    """Attach mandatory synthetic labelling. No record escapes without it."""
    record["IsSynthetic"] = True
    record["DataClassification"] = FINANCIAL_LABEL if financial else SYNTHETIC_LABEL
    return record


def iso(moment):
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def get_token():
    request = urllib.request.Request(IMDS_TOKEN_URL, headers={"Metadata": "true"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode())["access_token"]


def build_alerts(rng, anchor):
    """
    The correlated alert storm.

    One root fault in the data tier, then related alerts rippling through the
    services that depend on it. The count is large on purpose: the point of the
    demonstration is that Azure Monitor groups them into a single incident.
    """
    records = []

    root_time = anchor - timedelta(minutes=48)
    records.append(
        stamp(
            {
                "TimeGenerated": iso(root_time),
                "AlertId": "ALRT-0001",
                "Service": "Document Archive",
                "Component": "vm-sql-01",
                "Tier": "data",
                "Severity": "Sev1",
                "Source": "Azure Monitor",
                "Message": (
                    "Storage latency on the data tier exceeded 400 ms sustained. "
                    "Earliest signal in this incident."
                ),
                "IncidentId": INCIDENT_ID,
            }
        )
    )

    # Downstream related alerts. Severity and volume vary by tier so the
    # workbook's grouping has something meaningful to show.
    #
    # The total is pinned to exactly TOTAL_ALERTS because the narration says
    # "150 related alerts correlated into 1 actionable incident" and the figure
    # on screen must match the words spoken over it.
    templates = [
        ("Connection pool saturation on {host}", "Sev2", "app"),
        ("Request queue depth above threshold on {host}", "Sev2", "app"),
        ("Upstream dependency timeout observed on {host}", "Sev3", "web"),
        ("Page render latency degraded on {host}", "Sev3", "web"),
        ("Transaction retry rate elevated on {host}", "Sev2", "web"),
        ("Batch write backlog growing on {host}", "Sev2", "data"),
        ("Replica lag increasing on {host}", "Sev3", "data"),
    ]

    window_minutes = 45
    alert_number = 2
    while alert_number <= TOTAL_ALERTS:
        # Spread the remaining alerts across the window, cycling through it so
        # the storm builds continuously rather than arriving in one clump.
        minute_offset = 1 + ((alert_number - 2) % window_minutes)
        moment = root_time + timedelta(minutes=minute_offset, seconds=rng.randint(0, 59))

        message_template, severity, tier = rng.choice(templates)
        host = rng.choice(TIER_HOSTS[tier])
        service = rng.choice([s for s in SERVICES if s[1] == tier])[0]
        records.append(
            stamp(
                {
                    "TimeGenerated": iso(moment),
                    "AlertId": "ALRT-%04d" % alert_number,
                    "Service": service,
                    "Component": host,
                    "Tier": tier,
                    "Severity": severity,
                    "Source": rng.choice(
                        ["Azure Monitor", "VM Insights", "Log Analytics"]
                    ),
                    "Message": message_template.format(host=host),
                    "IncidentId": INCIDENT_ID,
                }
            )
        )
        alert_number += 1

    return records


def build_services(rng, anchor):
    """
    Service health over the incident window.

    Health degrades as the incident develops and recovers afterwards, so the
    workbook's timechart tells the story without narration.
    """
    records = []
    start = anchor - timedelta(hours=6)
    onset = anchor - timedelta(minutes=48)

    for step in range(72):  # 5-minute buckets across six hours
        moment = start + timedelta(minutes=5 * step)
        minutes_from_onset = (moment - onset).total_seconds() / 60

        for name, tier, users, revenue in SERVICES:
            floor = 42.0 if tier == "data" else (58.0 if tier == "app" else 66.0)

            if minutes_from_onset < 0:
                health = rng.uniform(97.0, 99.8)
                impact = 0.0
            elif minutes_from_onset < 48:
                decay = min(minutes_from_onset / 48.0, 1.0)
                health = 98.0 - (98.0 - floor) * decay + rng.uniform(-1.5, 1.5)
                impact = decay
            else:
                recovery = min((minutes_from_onset - 48) / 30.0, 1.0)
                health = floor + (97.0 - floor) * recovery + rng.uniform(-1.5, 1.5)
                impact = max(0.0, 1.0 - recovery)

            health = max(0.0, min(100.0, health))
            records.append(
                stamp(
                    {
                        "TimeGenerated": iso(moment),
                        "Service": name,
                        "Tier": tier,
                        "HealthScore": round(health, 2),
                        "UsersAffected": int(users * impact),
                        "RevenueAtRiskUsd": round(revenue * impact, 2),
                    },
                    financial=True,
                )
            )

    return records


def build_costs(anchor):
    records = []
    for month_offset in range(6, 0, -1):
        moment = anchor - timedelta(days=30 * month_offset)
        for tool, category, cost, ingest, duplication in COST_ROWS:
            # Gentle drift so the trend line is not a flat, obviously-fake bar.
            drift = 1.0 + (6 - month_offset) * 0.018
            records.append(
                stamp(
                    {
                        "TimeGenerated": iso(moment),
                        "Tool": tool,
                        "Category": category,
                        "MonthlyCostUsd": round(cost * drift, 2),
                        "IngestGbPerDay": round(ingest * drift, 2),
                        "DuplicationPercent": duplication,
                    },
                    financial=True,
                )
            )
    return records


def upload(endpoint, rule_id, stream, records, token, batch_size=500):
    """POST records to the Logs Ingestion API in batches, gzip-compressed."""
    url = "%s/dataCollectionRules/%s/streams/%s?api-version=2023-01-01" % (
        endpoint.rstrip("/"),
        rule_id,
        stream,
    )
    sent = 0
    for start in range(0, len(records), batch_size):
        chunk = records[start : start + batch_size]
        body = gzip.compress(json.dumps(chunk).encode("utf-8"))
        request = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Authorization": "Bearer %s" % token,
                "Content-Type": "application/json",
                "Content-Encoding": "gzip",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                if response.status not in (200, 204):
                    raise RuntimeError("unexpected status %s" % response.status)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:500]
            raise RuntimeError(
                "ingestion failed for %s: HTTP %s %s" % (stream, error.code, detail)
            ) from error
        sent += len(chunk)
    return sent


def main():
    parser = argparse.ArgumentParser(description="Seed synthetic estate history.")
    parser.add_argument("--endpoint", required=True, help="Data collection endpoint URI")
    parser.add_argument("--rule-id", required=True, help="DCR immutable ID")
    parser.add_argument(
        "--anchor",
        default="now",
        help=(
            "UTC anchor for the incident, ISO-8601, or 'now'. Using 'now' keeps the "
            "story inside the portal's default time range on demonstration day."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate and validate records without sending them.",
    )
    arguments = parser.parse_args()

    if arguments.anchor == "now":
        anchor = datetime.now(timezone.utc)
    else:
        anchor = datetime.fromisoformat(arguments.anchor).replace(tzinfo=timezone.utc)

    rng = random.Random(RANDOM_SEED)

    alerts = build_alerts(rng, anchor)
    services = build_services(rng, anchor)
    costs = build_costs(anchor)

    # Fail loudly rather than silently shipping an unlabelled record.
    for group in (alerts, services, costs):
        for record in group:
            if record.get("IsSynthetic") is not True or not record.get("DataClassification"):
                raise RuntimeError("unlabelled record generated: %r" % record)

    print("generated %d alert records" % len(alerts))
    print("generated %d service-health records" % len(services))
    print("generated %d cost records" % len(costs))
    print("all records labelled IsSynthetic=true")

    if arguments.dry_run:
        print("DRY_RUN complete, nothing sent")
        return 0

    token = get_token()
    print("acquired managed identity token via IMDS")

    total = 0
    for stream, records in (
        ("Custom-UoiEstateAlert_CL", alerts),
        ("Custom-UoiEstateService_CL", services),
        ("Custom-UoiEstateCost_CL", costs),
    ):
        count = upload(arguments.endpoint, arguments.rule_id, stream, records, token)
        print("uploaded %d records to %s" % (count, stream))
        total += count

    print("SEED_COMPLETE total=%d incident=%s" % (total, INCIDENT_ID))
    return 0


if __name__ == "__main__":
    sys.exit(main())
