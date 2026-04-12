#!/usr/bin/env python3

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def summarize_prompt(prompt: str) -> str:
    text = " ".join((prompt or "").split())
    if not text:
        return "Review the workstream context and choose the next concrete step."
    sentence = text.split(".", 1)[0].strip()
    return sentence or text[:140]


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", required=True)
    parser.add_argument("--queue", required=True)
    parser.add_argument("--now", required=True)
    parser.add_argument("--source-plan", required=True)
    args = parser.parse_args()

    plan_path = Path(args.plan)
    plan = json.loads(plan_path.read_text())
    generated_at = datetime.now(timezone.utc).isoformat()

    workstreams = plan.get("workstreams_to_open") or []
    queue_items = []
    for idx, item in enumerate(workstreams, start=1):
        queue_items.append(
            {
                "rank": idx,
                "workspace": item.get("name", "unknown"),
                "display_name": item.get("display_name") or item.get("name", "Unknown"),
                "priority": item.get("priority", "medium"),
                "reason": item.get("reason", ""),
                "next_action": summarize_prompt(item.get("prompt", "")),
            }
        )

    queue_payload = {
        "date": plan.get("date"),
        "generated_at": generated_at,
        "count": len(queue_items),
        "items": queue_items,
    }

    now_item = queue_items[0] if queue_items else None
    fallback_items = queue_items[1:4] if len(queue_items) > 1 else []
    now_payload = {
        "date": plan.get("date"),
        "generated_at": generated_at,
        "now": {
            "workspace": now_item["workspace"] if now_item else "idle",
            "title": now_item["display_name"] if now_item else "No recommended action",
            "priority": now_item["priority"] if now_item else "none",
            "reason": now_item["reason"] if now_item else "No workstreams were shortlisted in the current plan.",
            "next_action": now_item["next_action"] if now_item else "Review your workstreams and rebuild the plan.",
        },
        "fallbacks": fallback_items,
    }

    write_json(Path(args.queue), queue_payload)
    write_json(Path(args.now), now_payload)
    write_json(Path(args.source_plan), plan)


if __name__ == "__main__":
    main()
