# ADR-0053: First run asks for the language, and the device locale is never a hint

- **Status:** accepted
- **Decision id:** D-53
- **Date:** 2026-08-02
- **Owners:** Eng (with UX and the D-06 language gate as reviewers)

## Context

The app has always opened in whatever language `Localizations` resolved from
the handset, with a language control in the AppBar as the only way out. For a
reader who does not read English that control is 887dp from the thumb and is
labelled with a glyph, which means the first screen of the app can be
unreadable and the escape from it can be unfindable at the same time.

Nothing in the app records whether a reader has ever been asked. The single
existing `SettingsKeys.selectedLanguage` key is written only when someone finds
the AppBar menu, so a null value means "never chose", which is exactly the
question a first-run gate needs answered.

## Decision

The chooser is gated on that single existing key.
`AppLanguage.fromCode(stored) == null` routes to `/welcome/language`; anything
else routes to `/`. No second flag is added.

The three options are ordered `ne, hi, en` on every device and every install,
with no preselection, no reordering by device locale, no highlighted
recommendation, and no fourth "use my phone's language" option. The order is
pinned in `kLanguageChoices` and asserted by test.

The endonym on each option is rendered with `KdType.forLocale` for that
option's own locale, never the ambient theme.

## Rationale

**Why no second key.** Two keys can disagree, and the disagreement would be
invisible until a farmer hit it. One nullable read answers the only question
this module asks. A garbage stored value, say a `'bn'` written by some future
build, returns null from the existing parser and degrades to the chooser for
free rather than through a branch someone had to remember to write.

**Why the device locale is not a hint.** Handsets in this market ship
configured in English by the shop, so the device locale is evidence about a
shopkeeper and not about a reader. Reordering by it would destroy the position
memory that is a non-reader's most useful cue, would make goldens and support
screenshots device dependent, and would put the wrong option first exactly when
the hint is wrong.

**Why no skip.** A skip on a three-option screen saves one tap for a reader who
can read the skip, and costs the whole app to one who cannot.

**Why the write is awaited.** The screen navigates on completion, so the reader
cannot reach the next screen in a state where the language is on screen but not
on disk. A storage failure is swallowed rather than surfaced: the in-memory
locale is already applied, and the accepted consequence is that the chooser
reappears on the next cold start rather than that the farmer is trapped behind
an error on the first screen.

**Alternatives considered.**

- *Reorder by device locale.* Rejected above.
- *A fourth "use my phone's language" option.* Rejected: it is the same wrong
  evidence wearing a label, and it adds a fourth target to the one screen where
  a mis-tap costs the most.
- *A tri-script heading above the options.* Rejected: five to six lines at text
  scale 2.0, pushing two of three targets off the floor device, and saying
  nothing the glyph and three endonyms do not.

## Consequences

**Existing installs that never opened the language menu see the chooser once**
on their next launch. That is correct: they were never asked.

**Every new user-visible surface before the choice must style itself**, because
the ambient theme is Latin until the choice is made.

**Now forbidden.** No second onboarding-completion flag. No device-locale
influence on the order or the preselection. No network involvement in the
choice.

**Re-open triggers.** A field test showing readers failing at the chooser, or a
fourth launch language, which changes the ordering argument.

## Dissent

Recorded: showing the chooser to existing installs is a behaviour change for
users who were happy, and some of them will have been reading the app in a
language the handset happened to pick correctly. Accepted, because the cost is
one tap and the alternative is that a reader who was never asked stays unasked
forever.
