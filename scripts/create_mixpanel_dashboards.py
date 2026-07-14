"""
Creates the 5 MindsetForge analytics dashboards in Mixpanel.
Run once after authenticating with `mp login --service-account`.
"""
import json
import subprocess
import sys

from mixpanel_report_params import (
    FEATURE_EVENTS,
    ai_feature_usage_params,
    daily_win_breakdown_params,
    dau_daily_wins_params,
    encouragement_sent_params,
    onboarding_funnel_params,
    partner_invites_params,
    paywall_funnel_params,
    paywall_views_over_time_params,
    retention_table_params,
    signups_over_time_params,
    subscriptions_over_time_params,
    feature_adoption_params,
)


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
        l
        for l in result.stderr.splitlines()
        if "IOError" not in l
        and "sysctlbyname" not in l
        and "Detail" not in l
        and "errno" not in l
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
        "reports",
        "create",
        "--name",
        name,
        "--type",
        report_type,
        "--params",
        json.dumps(params),
        "--dashboard-id",
        str(dashboard_id),
    ]
    if description:
        args += ["--description", description]
    result = mp(*args)
    report_id = result.get("id") or result.get("bookmark_id")
    print(f"    ✓ Report '{name}' → id={report_id}")
    return report_id


def main():
    # ─── Dashboard 1: Activation ───────────────────────────────────────────

    print("\n📍 Dashboard 1: Activation Funnel")
    d1 = 11313438
    print(f"  ✓ Dashboard '🎯 Activation' → id={d1} (existing)")

    create_report(
        "Onboarding Funnel",
        "funnels",
        onboarding_funnel_params(),
        d1,
        "Sign-up → each onboarding step → completed. Reveals exact drop-off step.",
    )

    create_report(
        "New Sign-Ups Over Time",
        "insights",
        signups_over_time_params(),
        d1,
    )

    # ─── Dashboard 2: Retention ──────────────────────────────────────────────

    print("\n📍 Dashboard 2: Retention")
    d2 = create_dashboard("📈 Retention", "D1/D7/D30 cohort retention")

    create_report(
        "D1 / D7 / D30 Retention — Free vs Premium",
        "retention",
        retention_table_params(group_by="plan"),
        d2,
        "Users who complete any daily win after sign-up, segmented by plan.",
    )

    create_report(
        "D1 / D7 / D30 Retention — Partner vs No Partner",
        "retention",
        retention_table_params(group_by="has_partner"),
        d2,
        "Does having an accountability partner improve retention?",
    )

    create_report(
        "Daily Active Users (daily_win_completed)",
        "insights",
        dau_daily_wins_params(),
        d2,
    )

    # ─── Dashboard 3: Feature Adoption ───────────────────────────────────────

    print("\n📍 Dashboard 3: Feature Adoption")
    d3 = create_dashboard(
        "⚡ Feature Adoption",
        "Which features are actually used week-over-week?",
    )

    create_report(
        "Weekly Feature Adoption — Unique Users",
        "insights",
        feature_adoption_params(),
        d3,
        "Unique users per feature per week. Core engagement signal.",
    )

    create_report(
        "Daily Win Breakdown by Type",
        "insights",
        daily_win_breakdown_params(),
        d3,
        "Which daily wins are completed most? Ranks your habit loops.",
    )

    create_report(
        "AI Feature Usage",
        "insights",
        ai_feature_usage_params(),
        d3,
        "Which AI features get called most? Correlate with cost.",
    )

    # ─── Dashboard 4: Monetization ───────────────────────────────────────────

    print("\n📍 Dashboard 4: Monetization")
    d4 = create_dashboard("💰 Monetization", "Paywall conversion rates and revenue signals")

    create_report(
        "Paywall → Subscription Funnel by Source",
        "funnels",
        paywall_funnel_params(),
        d4,
        "Where users hit the paywall and which source converts best.",
    )

    create_report(
        "Subscriptions Over Time",
        "insights",
        subscriptions_over_time_params(),
        d4,
    )

    create_report(
        "Paywall Views Over Time",
        "insights",
        paywall_views_over_time_params(),
        d4,
    )

    # ─── Dashboard 5: Virality ───────────────────────────────────────────────

    print("\n📍 Dashboard 5: Virality")
    d5 = create_dashboard("🔗 Virality", "Accountability partner invite and acceptance rates")

    create_report(
        "Partner Invites Sent & Accepted",
        "insights",
        partner_invites_params(),
        d5,
        "Raw invite volume. Add a formula B/A to see acceptance rate.",
    )

    create_report(
        "Encouragement Messages Sent",
        "insights",
        encouragement_sent_params(),
        d5,
    )

    create_report(
        "Retention: Partner vs No Partner",
        "retention",
        retention_table_params(group_by="has_partner"),
        d5,
        "D1/D7/D30 split by whether user has an accountability partner.",
    )

    print(f"""
✅ All dashboards created!

  🎯 Activation      → id={d1}
  📈 Retention       → id={d2}
  ⚡ Feature Adoption → id={d3}
  💰 Monetization    → id={d4}
  🔗 Virality        → id={d5}

  Feature events tracked: {len(FEATURE_EVENTS)}

Open Mixpanel → Boards to find them.
""")


if __name__ == "__main__":
    main()
