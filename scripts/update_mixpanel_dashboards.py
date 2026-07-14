"""
Patch existing MindsetForge Mixpanel dashboards in-place via mp CLI.

Rebuilds all 14 live bookmark params using mixpanel_headless canonical
builders, removes ghost layout tiles, and verifies each report queries cleanly.

Run after `mp login --service-account`.
"""
from __future__ import annotations

import json
import subprocess
import sys

from mixpanel_report_params import GHOST_LAYOUT_TILES, all_live_report_params


def mp_run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["mp", *args, "--format", "json"],
        capture_output=True,
        text=True,
    )


def mp_update_report(report_id: int, params: dict) -> None:
    result = mp_run(
        ["reports", "update", str(report_id), "--params", json.dumps(params)],
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
        print(f"ERROR updating report {report_id}:\n{stderr}\n{result.stdout}", file=sys.stderr)
        sys.exit(1)
    print(f"  ✓ Updated report {report_id}")


def mp_remove_ghost_tile(dashboard_id: int, report_id: int) -> None:
    result = mp_run(["dashboards", "remove-report", str(dashboard_id), str(report_id)])
    stderr = "\n".join(
        l
        for l in result.stderr.splitlines()
        if "IOError" not in l
        and "sysctlbyname" not in l
        and "Detail" not in l
        and "errno" not in l
    )
    if result.returncode != 0:
        print(
            f"ERROR removing ghost tile {report_id} from dashboard {dashboard_id}:\n"
            f"{stderr}\n{result.stdout}",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"  ✓ Removed ghost tile {report_id} from dashboard {dashboard_id}")


def mp_query_saved_report(report_id: int) -> None:
    result = subprocess.run(
        ["mp", "query", "saved-report", str(report_id)],
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    if result.returncode != 0 or "Query error" in output or "malformed request" in output.lower():
        print(f"ERROR querying report {report_id}:\n{output}", file=sys.stderr)
        sys.exit(1)
    print(f"  ✓ Query OK for report {report_id}")


def patch_all_reports() -> None:
    print("\n🔧 Rebuilding live Mixpanel report params…\n")
    for report_id, params in sorted(all_live_report_params().items()):
        mp_update_report(report_id, params)


def clean_ghost_tiles() -> None:
    print("\n🧹 Removing ghost dashboard layout tiles…\n")
    for dashboard_id, ghost_ids in GHOST_LAYOUT_TILES.items():
        for ghost_id in ghost_ids:
            mp_remove_ghost_tile(dashboard_id, ghost_id)


def verify_all_reports() -> None:
    print("\n✅ Verifying saved reports query without errors…\n")
    for report_id in sorted(all_live_report_params().keys()):
        mp_query_saved_report(report_id)


def main() -> None:
    patch_all_reports()
    clean_ghost_tiles()
    verify_all_reports()
    print("\n✅ All dashboard reports patched and verified.\n")


if __name__ == "__main__":
    main()
