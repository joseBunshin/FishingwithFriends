"""
Confluence migration script — uploads docs/ tree to bunshin.atlassian.net.

Run: python scripts/confluence_migrate.py

Creates the page hierarchy:
  Bunshin Project Master Reference (existing)
    └── Fishing with Friends
        ├── Overview               (README.md)
        ├── Product
        │   ├── v1 Requirements    (docs/brainstorms/...)
        │   └── Store Listings     (docs/STORE_LISTINGS.md)
        ├── Architecture
        │   ├── Supabase Setup     (docs/SUPABASE_SETUP.md)
        │   ├── Edge Functions     (docs/EDGE_FUNCTIONS.md)
        │   └── Email Templates    (docs/EMAIL_TEMPLATES.md)
        ├── Plans
        │   └── M0 … M6 milestone plans
        └── Solutions
            └── 5 learning entries

Idempotent — if a page with the same title already exists under the same
parent, it's updated in place. New children are created.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

import markdown

# ---------------------------------------------------------------------------
# Config — pulled from env or hard-coded for this one-shot run.
# ---------------------------------------------------------------------------
EMAIL = os.environ.get("ATLASSIAN_EMAIL", "jose.diaz@bunshin.io")
TOKEN = os.environ.get("ATLASSIAN_API_TOKEN")
if not TOKEN:
    sys.exit(
        "ATLASSIAN_API_TOKEN env var not set. Generate one at "
        "https://id.atlassian.com/manage-profile/security/api-tokens "
        "and run: ATLASSIAN_API_TOKEN=... python scripts/confluence_migrate.py"
    )

BASE = "https://bunshin.atlassian.net/wiki"
SPACE_KEY = "MFS"
ROOT_PARENT_ID = "10289153"  # "Bunshin Project Master Reference"

REPO = Path(__file__).resolve().parent.parent

# Markdown extensions: fenced code blocks, tables, full quotes, code highlight
MD_EXTS = ["fenced_code", "tables", "toc", "sane_lists", "nl2br"]


def auth_header():
    raw = f"{EMAIL}:{TOKEN}".encode()
    return "Basic " + base64.b64encode(raw).decode()


def http(method, url, body=None):
    data = None
    headers = {
        "Authorization": auth_header(),
        "Accept": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"{method} {url} -> {e.code}: {body_text[:500]}"
        ) from e


def md_to_storage(md_text: str, title: str) -> str:
    """Convert a markdown body into Confluence storage format (XHTML)."""
    html = markdown.markdown(md_text, extensions=MD_EXTS)
    # Light wrapping. Confluence accepts most basic HTML in storage repr.
    # We embed an info macro at the top with the source path for traceability.
    return html


def find_child(parent_id: str, title: str):
    url = (
        f"{BASE}/rest/api/content/{parent_id}/child/page"
        f"?limit=200"
    )
    data = http("GET", url)
    for r in data.get("results", []):
        if r["title"] == title:
            return r
    return None


def find_in_space(title: str):
    """Confluence requires titles unique per space (not just per parent).
    Search the whole space by title to detect collisions before creating."""
    import urllib.parse
    cql = f'space={SPACE_KEY} AND type=page AND title="{title}"'
    url = f"{BASE}/rest/api/content/search?cql={urllib.parse.quote(cql)}&expand=ancestors&limit=5"
    data = http("GET", url)
    results = data.get("results", [])
    return results[0] if results else None


def create_or_update(parent_id: str, title: str, body_html: str) -> str:
    """Create the page under parent_id, or update it if a match exists. Returns id."""
    # First check: page directly under our parent (fast path).
    existing = find_child(parent_id, title)
    # Fallback: check the whole space — Confluence requires title uniqueness
    # per space, so a stale page elsewhere blocks creation. If it's anywhere
    # in this space, treat it as ours and update content (re-parenting it
    # under our intended parent if needed).
    if existing is None:
        space_match = find_in_space(title)
        if space_match is not None:
            ancestor_ids = [a["id"] for a in space_match.get("ancestors", [])]
            if parent_id in ancestor_ids:
                existing = space_match
            else:
                raise RuntimeError(
                    f"Title collision: a page titled '{title}' already exists "
                    f"in space {SPACE_KEY} under a different parent "
                    f"(id={space_match['id']}). Rename the section or that "
                    f"page to proceed."
                )

    if existing:
        # Need current version to update.
        cur = http(
            "GET",
            f"{BASE}/rest/api/content/{existing['id']}?expand=version",
        )
        new_version = cur["version"]["number"] + 1
        payload = {
            "id": existing["id"],
            "type": "page",
            "title": title,
            "space": {"key": SPACE_KEY},
            "version": {"number": new_version},
            "body": {
                "storage": {
                    "value": body_html,
                    "representation": "storage",
                }
            },
        }
        http("PUT", f"{BASE}/rest/api/content/{existing['id']}", payload)
        print(f"  [up] updated {title} ({existing['id']})")
        return existing["id"]

    payload = {
        "type": "page",
        "title": title,
        "space": {"key": SPACE_KEY},
        "ancestors": [{"id": parent_id}],
        "body": {
            "storage": {
                "value": body_html,
                "representation": "storage",
            }
        },
    }
    res = http("POST", f"{BASE}/rest/api/content", payload)
    print(f"  [+] created {title} ({res['id']})")
    return res["id"]


def page_from_md(parent_id: str, title: str, md_path: Path) -> str:
    text = md_path.read_text(encoding="utf-8")
    html = md_to_storage(text, title)
    return create_or_update(parent_id, title, html)


def section_page(parent_id: str, title: str, intro_html: str) -> str:
    return create_or_update(parent_id, title, intro_html)


def main():
    print(f"-> Confluence migration to {BASE}")
    print(f"  space={SPACE_KEY} root_parent={ROOT_PARENT_ID}\n")

    # 1. Project root.
    fwf_id = section_page(
        ROOT_PARENT_ID,
        "Fishing with Friends",
        "<p><strong>Fishing with Friends</strong> — Flutter + Supabase social fishing app for iOS/Android."
        " Documentation hub for the project. Subpages mirror the <code>docs/</code> tree on GitHub.</p>"
        "<ul>"
        "<li><strong>Overview</strong> — README.</li>"
        "<li><strong>Product</strong> — v1 scope contract, store listings.</li>"
        "<li><strong>Architecture</strong> — Supabase setup, edge functions, email templates.</li>"
        "<li><strong>Plans</strong> — Milestone-by-milestone implementation plans (M0 -> M6).</li>"
        "<li><strong>Solutions</strong> — Post-mortem learning entries.</li>"
        "</ul>",
    )

    # 2. Overview.
    print("\n[Overview]")
    page_from_md(fwf_id, "Overview", REPO / "README.md")

    # 3. Product.
    print("\n[Product]")
    product_id = section_page(
        fwf_id,
        "Product",
        "<p>Product-level documentation: scope, store listings, design contracts.</p>",
    )
    page_from_md(
        product_id,
        "v1 Requirements",
        REPO / "docs" / "brainstorms" / "fishing-with-friends-v1-requirements.md",
    )
    page_from_md(
        product_id, "Store Listings", REPO / "docs" / "STORE_LISTINGS.md"
    )

    # 4. Architecture.
    print("\n[Architecture]")
    arch_id = section_page(
        fwf_id,
        "Architecture",
        "<p>Backend + integration setup. Supabase schema, edge functions, transactional email, and the migration history.</p>",
    )
    page_from_md(
        arch_id, "Supabase Setup & Migrations", REPO / "docs" / "SUPABASE_SETUP.md"
    )
    page_from_md(
        arch_id, "Edge Functions", REPO / "docs" / "EDGE_FUNCTIONS.md"
    )
    page_from_md(
        arch_id, "Email Templates", REPO / "docs" / "EMAIL_TEMPLATES.md"
    )

    # 5. Implementation Plans.
    # Note: titled "Implementation Plans" not "Plans" because Confluence
    # requires titles unique per space, and there's already a page titled
    # "Plans" elsewhere in MFS.
    print("\n[Implementation Plans]")
    plans_id = section_page(
        fwf_id,
        "Implementation Plans",
        "<p>Milestone implementation plans. Each plan was the concrete spec we built against; commits trace back to plan-numbered units.</p>",
    )
    plans_dir = REPO / "docs" / "plans"
    plan_titles = {
        "2026-05-01-001-feat-fishing-with-friends-v1-plan.md":
            "M0 — Visual System & Foundation",
        "2026-05-01-002-feat-m1-catch-persistence-plan.md":
            "M1 — Catch Persistence",
        "2026-05-01-003-feat-m2-trips-and-feed-plan.md":
            "M2 — Trips & Feed",
        "2026-05-01-004-feat-m3-tournaments-plan.md":
            "M3 — Tournaments",
        "2026-05-01-005-feat-m4-map-and-stats-plan.md":
            "M4 — Map & Stats",
        "2026-05-01-006-feat-m5-storytelling-plan.md":
            "M5 — Storytelling",
        "2026-05-01-007-feat-m6-offline-conditions-push-plan.md":
            "M6 — Offline + Conditions + Push",
    }
    for fname, title in plan_titles.items():
        page_from_md(plans_id, title, plans_dir / fname)

    # 6. Deployment.
    print("\n[Deployment]")
    deploy_id = section_page(
        fwf_id,
        "Deployment",
        "<p>Production deployment guides — readiness checklist and "
        "platform-by-platform shipping steps for v1.0.0 to the iOS App "
        "Store and Google Play. Code-side the app is ready; the gating "
        "items are the once-per-platform setup work (signing, store "
        "accounts, privacy policy hosting).</p>",
    )
    deploy_dir = REPO / "docs" / "deployment"
    page_from_md(deploy_id, "Deployment Readiness", deploy_dir / "README.md")
    page_from_md(deploy_id, "iOS — App Store deployment", deploy_dir / "ios.md")
    page_from_md(
        deploy_id,
        "iOS deployment checklist",
        deploy_dir / "ios-checklist.md",
    )
    page_from_md(
        deploy_id,
        "iOS capabilities & ASC declarations",
        deploy_dir / "ios-capabilities.md",
    )
    page_from_md(
        deploy_id,
        "iOS — Mac/Xcode walkthrough to TestFlight + App Store",
        deploy_dir / "ios-mac-walkthrough.md",
    )
    page_from_md(
        deploy_id,
        "Android — Google Play deployment",
        deploy_dir / "android.md",
    )

    # 7. Legal.
    print("\n[Legal]")
    legal_id = section_page(
        fwf_id,
        "Legal",
        "<p>Public-facing legal documents — privacy policy and terms. "
        "These get hosted on bunshin.io and referenced from the App Store "
        "/ Google Play listings; the canonical source lives in "
        "<code>docs/legal/</code> and is mirrored here.</p>",
    )
    page_from_md(
        legal_id,
        "Privacy Policy — Fishing with Friends",
        REPO / "docs" / "legal" / "privacy-policy.md",
    )

    # 8. Solutions.
    print("\n[Solutions]")
    sol_id = section_page(
        fwf_id,
        "Solutions",
        "<p>Post-mortem learnings — bugs we hit, root causes we found, and the durable patterns. Each entry documents <em>why</em> a thing is the way it is.</p>",
    )
    sol_dir = REPO / "docs" / "solutions"
    sol_titles = {
        "2026-05-01-catch-persistence.md": "Catch persistence",
        "2026-05-01-conditions-pg-net-async.md":
            "Conditions auto-fill via pg_net (async)",
        "2026-05-01-mpa-display-suppression.md":
            "MPA display suppression on the map",
        "2026-05-01-offline-first-queue.md":
            "Offline-first sync queue",
        "2026-05-01-storytelling-server-detection.md":
            "Storytelling — server-side detection",
    }
    for fname, title in sol_titles.items():
        page_from_md(sol_id, title, sol_dir / fname)

    print("\n[OK] Migration complete.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[ERR] {e}", file=sys.stderr)
        sys.exit(1)
