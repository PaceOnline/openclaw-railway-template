#!/usr/bin/env python3
"""Resolve PaceOnline site and publish target details from sender + content type."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SITES_PATH = ROOT / "sites.json"

ALIASES = {
    "tender": "tender",
    "rfp": "tender",
    "bid": "tender",
    "proposal": "tender",
    "quotation": "rfq",
    "quote": "rfq",
    "rfq": "rfq",
    "award": "award",
    "awarded": "award",
    "award_notice": "award",
    "notice_of_award": "award",
    "intention_to_award": "intention_to_award",
    "intention-to-award": "intention_to_award",
    "notice_of_intention_to_award": "intention_to_award",
    "register": "register",
    "bid_register": "register",
    "closing_register": "register",
    "contract_register": "register",
    "supplier": "supplier",
    "supplier_registration": "supplier",
    "vacancy": "vacancy",
    "job": "vacancy",
    "career": "vacancy",
    "bursary": "bursary",
    "notice": "notice",
    "public_notice": "notice",
    "news": "news",
    "newsletter": "newsletter",
    "media_statement": "media_statement",
    "statement": "media_statement",
    "event": "news",
    "document": "document",
    "report": "report",
    "budget": "budget",
    "policy": "policy",
    "prospectus": "prospectus",
    "travel_guide": "travel_guide",
    "permit": "permit",
    "maps": "maps",
    "map": "maps",
    "gef": "gef_project",
    "gef_project": "gef_project",
}

SITE_RULES = {
    "bbr": {
        "repoRoot": "html",
        "preferredReplyOrigin": "https://bushbuckridge.gov.za",
        "verificationUrl": "https://bushbuckridge.gov.za",
        "previewUrl": None,
        "previewStatus": "use_live_site",
        "guidancePaths": [
            "CONTENT-MANAGEMENT.md",
        ],
        "fallbackTarget": {
            "file": "html/documents-center/index.html",
            "route": "/documents-center/",
            "replyUrl": "https://bushbuckridge.gov.za/documents-center/",
        },
        "contentTargets": {
            "tender": {
                "file": "html/supply-chain/index.html",
                "route": "/supply-chain/",
                "replyUrl": "https://bushbuckridge.gov.za/supply-chain/",
            },
            "rfq": {
                "file": "html/supply-chain/index.html",
                "route": "/supply-chain/",
                "replyUrl": "https://bushbuckridge.gov.za/supply-chain/",
            },
            "award": {
                "file": "html/supply-chain/index.html",
                "route": "/supply-chain/",
                "replyUrl": "https://bushbuckridge.gov.za/supply-chain/",
            },
            "register": {
                "file": "html/supply-chain/index.html",
                "route": "/supply-chain/",
                "replyUrl": "https://bushbuckridge.gov.za/supply-chain/",
            },
            "vacancy": {
                "file": "html/careers/index.html",
                "route": "/careers/",
                "replyUrl": "https://bushbuckridge.gov.za/careers/",
            },
            "bursary": {
                "file": "html/careers/index.html",
                "route": "/careers/",
                "replyUrl": "https://bushbuckridge.gov.za/careers/",
            },
            "news": {
                "file": "html/news/index.html",
                "route": "/news/",
                "replyUrl": "https://bushbuckridge.gov.za/news/",
            },
            "notice": {
                "file": "html/news/index.html",
                "route": "/news/",
                "replyUrl": "https://bushbuckridge.gov.za/news/",
            },
            "document": {
                "file": "html/documents-center/index.html",
                "route": "/documents-center/",
                "replyUrl": "https://bushbuckridge.gov.za/documents-center/",
            },
            "report": {
                "file": "html/documents-center/index.html",
                "route": "/documents-center/",
                "replyUrl": "https://bushbuckridge.gov.za/documents-center/",
            },
            "budget": {
                "file": "html/documents-center/index.html",
                "route": "/documents-center/",
                "replyUrl": "https://bushbuckridge.gov.za/documents-center/",
            },
            "policy": {
                "file": "html/documents-center/index.html",
                "route": "/documents-center/",
                "replyUrl": "https://bushbuckridge.gov.za/documents-center/",
            },
        },
        "notes": [
            "Current repo is a mirrored WordPress/Elementor site.",
            "Do not use the old Joomla/UIkit instructions.",
        ],
    },
    "hgdm": {
        "repoRoot": "html",
        "preferredReplyOrigin": "https://www.harrygwaladm.gov.za",
        "verificationUrl": "https://www.harrygwaladm.gov.za",
        "previewUrl": "https://hgdm-production.up.railway.app",
        "previewStatus": "joomla_reference_only",
        "guidancePaths": [
            "html/CONTENT-MANAGEMENT.md",
            "html/WEBSITE-MAINTENANCE.md",
        ],
        "fallbackTarget": {
            "file": "html/documents.html",
            "route": "/documents.html",
            "replyUrl": "https://www.harrygwaladm.gov.za/documents.html",
        },
        "contentTargets": {
            "tender": {
                "file": "html/supply-chain.html",
                "route": "/supply-chain.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/supply-chain.html",
            },
            "rfq": {
                "file": "html/supply-chain.html",
                "route": "/supply-chain.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/supply-chain.html",
            },
            "award": {
                "file": "html/supply-chain.html",
                "route": "/supply-chain.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/supply-chain.html",
            },
            "register": {
                "file": "html/supply-chain.html",
                "route": "/supply-chain.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/supply-chain.html",
            },
            "vacancy": {
                "file": "html/jobs-center.html",
                "route": "/jobs-center.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/jobs-center.html",
            },
            "notice": {
                "file": "html/public-notices.html",
                "route": "/public-notices.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/public-notices.html",
            },
            "news": {
                "file": "html/news.html",
                "route": "/news.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/news.html",
            },
            "newsletter": {
                "file": "html/news/newsletters.html",
                "route": "/news/newsletters.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/news/newsletters.html",
            },
            "media_statement": {
                "file": "html/news/media-statements.html",
                "route": "/news/media-statements.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/news/media-statements.html",
            },
            "document": {
                "file": "html/documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/documents.html",
            },
            "report": {
                "file": "html/documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/documents.html",
            },
            "budget": {
                "file": "html/documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/documents.html",
            },
            "policy": {
                "file": "html/documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.harrygwaladm.gov.za/documents.html",
            },
        },
        "notes": [
            "Verify on the live custom domain, not the Railway preview alias.",
        ],
    },
    "ilembe": {
        "repoRoot": "html5",
        "preferredReplyOrigin": "https://www.enterpriseilembe.co.za",
        "verificationUrl": "https://www.enterpriseilembe.co.za",
        "previewUrl": "https://ilembe-production.up.railway.app",
        "previewStatus": "valid_preview",
        "guidancePaths": [
            "CONTENT-MANAGEMENT.md",
        ],
        "fallbackTarget": {
            "file": "html5/assets/data/download-overrides.json",
            "route": "/downloads.html",
            "replyUrl": "https://www.enterpriseilembe.co.za/downloads.html",
        },
        "contentTargets": {
            "tender": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/scm-tenders.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/scm-tenders.html",
            },
            "rfq": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/scm-rfqs.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/scm-rfqs.html",
            },
            "register": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/scm-contract-register.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/scm-contract-register.html",
            },
            "supplier": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/scm-supplier-registration.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/scm-supplier-registration.html",
            },
            "vacancy": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/vacancies.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/vacancies.html",
            },
            "news": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/news-media.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/news-media.html",
            },
            "newsletter": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/news-media.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/news-media.html",
            },
            "document": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/documents.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/documents.html",
            },
            "report": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/documents.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/documents.html",
            },
            "budget": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/documents-annual-budgets.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/documents-annual-budgets.html",
            },
            "policy": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/documents.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/documents.html",
            },
            "prospectus": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/invest.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/invest.html",
            },
            "travel_guide": {
                "file": "html5/assets/data/download-overrides.json",
                "route": "/destination.html",
                "replyUrl": "https://www.enterpriseilembe.co.za/destination.html",
            },
        },
        "notes": [
            "Prefer the www hostname for replies and verification.",
            "Most publishing is data-only through download-overrides.json.",
        ],
    },
    "isimangaliso": {
        "repoRoot": "site",
        "preferredReplyOrigin": "https://www.isimangaliso.com",
        "verificationUrl": "https://www.isimangaliso.com",
        "previewUrl": "https://isimangaliso-production.up.railway.app",
        "previewStatus": "detached_application",
        "guidancePaths": [
            "site/AGENTS.md",
            "site/MAINTENANCE.md",
        ],
        "fallbackTarget": {
            "file": "site/__fragments/resources-documents.html",
            "route": "/documents/",
            "replyUrl": "https://www.isimangaliso.com/documents/",
        },
        "contentTargets": {
            "tender": {
                "file": "site/__fragments/resources-tenders.html",
                "route": "/tenders/",
                "replyUrl": "https://www.isimangaliso.com/tenders/",
            },
            "rfq": {
                "file": "site/__fragments/resources-tenders.html",
                "route": "/tenders/",
                "replyUrl": "https://www.isimangaliso.com/tenders/",
            },
            "award": {
                "file": "site/__fragments/resources-tenders.html",
                "route": "/tenders/",
                "replyUrl": "https://www.isimangaliso.com/tenders/",
            },
            "document": {
                "file": "site/__fragments/resources-documents.html",
                "route": "/documents/",
                "replyUrl": "https://www.isimangaliso.com/documents/",
            },
            "report": {
                "file": "site/__fragments/resources-documents.html",
                "route": "/documents/",
                "replyUrl": "https://www.isimangaliso.com/documents/",
            },
            "policy": {
                "file": "site/__fragments/resources-documents.html",
                "route": "/documents/",
                "replyUrl": "https://www.isimangaliso.com/documents/",
            },
            "vacancy": {
                "file": "site/vacancies/index.html",
                "route": "/vacancies/",
                "replyUrl": "https://www.isimangaliso.com/vacancies/",
            },
            "bursary": {
                "file": "site/bursary/index.html",
                "route": "/bursary/",
                "replyUrl": "https://www.isimangaliso.com/bursary/",
            },
            "permit": {
                "file": "site/permits/index.html",
                "route": "/permits/",
                "replyUrl": "https://www.isimangaliso.com/permits/",
            },
            "maps": {
                "file": "site/download-maps/index.html",
                "route": "/download-maps/",
                "replyUrl": "https://www.isimangaliso.com/download-maps/",
            },
            "gef_project": {
                "file": "site/__fragments/resources-gef-project.html",
                "route": "/gef-project/",
                "replyUrl": "https://www.isimangaliso.com/gef-project/",
            },
        },
        "skipKeywords": [
            "csd",
            "central supplier database",
            "compliance certificate",
            "tax clearance",
        ],
        "notes": [
            "Fragment pages edit only the fragment file.",
            "Inline pages must update both the route file and the template mirror.",
            "The Railway preview alias is currently detached.",
        ],
    },
    "hgda": {
        "repoRoot": ".",
        "preferredReplyOrigin": "https://www.hgda.co.za",
        "verificationUrl": "https://www.hgda.co.za",
        "previewUrl": "https://harry-gwala-agency-production.up.railway.app",
        "previewStatus": "valid_preview",
        "guidancePaths": [
            "CONTENT-MANAGEMENT.md",
        ],
        "fallbackTarget": {
            "file": "documents.html",
            "route": "/documents.html",
            "replyUrl": "https://www.hgda.co.za/documents.html",
        },
        "contentTargets": {
            "rfq": {
                "file": "quotations.html",
                "route": "/quotations.html",
                "replyUrl": "https://www.hgda.co.za/quotations.html",
            },
            "tender": {
                "file": "tenders.html",
                "route": "/tenders.html",
                "replyUrl": "https://www.hgda.co.za/tenders.html",
            },
            "intention_to_award": {
                "file": "intention-to-award.html",
                "route": "/intention-to-award.html",
                "replyUrl": "https://www.hgda.co.za/intention-to-award.html",
            },
            "award": {
                "file": "awarded-bids.html",
                "route": "/awarded-bids.html",
                "replyUrl": "https://www.hgda.co.za/awarded-bids.html",
            },
            "register": {
                "file": "bid-registers.html",
                "route": "/bid-registers.html",
                "replyUrl": "https://www.hgda.co.za/bid-registers.html",
            },
            "vacancy": {
                "file": "jobs-portal.html",
                "route": "/jobs-portal.html",
                "replyUrl": "https://www.hgda.co.za/jobs-portal.html",
            },
            "document": {
                "file": "documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.hgda.co.za/documents.html",
            },
            "report": {
                "file": "documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.hgda.co.za/documents.html",
            },
            "budget": {
                "file": "documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.hgda.co.za/documents.html",
            },
            "policy": {
                "file": "documents.html",
                "route": "/documents.html",
                "replyUrl": "https://www.hgda.co.za/documents.html",
            },
        },
        "notes": [
            "Never publish HGDA content into the HGDM repo or use harrygwaladm.gov.za reply URLs.",
            "Read CONTENT-MANAGEMENT.md before editing because HGDA uses exact UIkit grid templates.",
        ],
    },
}


def extract_domain(sender: str) -> str:
    sender = sender.strip()
    match = re.search(r"<([^>]+)>", sender)
    email = match.group(1) if match else sender
    email = email.strip().lower()
    if "@" not in email:
        raise ValueError(f"Could not extract an email domain from: {sender}")
    return email.rsplit("@", 1)[1]


def normalize_content_type(value: str) -> str:
    key = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    if not key:
        raise ValueError("Content type cannot be empty.")
    return ALIASES.get(key, key)


def load_sites() -> list[dict]:
    return json.loads(SITES_PATH.read_text(encoding="utf-8"))


def find_site_by_domain(sites: list[dict], domain: str) -> dict:
    for site in sites:
        if site["emailDomain"].lstrip("@") == domain.lstrip("@"):
            return site
    raise ValueError(f"No site found for sender domain: {domain}")


def resolve_target(site_id: str, content_type: str) -> dict:
    rules = SITE_RULES[site_id]
    return rules["contentTargets"].get(content_type) or rules["fallbackTarget"]


def build_result(site: dict, sender: str, sender_domain: str, content_type: str, target: dict) -> dict:
    rules = SITE_RULES[site["id"]]
    result = {
        "sender": sender,
        "senderDomain": sender_domain,
        "siteId": site["id"],
        "siteName": site["name"],
        "contentType": content_type,
        "website": f"https://{site['domain']}",
        "preferredReplyOrigin": rules["preferredReplyOrigin"],
        "verificationUrl": rules["verificationUrl"],
        "previewUrl": rules["previewUrl"],
        "previewStatus": rules["previewStatus"],
        "repoUrl": f"https://github.com/{site['gitRepo']}.git",
        "repoSlug": site["gitRepo"],
        "repoDir": site["repoDir"],
        "repoRoot": rules["repoRoot"],
        "r2Bucket": site["r2Bucket"],
        "r2PublicBase": site["r2PublicUrl"],
        "guidancePaths": rules["guidancePaths"],
        "targetFile": target["file"],
        "targetRoute": target["route"],
        "replyUrl": target["replyUrl"],
        "duplicateChecks": [
            "attachment filename",
            "content title",
            target["file"],
            target["route"],
        ],
        "notes": rules.get("notes", []),
    }
    if rules.get("skipKeywords"):
        result["skipKeywords"] = rules["skipKeywords"]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sender", help="Full sender email or From header value")
    parser.add_argument("--content-type", help="Tender, RFQ, report, vacancy, etc.")
    parser.add_argument("--list-sites", action="store_true", help="List known sites")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    args = parser.parse_args()

    sites = load_sites()

    if args.list_sites:
        payload = [
            {
                "id": site["id"],
                "name": site["name"],
                "emailDomain": site["emailDomain"],
                "website": f"https://{site['domain']}",
                "repo": site["gitRepo"],
            }
            for site in sites
        ]
        print(json.dumps(payload, indent=2 if args.pretty else None))
        return 0

    if not args.sender or not args.content_type:
        parser.error("--sender and --content-type are required unless --list-sites is used.")

    sender_domain = extract_domain(args.sender)
    content_type = normalize_content_type(args.content_type)
    site = find_site_by_domain(sites, sender_domain)
    target = resolve_target(site["id"], content_type)
    result = build_result(site, args.sender, sender_domain, content_type, target)
    print(json.dumps(result, indent=2 if args.pretty else None))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
