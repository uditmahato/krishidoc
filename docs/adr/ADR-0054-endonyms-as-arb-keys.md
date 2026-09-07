# ADR-0054: Endonyms are non-translatable ARB keys, not Dart constants

- **Status:** accepted
- **Decision id:** D-54
- **Date:** 2026-08-02
- **Owners:** Eng (with the D-06 language gate as reviewer)

## Context

The language chooser renders `नेपाली`, `हिन्दी` and `English` simultaneously, in
every locale. They are not translations of one another: each must appear in its
own script whatever language the app is currently showing.

Before this module the same three strings were hardcoded in
`home_screen.dart`'s language menu as Dart literals.

## Decision

`languageNameNe`, `languageNameHi` and `languageNameEn` are ARB keys carrying
byte-identical values in `app_en.arb`, `app_ne.arb` and `app_hi.arb`, each with
an `@` description reading "Do not translate. This is an endonym and must
appear in its own script in every locale."

They are rendered with `KdType.forLocale` for their own locale, never the
ambient theme. Both surfaces that show them, the chooser and the Home language
menu, read from the single `kLanguageChoices` list.

## Rationale

**Why not Dart constants**, which is what they were. Moving user-visible text
into Dart creates a second string surface outside the D-06 review inventory,
which is defined as the ne and hi ARB strings. This repo has been burned by
exactly that twice already, with `'Prepared $bytes bytes'` and
`'Camera preview (debug)'` reaching a screen without ever passing a reviewer.
The endonyms carry no translation units, because they are not translated, but
they do carry a spelling question, and the spelling question belongs where the
reviewer will see it.

**Why one list rather than two.** The menu and the chooser previously could not
disagree only because nobody had edited one of them. Reading both from
`kLanguageChoices` makes the agreement structural.

**Why `KdType.forLocale` rather than the theme.** On the chooser no language has
been chosen, so the app themes with English metrics. Flutter's `tall2021`
typography is byte-identical to `englishLike2021`, so the Devanagari endonyms
would paint at Latin line height with letter spacing applied, collapsing the
shirorekha on the one screen whose premise is that each option is readable in
its own script.

## Consequences

**The D-35 translation flow must respect the non-translatable marker.** A
Weblate round trip that helpfully translates `languageNameNe` into Hindi breaks
the chooser's entire premise.

**A test asserts each endonym appears exactly once** with the app in `en`, `ne`
and `hi`. Two hits would mean a locale had acquired a translated copy.

**Open question for the gate, not a decision here:** whether `हिन्दी` or `हिंदी`
is the right spelling. The value shipped matches what `home_screen.dart` already
used, and the two must not diverge; the `@` description carries the question.

## Dissent

The obvious objection is that three strings that are identical in all three
files are duplication, and that a Dart constant would express "this is one
value" more honestly than three copies. Recorded and rejected: the duplication
is real but it is the price of keeping every user-visible string inside one
reviewable inventory, and the alternative failure mode, a string nobody
reviewed reaching a farmer, has already happened here twice.
