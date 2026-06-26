"""
Creates the 5 MindsetForge analytics dashboards in Mixpanel.
Run once after authenticating with `mp login --service-account`.
"""
import json
import subprocess
import sys


def mp(*args, input_data=None):
    """Run an mp CLI command and return parsed JSON output."""
    cmd = ["mp"] + list(args) + ["--format", "json"]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        input=input_data,
    )
    stderr = "\n".join(
        l for l in result.stderr.splitlines()
        if "IOError" not in l and "sysctlbyname" not in l
        and "Detail" not in l and "errno" not in l
    )
    if result.returncode != 0:
        print(f"ERROR running: mp {' '.join(args)}\n{stderr}\n{result.stdout}", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return result.stdout.strip()


def create_dashboard(title, description=""):
    args = ["dashboards", "create", "--title", title]
    if description:
        args += ["--description", description]
    result = mp(*args)
    dash_id = result.get("id") or result.get("dashboard_id")
    print(f"  ✓ Dashboard '{title}' → id={dash_id}")
    return dash_id


def create_report(name, report_type, params, dashboard_id, description=""):
    args = [
        "reports", "create",
        "--name", name,
        "--type", report_type,
        "--params", json.dumps(params),
        "--dashboard-id", str(dashboard_id),
    ]
    if description:
        args += ["--description", description]
    result = mp(*args)
    report_id = result.get("id") or result.get("bookmark_id")
    print(f"    ✓ Report '{name}' → id={report_id}")
    return report_id


# ─── Shared helpers ──────────────────────────────────────────────────────────

def event_metric(event_name, label=None, math="unique", filters=None):
    return {
        "type": "metric",
        "isHidden": False,
        "behavior": {
            "type": "simple",
            "name": label or event_name,
            "resourceType": "events",
            "dataGroupId": None,
            "filters": [],
            "behaviors": [
                {
                    "type": "event",
                    "name": event_name,
                    "filters": filters or [],
                    "filtersDeterminer": "all",
                }
            ],
        },
        "measurement": {
            "math": math,
            "property": None,
            "rolling": None,
            "cumulative": False,
            "perUserAggregation": None,
            "multiAttribution": None,
        },
    }


def time_last(value, unit="day"):
    return [{"dateRangeType": "in the last", "window": {"unit": unit, "value": value}, "unit": unit}]


def group_by_property(prop, prop_type="string"):
    return [{"value": prop, "resourceType": "events", "type": prop_type}]


def insights_params(metrics, time, group=None, chart_type="bar", display_options=None):
    opts = {"chartType": chart_type}
    if display_options:
        opts.update(display_options)
    return {
        "sections": {
            "show": metrics,
            "filter": [],
            "formula": [],
            "group": group or [],
            "time": time,
        },
        "columnWidths": {"bar": {}},
        "displayOptions": opts,
    }


def retention_params(entry_event, return_event, breakdown_prop=None):
    group = []
    if breakdown_prop:
        group = [{"value": breakdown_prop, "resourceType": "events", "type": "string"}]
    return {
        "sections": {
            "show": [
                {
                    "type": "metric",
                    "isExpanded": True,
                    "behavior": {
                        "type": "retention",
                        "resourceType": "events",
                        "behaviors": [
                            {
                                "type": "event",
                                "name": entry_event,
                                "filters": [],
                                "filtersDeterminer": "all",
                            },
                            {
                                "type": "event",
                                "name": return_event,
                                "filters": [],
                                "filtersDeterminer": "all",
                            },
                        ],
                        "retentionUnit": "day",
                        "retentionCustomBucketSizes": [1, 7, 30],
                        "retentionAlignmentType": "birth",
                        "retentionUnboundedMode": "none",
                    },
                    "measurement": {
                        "math": "retention_rate",
                        "retentionBucketIndex": 0,
                        "retentionSegmentationEvent": None,
                        "dataGroupId": None,
                    },
                }
            ],
            "filter": [],
            "group": group,
            "formula": [],
            "time": [{"dateRangeType": "in the last", "window": {"unit": "day", "value": 60}, "unit": "day"}],
            "cohorts": [],
            "metricLevelDataGroups": True,
        },
        "columnWidths": {"bar": {}},
        "displayOptions": {"chartType": "table"},
        "sorting": {
            "table": {
                "sortBy": "column",
                "colSortAttrs": [{"sortBy": "value", "sortOrder": "desc", "valueField": "cohortSize", "viewNLimit": 12}],
            }
        },
    }


def funnel_params(events, breakdown_prop=None):
    """Build a funnel bookmark params for Mixpanel.

    `events` is a list of (event_name, [filter_list]) tuples.
    Each filter in the list is (property, value).
    """
    def behavior(event_name, filters=None):
        event_filters = []
        if filters:
            for prop, val in filters:
                event_filters.append({
                    "property": prop,
                    "value": val,
                    "type": "string",
                    "operator": "equals",
                    "resourceType": "event",
                })
        return {
            "type": "event",
            "name": event_name,
            "filters": event_filters,
            "filtersDeterminer": "all",
        }

    group = []
    if breakdown_prop:
        group = group_by_property(breakdown_prop)

    return {
        "sections": {
            "show": [
                {
                    "type": "metric",
                    "behavior": {
                        "type": "funnel",
                        "resourceType": "events",
                        "behaviors": [behavior(e, f) for e, f in events],
                    },
                }
            ],
            "filter": [],
            "group": group,
            "time": time_last(30),
        },
        "displayOptions": {"chartType": "funnel-steps"},
    }


# ─── Dashboard 1: Activation ─────────────────────────────────────────────────

print("\n📍 Dashboard 1: Activation Funnel")
# Already created during testing — reuse id=11313438
d1 = 11313438
print(f"  ✓ Dashboard '🎯 Activation' → id={d1} (existing)")

create_report(
    "Onboarding Funnel",
    "funnels",
    funnel_params([
        ("sign_up", []),
        ("onboarding_step_completed", [("step_name", "welcome")]),
        ("onboarding_step_completed", [("step_name", "goals")]),
        ("onboarding_step_completed", [("step_name", "identity")]),
        ("onboarding_step_completed", [("step_name", "blocker")]),
        ("onboarding_completed", []),
    ]),
    d1,
    "Sign-up → each onboarding step → completed. Reveals exact drop-off step.",
)

# Sign-ups over time line chart
create_report(
    "New Sign-Ups Over Time",
    "insights",
    insights_params(
        [event_metric("sign_up", "New Sign-Ups", math="unique")],
        time_last(30),
        chart_type="line",
    ),
    d1,
)


# ─── Dashboard 2: Retention ───────────────────────────────────────────────────

print("\n📍 Dashboard 2: Retention")
d2 = create_dashboard("📈 Retention", "D1/D7/D30 cohort retention")

create_report(
    "D1 / D7 / D30 Retention — Free vs Premium",
    "retention",
    retention_params("sign_up", "daily_win_completed", breakdown_prop="plan"),
    d2,
    "Users who complete any daily win after sign-up, segmented by plan.",
)

create_report(
    "D1 / D7 / D30 Retention — Partner vs No Partner",
    "retention",
    retention_params("sign_up", "daily_win_completed", breakdown_prop="has_partner"),
    d2,
    "Does having an accountability partner improve retention?",
)

create_report(
    "Daily Active Users (daily_win_completed)",
    "insights",
    insights_params(
        [event_metric("daily_win_completed", "DAU (any win)", math="unique")],
        time_last(30),
        chart_type="line",
    ),
    d2,
)


# ─── Dashboard 3: Feature Adoption ───────────────────────────────────────────

print("\n📍 Dashboard 3: Feature Adoption")
d3 = create_dashboard("⚡ Feature Adoption", "Which features are actually used week-over-week?")

feature_events = [
    ("affirmation_session_completed", "Affirmations"),
    ("journal_entry_saved", "Journal"),
    ("coach_message_sent", "AI Coach"),
    ("habit_checked_in", "Habits"),
    ("future_self_session_completed", "Future Self"),
    ("goal_created", "Goal Created"),
    ("blueprint_completed", "Blueprint"),
    ("deep_dive_module_completed", "Deep Dive"),
    ("priority_actions_set", "Day Planned"),
]

create_report(
    "Weekly Feature Adoption — Unique Users",
    "insights",
    insights_params(
        [event_metric(e, label, math="unique") for e, label in feature_events],
        time_last(28),
        chart_type="bar",
    ),
    d3,
    "Unique users per feature per week. Core engagement signal.",
)

create_report(
    "Daily Win Breakdown by Type",
    "insights",
    insights_params(
        [event_metric("daily_win_completed", "Daily Wins", math="total")],
        time_last(30),
        group=group_by_property("win_type"),
        chart_type="bar",
    ),
    d3,
    "Which daily wins are completed most? Ranks your habit loops.",
)

create_report(
    "AI Feature Usage",
    "insights",
    insights_params(
        [event_metric("ai_feature_used", "AI Calls", math="total")],
        time_last(30),
        group=group_by_property("feature"),
        chart_type="bar",
    ),
    d3,
    "Which AI features get called most? Correlate with cost.",
)


# ─── Dashboard 4: Monetization ────────────────────────────────────────────────

print("\n📍 Dashboard 4: Monetization")
d4 = create_dashboard("💰 Monetization", "Paywall conversion rates and revenue signals")

create_report(
    "Paywall → Subscription Funnel by Source",
    "funnels",
    funnel_params([
        ("paywall_viewed", []),
        ("subscription_started", []),
    ], breakdown_prop="source"),
    d4,
    "Where users hit the paywall and which source converts best.",
)

create_report(
    "Subscriptions Over Time",
    "insights",
    insights_params(
        [event_metric("subscription_started", "New Subscriptions", math="total")],
        time_last(90),
        chart_type="line",
    ),
    d4,
)

create_report(
    "Paywall Views Over Time",
    "insights",
    insights_params(
        [
            event_metric("paywall_viewed", "Paywall Views", math="total"),
            event_metric("subscription_started", "Conversions", math="total"),
        ],
        time_last(30),
        chart_type="line",
    ),
    d4,
)


# ─── Dashboard 5: Virality ────────────────────────────────────────────────────

print("\n📍 Dashboard 5: Virality")
d5 = create_dashboard("🔗 Virality", "Accountability partner invite and acceptance rates")

create_report(
    "Partner Invites Sent & Accepted",
    "insights",
    insights_params(
        [
            event_metric("partner_invite_sent", "Invites Sent", math="total"),
            event_metric("partner_invite_accepted", "Invites Accepted", math="total"),
        ],
        time_last(30),
        chart_type="bar",
    ),
    d5,
    "Raw invite volume. Add a formula B/A to see acceptance rate.",
)

create_report(
    "Encouragement Messages Sent",
    "insights",
    insights_params(
        [event_metric("encouragement_sent", "Encouragements", math="total")],
        time_last(30),
        chart_type="line",
    ),
    d5,
)

# Retention segmented by has_partner — does having a partner improve D30?
create_report(
    "Retention: Partner vs No Partner",
    "retention",
    retention_params("sign_up", "daily_win_completed", breakdown_prop="has_partner"),
    d5,
    "D1/D7/D30 split by whether user has an accountability partner.",
)


# ─── Summary ──────────────────────────────────────────────────────────────────

print(f"""
✅ All dashboards created!

  🎯 Activation      → id={d1}
  📈 Retention       → id={d2}
  ⚡ Feature Adoption → id={d3}
  💰 Monetization    → id={d4}
  🔗 Virality        → id={d5}

Open Mixpanel → Boards to find them.
""")
