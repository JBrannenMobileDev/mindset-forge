"""
Canonical Mixpanel bookmark params for MindsetForge dashboards.

Uses mixpanel_headless Workspace builders so saved reports match the schema
Mixpanel's API validates today (avoids malformed-request errors in the UI).
"""
from __future__ import annotations

from mixpanel_headless.types import Filter, FunnelStep, Metric
from mixpanel_headless.workspace import Workspace

_ws: Workspace | None = None

ONBOARDING_STEP_NAMES = (
    "welcome",
    "goals_select",
    "goals_focus",
    "identity",
    "ai_consent",
    "blocker",
    "ai_summary",
)

FEATURE_EVENTS: list[tuple[str, str]] = [
    ("affirmation_session_completed", "Affirmations"),
    ("journal_entry_saved", "Journal"),
    ("coach_message_sent", "AI Coach"),
    ("habit_checked_in", "Habits"),
    ("future_self_session_completed", "Future Self"),
    ("goal_created", "Goal Created"),
    ("blueprint_completed", "Blueprint"),
    ("deep_dive_module_completed", "Deep Dive"),
    ("priority_actions_set", "Day Planned"),
    ("identity_evolved", "Identity Evolved"),
    ("perfect_day_achieved", "Perfect Day"),
    ("callback_fired", "Coach Callback"),
]

# Live bookmark IDs on the five production dashboards.
LIVE_REPORT_IDS: dict[str, int] = {
    "onboarding_funnel": 91001788,
    "signups_over_time": 91001802,
    "retention_plan": 91001805,
    "retention_partner": 91001808,
    "dau_daily_wins": 91001811,
    "feature_adoption": 91001812,
    "daily_win_breakdown": 91001840,
    "ai_feature_usage": 91001850,
    "paywall_funnel": 91001868,
    "subscriptions_over_time": 91001870,
    "paywall_views_over_time": 91001872,
    "trial_conversion_funnel": 91414649,
    "partner_invites": 91001874,
    "encouragement_sent": 91001877,
    "virality_retention_partner": 91001880,
}

GHOST_LAYOUT_TILES: dict[int, list[int]] = {
    11313443: [91000979, 91000981, 91000984],
    11313444: [91000996, 91001000, 91001003],
    11313446: [91001005, 91001009, 91001011],
    11313448: [91001034, 91001036, 91001039],
}


def workspace() -> Workspace:
    global _ws
    if _ws is None:
        _ws = Workspace()
    return _ws


def _bar_chart(params: dict) -> dict:
    params["displayOptions"]["chartType"] = "bar"
    return params


def onboarding_funnel_params() -> dict:
    ws = workspace()
    steps: list[str | FunnelStep] = ["sign_up"]
    for step_name in ONBOARDING_STEP_NAMES:
        steps.append(
            FunnelStep(
                "onboarding_step_completed",
                filters=[Filter.equals("step_name", step_name)],
            )
        )
    steps.append("onboarding_completed")
    return ws.build_funnel_params(steps, last=30)


def signups_over_time_params() -> dict:
    return workspace().build_params(
        "sign_up",
        last=30,
        math="unique",
        mode="timeseries",
    )


def retention_table_params(*, group_by: str) -> dict:
    return workspace().build_retention_params(
        "sign_up",
        "daily_win_completed",
        retention_unit="day",
        bucket_sizes=[1, 7, 30],
        group_by=group_by,
        last=60,
        mode="table",
    )


def dau_daily_wins_params() -> dict:
    return workspace().build_params(
        "daily_win_completed",
        last=30,
        math="unique",
        mode="timeseries",
    )


def feature_adoption_params() -> dict:
    events = [Metric(event, math="unique") for event, _ in FEATURE_EVENTS]
    return _bar_chart(
        workspace().build_params(events, last=28, mode="timeseries"),
    )


def daily_win_breakdown_params() -> dict:
    return _bar_chart(
        workspace().build_params(
            "daily_win_completed",
            last=30,
            math="total",
            group_by="win_type",
            mode="timeseries",
        ),
    )


def ai_feature_usage_params() -> dict:
    return _bar_chart(
        workspace().build_params(
            "ai_feature_used",
            last=30,
            math="total",
            group_by="feature",
            mode="timeseries",
        ),
    )


def paywall_funnel_params() -> dict:
    return workspace().build_funnel_params(
        ["paywall_viewed", "subscription_started"],
        group_by="source",
        last=30,
    )


def trial_conversion_funnel_params() -> dict:
    return workspace().build_funnel_params(
        [
            "onboarding_started",
            FunnelStep(
                "subscription_started",
                filters=[Filter.equals("is_trial", True)],
            ),
            "trial_converted",
        ],
        conversion_window=30,
        conversion_window_unit="day",
        last=90,
    )


def subscriptions_over_time_params() -> dict:
    return workspace().build_params(
        "subscription_started",
        last=90,
        math="total",
        mode="timeseries",
    )


def paywall_views_over_time_params() -> dict:
    return workspace().build_params(
        [
            Metric("paywall_viewed", math="total"),
            Metric("subscription_started", math="total"),
        ],
        last=30,
        mode="timeseries",
    )


def partner_invites_params() -> dict:
    return _bar_chart(
        workspace().build_params(
            [
                Metric("partner_invite_sent", math="total"),
                Metric("partner_invite_accepted", math="total"),
            ],
            last=30,
            mode="timeseries",
        ),
    )


def encouragement_sent_params() -> dict:
    return workspace().build_params(
        "encouragement_sent",
        last=30,
        math="total",
        mode="timeseries",
    )


def all_live_report_params() -> dict[int, dict]:
    """Map of live bookmark ID -> canonical params dict."""
    builders = {
        LIVE_REPORT_IDS["onboarding_funnel"]: onboarding_funnel_params,
        LIVE_REPORT_IDS["signups_over_time"]: signups_over_time_params,
        LIVE_REPORT_IDS["retention_plan"]: lambda: retention_table_params(group_by="plan"),
        LIVE_REPORT_IDS["retention_partner"]: lambda: retention_table_params(
            group_by="has_partner"
        ),
        LIVE_REPORT_IDS["dau_daily_wins"]: dau_daily_wins_params,
        LIVE_REPORT_IDS["feature_adoption"]: feature_adoption_params,
        LIVE_REPORT_IDS["daily_win_breakdown"]: daily_win_breakdown_params,
        LIVE_REPORT_IDS["ai_feature_usage"]: ai_feature_usage_params,
        LIVE_REPORT_IDS["paywall_funnel"]: paywall_funnel_params,
        LIVE_REPORT_IDS["trial_conversion_funnel"]: trial_conversion_funnel_params,
        LIVE_REPORT_IDS["subscriptions_over_time"]: subscriptions_over_time_params,
        LIVE_REPORT_IDS["paywall_views_over_time"]: paywall_views_over_time_params,
        LIVE_REPORT_IDS["partner_invites"]: partner_invites_params,
        LIVE_REPORT_IDS["encouragement_sent"]: encouragement_sent_params,
        LIVE_REPORT_IDS["virality_retention_partner"]: lambda: retention_table_params(
            group_by="has_partner"
        ),
    }
    return {report_id: builder() for report_id, builder in builders.items()}
