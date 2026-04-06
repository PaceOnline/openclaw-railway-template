# PaceOnline OpenClaw Website Maintenance

OpenClaw maintains five public websites from Gmail content requests sent to `support@paceonline.co.za`:

| Site | Sender Domain | Website | Repo |
|---|---|---|---|
| BBR | `@yetsagala.co.za` | `https://bushbuckridge.gov.za` | `PaceOnline/bbr` |
| HGDM | `@harrygwaladm.gov.za` | `https://www.harrygwaladm.gov.za` | `PaceOnline/Harry-Gwala-Municipality` |
| iLembe | `@enterpriseilembe.co.za` | `https://www.enterpriseilembe.co.za` | `PaceOnline/ilembe` |
| iSimangaliso | `@isimangaliso.com` | `https://www.isimangaliso.com` | `PaceOnline/iSimangaliso` |
| HGDA | `@hgda.co.za` | `https://www.hgda.co.za` | `PaceOnline/Harry-Gwala-Agency` |

## Non-Negotiable Rules

1. Process at most one email at a time, end-to-end.
2. Do not spend output tokens listing a batch and stopping. Make the first shell call immediately.
3. Do not reply to skipped emails.
4. Replies must use website URLs, never raw R2 URLs.
5. Check duplicates before uploading or editing.
6. Add `Tickets/Handled` only after a successful publish or a confirmed duplicate.
7. Use the live custom domains for verification, not stale preview hosts.

## Required Workflow

For cron-triggered runs, start with `scripts/run_email_content_check.sh`. It will:

- return `status=no_messages` when there is nothing to do
- return `status=skipped_no_publishable_attachments` after labeling signature-only emails handled
- return `status=ready` with the selected message and `processResultPath` for the one email you should finish

For every candidate message:

1. Run `scripts/process_email.sh <message_id>`.
2. Read the JSON it prints. That script already:
   - reads message metadata
   - resolves the site from the sender domain
   - filters out signature artifacts such as `image001.png`
   - downloads publishable attachments
   - uploads them to the correct R2 bucket
   - clones or updates the correct repo
3. Read the email subject/body and decide the content type.
4. Run `python3 scripts/site_lookup.py --sender "<sender>" --content-type "<type>" --pretty`.
5. Open the repo-local guidance files returned by the lookup or listed in `repoGuidanceCandidates`.
6. Check the target file and live route for duplicates before editing.
7. If the content is already live, label the email and stop with no reply.
8. If the content is new, edit only the correct repo and correct target file.
9. Commit and push with `scripts/git_push.sh`.
10. Verify the live route in a headed browser.
11. Reply in the original thread with the website URL where the content now lives.
12. Add `Tickets/Handled`.

## Site-Specific Guardrails

- HGDA and HGDM are different organizations.
- Never publish `@hgda.co.za` content into `PaceOnline/Harry-Gwala-Municipality`.
- Never send `harrygwaladm.gov.za` URLs in replies for HGDA work.
- HGDA uses strict UIkit templates. Read `CONTENT-MANAGEMENT.md` in the HGDA repo before editing.
- iSimangaliso messages mentioning `CSD`, `Central Supplier Database`, `compliance certificate`, or `tax clearance` are internal and must not be published.
- iLembe usually publishes by editing `html5/assets/data/download-overrides.json`, not page HTML.
- HGDM verifies on `https://www.harrygwaladm.gov.za`, not `hgdm-production.up.railway.app`.
- BBR is a WordPress/Elementor mirror, not the old Joomla/UIkit site.
