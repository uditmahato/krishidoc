# ADR-0055: The onboarding deck is one About screen until the flows it would teach are reachable

- **Status:** accepted
- **Decision id:** D-55
- **Date:** 2026-08-02
- **Owners:** Eng (with CPO and UX as reviewers)
- **Supersedes:** the Module 13 scope line in `docs/IMPROVEMENT_PLAN.md` section 5

## Context

The design work for first contact proposed a three-card onboarding deck: what
the app checks, how to take the photo and read the green capture gate, and that
"not sure" is a real answer with a human one tap away.

Two of those three teach flows that do not exist in this build. `/capture` is
reachable only from a debug entry, and the escalation route is a recorded seam
(`docs/seams/clinics.md`) with a no-op handler behind it.

## Decision

Module 13 ships one `/welcome/about` screen carrying three things: coverage,
the not-ready statement, and the offline and on-device facts. It is reached
with `?first=1` from the chooser, and afterwards from Home and from empty
History.

The card teaching the photo and the capture gate is deferred to the module that
routes `/capture` outside `kDebugMode`. The card teaching certainty and
escalation is deferred to the module that ships a real model and a clinic
directory.

No first-run completion flag is stored.

## Rationale

**Why not teach a flow the farmer cannot enter.** It burns the one install
attempt you get, more thoroughly than a coming-soon tile does, because it costs
attention as well as trust. The certainty-and-escalation card additionally
promises a diagnosis and a person, which the module's own constraint forbids and
which the escalation handler cannot honour.

**Why no completion flag.** Storing "this reader has been onboarded" would
guarantee that everyone who installs during this period is never taught the real
flow when it ships, because the flag would already be set. Without it, the
module that ships those flows owns teaching them, and no install cohort is
permanently un-taught. This is the same argument as D-53's single key, applied
to a different question.

**Why one screen rather than zero.** The three facts it carries are all true
today and all currently reach the user nowhere. The offline and on-device
statements in particular are the cheapest trust in the product.

## Consequences

**Home is visibly emptier**, and the pre-decision reading on it goes up rather
than down: roughly 16 English words to 28, measured by the cognitive review's
own method. That is the trade, stated as one. What it buys is that the
useful-choice ratio moves from one live destination in five tap targets to two
in two, and no tap on Home produces a snackbar.

**About is a real route, not a page in a deck**, so the later modules add cards
next to something that already exists rather than replacing a flow.

**Now forbidden.** No onboarding card may teach a flow that is not reachable in
the build it ships in. No first-run completion flag.

**Re-open triggers.** `/capture` leaving `kDebugMode`, or a clinic directory
existing. Either one brings its own card back onto the table, and through the
D-06 gate.

## Dissent

Recorded: one screen carrying three unrelated blocks is weaker teaching than
three focused cards, and a reader who skips it learns nothing. Accepted. The
answer is not to add cards about things that do not work, and About is reachable
from two places afterwards precisely because the first-run reading of it is
expected to be shallow.
