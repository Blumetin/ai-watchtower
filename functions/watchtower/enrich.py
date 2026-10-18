import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from . import ai
from .cap import allowed_cap_url, counties_from_text, fetch_cap, for_alert, instruction_for


def _err(step: str, e: Exception) -> str:
    import traceback
    code = getattr(e, "code", None)
    frames = [f"{Path(f.filename).name}:{f.name}:{f.lineno}" for f in traceback.extract_tb(e.__traceback__)[-3:]]
    print(json.dumps({"severity": "WARNING", "message": "enrich_step_failed", "step": step,
                      "error": type(e).__name__, "where": frames}))
    return f"{step}: {type(e).__name__}" + (f" {code}" if code else "")


def cap_fields(doc: dict, cap: dict | None) -> dict:
    title, summary = doc.get("title", ""), doc.get("summary", "")
    if cap is None:
        text = counties_from_text(title + summary)
        return {"cap_severity": None, "counties": text, "county_levels": {},
                "county_source": "text" if text else None, "cap_status": None, "cap_msg_type": None,
                "cap_identifier": None, "cap_references": []}
    picked = {**for_alert(cap, title, summary),
              **{k: cap.get(k) for k in ("cap_status", "cap_msg_type", "cap_identifier")},
              "cap_references": cap.get("cap_references") or []}
    if not picked["counties"]:
        picked["counties"] = counties_from_text(title + summary)
        picked["county_source"] = "text" if picked["counties"] else None
    return picked


def enrich(doc: dict, ai_budget: float | None = None) -> dict:
    token = ai.set_budget(ai_budget)
    try:
        return _enrich(doc)
    finally:
        ai.reset_budget(token)


def _enrich(doc: dict) -> dict:
    title, sender, summary = doc.get("title", ""), doc.get("sender", ""), doc.get("summary", "")
    fields, errors = {}, []

    cap = None
    if doc.get("cap_link"):
        if not allowed_cap_url(doc["cap_link"]):
            print(json.dumps({"severity": "WARNING", "message": "cap_link_blocked",
                              "host": urlparse(doc["cap_link"]).hostname}, ensure_ascii=False))
            errors.append("cap: blocked_host")
        else:
            try:
                cap = fetch_cap(doc["cap_link"])
            except Exception as e:
                errors.append(_err("cap", e))
    raw_cap, cap = cap, cap_fields(doc, cap)
    fields["counties"] = cap["counties"]
    fields["county_levels"] = cap["county_levels"]
    fields["county_source"] = cap["county_source"]
    fields["cap_status"] = cap["cap_status"]
    fields["cap_msg_type"] = cap["cap_msg_type"]
    fields["cap_identifier"] = cap["cap_identifier"]
    fields["cap_references"] = cap["cap_references"]

    try:
        fields["severity"], fields["severity_source"] = ai.grade(f"{title}\n{summary}", cap["cap_severity"])
    except Exception as e:
        errors.append(_err("grade", e))

    try:
        instruction = instruction_for(raw_cap, summary) if raw_cap else ""
        zh, fields["ai_summary_source"] = ai.summarize(title, sender, summary, instruction)
        fields["ai_summary"] = zh
        translated, report = ai.translate(zh)
        for lang, text in translated.items():
            fields[f"ai_summary_{lang}"] = text
        fields["translation_check"] = report
    except Exception as e:
        errors.append(_err("summary/translate", e))

    fields["ai_model"] = ai.MODEL
    fields["enriched_at"] = datetime.now(timezone.utc)
    if errors:
        fields["enrich_errors"] = errors
    return fields
