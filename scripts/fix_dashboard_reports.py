"""
Re-links orphaned reports to their dashboards and strips the 'Duplicate of' prefix.
"""
import json
import subprocess
import sys
import time


def mp(*args):
    cmd = ["mp"] + list(args) + ["--format", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        err = "\n".join(l for l in result.stderr.splitlines()
                        if not any(x in l for x in ["IOError", "sysctlbyname", "Detail", "errno"]))
        print(f"ERROR: mp {' '.join(args)}\n{err}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)


def add_and_rename(dashboard_id, report_id, correct_name):
    """Add report to dashboard (creates a Duplicate clone), then rename the clone."""
    # Step 1: add-report clones the bookmark onto the dashboard
    result = mp("dashboards", "add-report", str(dashboard_id), str(report_id))

    # Step 2: find the newly cloned report (highest id with "Duplicate of" in name)
    all_reports = mp("reports", "list")
    dup_name = f"Duplicate of {correct_name}"
    clones = [r for r in all_reports if r["name"] == dup_name]
    if not clones:
        print(f"    ⚠️  Could not find clone for '{correct_name}' — skipping rename")
        return

    clone = max(clones, key=lambda r: r["id"])
    clone_id = clone["id"]

    # Step 3: rename it
    mp("reports", "update", str(clone_id), "--name", correct_name)
    print(f"    ✓ '{correct_name}' → clone {clone_id} renamed")
    time.sleep(0.5)  # be gentle with the API


# Dashboard → [(report_id, correct_name), ...]
PLAN = {
    11313438: [  # 🎯 Activation
        (91000972, "Onboarding Funnel"),
        (91000975, "New Sign-Ups Over Time"),
    ],
    11313443: [  # 📈 Retention
        (91000978, "D1 / D7 / D30 Retention — Free vs Premium"),
        (91000980, "D1 / D7 / D30 Retention — Partner vs No Partner"),
        (91000983, "Daily Active Users (daily_win_completed)"),
    ],
    11313444: [  # ⚡ Feature Adoption
        (91000995, "Weekly Feature Adoption — Unique Users"),
        (91000998, "Daily Win Breakdown by Type"),
        (91001002, "AI Feature Usage"),
    ],
    11313446: [  # 💰 Monetization
        (91001004, "Paywall → Subscription Funnel by Source"),
        (91001008, "Subscriptions Over Time"),
        (91001010, "Paywall Views Over Time"),
    ],
    11313448: [  # 🔗 Virality
        (91001012, "Partner Invites Sent & Accepted"),
        (91001035, "Encouragement Messages Sent"),
        (91001038, "Retention: Partner vs No Partner"),
    ],
}

DASH_NAMES = {
    11313438: "🎯 Activation",
    11313443: "📈 Retention",
    11313444: "⚡ Feature Adoption",
    11313446: "💰 Monetization",
    11313448: "🔗 Virality",
}

for dash_id, reports in PLAN.items():
    print(f"\n{DASH_NAMES[dash_id]} (id={dash_id})")
    for report_id, name in reports:
        add_and_rename(dash_id, report_id, name)

print("\n✅ All reports re-linked and renamed.")
