# Seam: Plant clinic referral network ("hospital integration")

**Decision:** D-07, D-43. **Status:** directory ships early (in scope); the referral integration is the seam.

## What exists now / ships early

- `clinics` directory (agrovet, extension office, KVK, JT/JTA) with verified-on dates and staleness rendering (audit M-7); surfaced on every uncertain diagnosis (D-17) as the human escalation path.
- Static, localized emergency information card for pesticide exposure (never triage).

## The reserved integration

Referral API: on escalation, a case file (diagnosis snapshot, images under consent, advice history from the D-43 ledger) shareable to a clinic via a scoped, expiring link. Schema reserved (`referrals`), endpoints unbuilt.

## When it opens

Trigger: a signed clinic/extension partner. Constraints already fixed: consent-gated sharing, audit-logged access, expiring links, and no human-health data of any kind.
