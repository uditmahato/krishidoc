# Module 14 — The Handbook Shell

**Adjudicated specification. This supersedes all four proposals.** Where a skeptic landed a fatal blow, the proposal loses and I say so.

---

## 0. Verdicts on the four proposals

| Key | Verdict | Fatal blow that decided it |
|---|---|---|
| `content-schema` | **Loses on execution, wins on shape.** | Its own worked entry cannot build (NOT NULL `reviewedBy` set to null, no `lifecycle` column, dangling confusion ids), it writes the dose into prose in three languages against its own rule 16, it needs ~29 pictograms that need a designer, its one MATCH query has an FTS5 syntax error and its bm25 ranking is sign-inverted, and every taxonomy is a Dart enum, which makes a new symptom tag an app release. The facts/text split, two databases, row-per-language, and the build-time validator survive. |
| `browse-by-sight` | **Loses.** | The picture axis terminates one screen before the decision: every row in a `spots` result set renders the same `spots` glyph, so the leading slot carries zero discriminating information. Two of eight glyphs violate its own 6dp feature floor or draw a colour-meaning mark with no colour. Its coverage table omits spider mite from the launch set it was checking, and its own seeder hard-fails an entry with no mark. It ships engineer-written mancozeb dosing flagged `agronomistReviewed`. The `KdAppBar` title clamp, JSON-pack-plus-seeder, FTS DDL in `.drift`, "absence is not a negative", and the language visibility rule survive. |
| `components` | **Loses.** | It does not build the module: no schema, no worked entry, no browse. `KdListRow` collapses its title column to 45dp (11dp inside a state card) at 320×640 scale 2.0 in Nepali, and all four of its own matrix assertions pass on that failure. Its certainty stack needs a model that does not exist and re-opens P0-5. `KdStateVisual`, `KdActionRow` stacked vertically, the `errorContainer` token promotion, inverting the `findsNothing` assertion, `OutOfScopeCause`, and the generic touch-target semantics walk survive. |
| `worked-entry-and-ops` | **Loses.** | Its single deliverable cannot pass its own `kb_lint`, which is a CI gate, so the repo goes red on commit. Browse-by-see has no picture binding at all. Its `shipChemicals` predicate depends on a CIB&RC/PQPMC feed its own risk 10 says is not obtainable. Every degraded state terminates in a clinic list that does not exist. It adds `GET /v1/kb/revocations`, unfreezing the backend this module exists to keep frozen. Tier A/Tier B, the two horizons, degrade-never-blank, computed `review_status`, and the role-split R1 economics survive. |

---

## 1. What Module 14 IS

Module 14 is an offline crop handbook: a shipped JSON content pack, seeded into its own SQLite database with a Devanagari trigram search index, that a farmer browses by crop or by what she can see, plus the seven design-system components that render it and a build-time validator that makes unreviewed or unsafe content physically unshippable.

It is the schema and the shell only: it contains exactly one worked entry, written by an engineer, marked draft, and structurally refused by the release build until a credentialed agronomist signs it.

---

## 2. The ordered build list

Every item names its file, its structure, and the test that proves it. Items are ordered so each is independently verifiable when it lands.

### Item 0 — Photo unblock (not code, blocking)

Module 14 does not close until **two JPEG files** exist for the worked entry: a tomato leaf showing a brown wet-edged patch, and the underside of that same leaf showing white sporulation. Everything below ships and degrades honestly without them (`KdEntryPhoto` renders its defined pending state, and symptom browse renders `KdEmptyState`), but with them absent the module's headline feature is an empty grid. Owner: content workstream. This is named, not papered over.

### Item 1 — `tools/kb`, the authoring toolchain

```
tools/kb/pubspec.yaml                 # pure Dart; deps: yaml, crypto, image, path, core_domain
tools/kb/bin/kb.dart                  # new | lint | build | hash
tools/kb/lib/src/authoring_model.dart # YAML -> Dart, one parse site
tools/kb/lib/src/validator.dart       # section 7 rules
tools/kb/lib/src/pack_builder.dart    # -> app/assets/kb/kb-<version>.json
tools/kb/lib/src/photo_pipeline.dart  # JPEG only, package:image
tools/kb/test/validator_test.dart
tools/kb/test/pack_builder_test.dart
content/kb/SCHEMA.md
content/kb/vocab/{symptom_tag,plant_part,action_kind,harm}.yaml
content/kb/reviewers.yaml
content/kb/entries/tomato.late_blight/{common,text.en,text.ne,text.hi,signoff}.yaml
```

Root `pubspec.yaml` gains `tools/kb` to the workspace list.

**Two gates, deliberately separated.** This is the fix to the flaw that killed `worked-entry-and-ops`:
- `kb lint` is **repo health**. It runs in CI on every PR touching `content/`. A `draft` entry passes it. The committed worked entry passes it.
- `kb build --channel release` is the **ship gate**. It refuses `review_status: draft`, refuses `licence: pending`, refuses any chemical row, refuses a single-jurisdiction entry. The committed worked entry fails it, by design.

**Photo pipeline is JPEG, never WebP.** `package:image` has no WebP encoder and no HEIC decoder; requiring `cwebp` would be a native toolchain dependency against D-09's language cap. Long edge 800px, quality 82, EXIF cleared, sha256 recorded. 800px because the entry hero renders at 288dp maximum on the reference screen.

**Test:** `validator_test.dart` asserts each of the 22 rules in section 7 rejects a crafted violation and accepts the worked entry. `pack_builder_test.dart` asserts `kb build --channel draft` on the worked entry exits 0 and `--channel release` on the identical input **exits non-zero**. That second assertion is the module's most important test: it proves the gate is not decorative.

### Item 2 — `core_domain` KB model and the fold function

```
packages/core_domain/lib/src/kb/kb_entry.dart      # KbEntry, KbSymptom, KbAction, KbDont, KbConfusion, KbPhoto
packages/core_domain/lib/src/kb/kb_text.dart       # KbText { text, requested, resolved, isFallback }
packages/core_domain/lib/src/kb/kb_enums.dart      # RiskClass, PhotoRole, KbLifecycle, CertaintyBand
packages/core_domain/lib/src/kb/kb_repository.dart # the port
packages/core_domain/lib/src/kb/kb_query.dart      # BrowseQuery, SearchHit, FacetCount
packages/core_domain/lib/src/kb/search_fold.dart   # foldForSearch(String) -> String
packages/core_domain/lib/src/kb/kb_clock.dart      # trustedNow
packages/core_domain/lib/src/stores.dart           # EDIT: SettingsKeys.kbPackVersion
```

**The taxonomy rule that decides everything here:** an enum in Dart is *app behaviour*; a key in a vocab table is *content taxonomy*. `RiskClass` (a sort key that makes IPM-first structural per D-25), `PhotoRole`, and `KbLifecycle` are Dart enums. Symptom tags, plant parts, action kinds and harm codes are `TEXT` keys validated against `content/kb/vocab/*.yaml` and rendered from KB-supplied label rows. This is `content-schema`'s own argument against a column-per-language, applied to the thing it exempted: a new symptom tag must be an INSERT, not an `ALTER TABLE` plus codegen plus an app release.

**`foldForSearch` is deliberately small.** NFC, strip U+200C/U+200D, Devanagari digits `०..९` to `0..9`, lowercase ASCII, collapse whitespace. That is all. `content-schema`'s 35-consonant transliterator plus eight-stage sloppy folding is **cut**: its own risk register concedes it is one person's guess whose failure mode (zero results) is indistinguishable from a genuine miss, and its aspirate/vowel-length collapse would make `फल` and `पल` collide, which its own uniqueness rule then forbids. Romanization is carried by **synonym rows an agronomist writes** (`jhulsa`, `julsa`, `dadhuwa`), which is thirty seconds per entry, testable, and correct by construction.

**Test:** `search_fold_test.dart` — NFC idempotence, ZWNJ stripped, `पातहरूमा` and `पात` both fold to forms where the second is a substring of the first, Devanagari digits Latinised, fold is idempotent (`fold(fold(x)) == fold(x)`). `kb_clock_test.dart` — four cases: normal, epoch-1970 clock, year-2099 clock, exactly at pack build time.

### Item 3 — `core_data` KB database, seeder, repository

```
packages/core_data/lib/src/kb/kb_tables.dart        # the 18 tables
packages/core_data/lib/src/kb/kb.drift              # FTS5 DDL only
packages/core_data/lib/src/kb/kb_database.dart
packages/core_data/lib/src/kb/kb_seeder.dart
packages/core_data/lib/src/kb/drift_kb_repository.dart
packages/core_data/test/kb_seeder_test.dart
packages/core_data/test/kb_repository_test.dart
packages/core_data/test/kb_search_test.dart
```

**Second database file, JSON pack, on-device seed.** Three conflicting proposals; I pick one. The pack is `assets/kb/kb-<version>.json`, seeded by `KbSeeder` into `kb.sqlite`, a file separate from `app.sqlite`. Separate file because content is disposable and user data is not, and a content reset inside one file is a transaction over the farmer's history. JSON rather than a prebuilt `.db` because a prebuilt database pins the SQLite page format to the drift generated schema, cannot be opened in place from an Android asset (forcing a copy that doubles the install footprint), and would put this repo's first-ever `OpenMode.readOnly` drift path on the critical path unverified.

**FTS5 DDL lives in `kb.drift` and is `include:`d on `@DriftDatabase`**, so `onCreate` and any future `onUpgrade` create the identical virtual table. Declaring it only in a `customStatement` inside `onUpgrade` silently diverges fresh installs from upgrades.

**No sync triggers.** The pack is written exactly once per seed, inside one transaction, then `INSERT INTO kb_fts(kb_fts) VALUES('rebuild');`. Three triggers that can each be got wrong are replaced by one rebuild that cannot.

**Test:** `kb_seeder_test.dart` — seeding is idempotent by `pack_version`; a changed `pack_version` wipes and reseeds; a malformed pack throws a typed `KbPackException` rather than a raw `FormatException`; the seeder refuses an entry with no `hero_photo_id`. `kb_search_test.dart` — a Devanagari substring query matches (skipped with a stated reason below SQLite 3.34, **and CI must not skip**, asserted by a test that fails if the CI environment variable is set and the skip fires); a synonym row matches; ranking puts a `name` hit above a `body` hit; a two-character query falls back to the prefix scan and returns a row.

### Item 4 — `AppDatabase` v1 → v2

```
packages/core_data/drift_schemas/drift_schema_v1.json   # dumped BEFORE editing
packages/core_data/drift_schemas/drift_schema_v2.json
packages/core_data/lib/src/database/app_database.dart   # EDIT
packages/core_data/test/migration_test.dart
```

`packages/core_data/drift_schemas/` does not exist today. Run `dart run drift_dev schema dump` for v1 **before** touching `app_database.dart`. Taking the dump afterwards captures v2 and makes the migration test vacuous, which is the same defect class as a regression guard never validated against the broken code.

**Test:** `migration_test.dart` opens a real v1 database, writes a `DiagnosisRow`, migrates to v2, and asserts the row survives with nulls in the three new columns. Per the recorded lesson, this test is run once against `schemaVersion = 1` and **watched to fail** before it is trusted.

### Item 5 — design system components

```
packages/design_system/lib/src/components/kd_state_card.dart
packages/design_system/lib/src/components/kd_empty_state.dart
packages/design_system/lib/src/components/kd_list_row.dart
packages/design_system/lib/src/components/kd_certainty_badge.dart
packages/design_system/lib/src/components/kd_entry_photo.dart
packages/design_system/lib/src/components/kd_section_header.dart
packages/design_system/lib/src/components/kd_app_bar.dart
packages/design_system/lib/src/state_visual.dart
packages/design_system/lib/design_system.dart                     # EDIT: 8 export lines
packages/design_system/lib/src/tokens.dart                        # EDIT: dangerBand, dangerInk
packages/design_system/lib/src/theme.dart                         # EDIT: point at the tokens
packages/design_system/test/component_matrix_test.dart
packages/design_system/test/kd_state_card_test.dart
packages/design_system/test/contrast_test.dart                    # EDIT
packages/design_system/test/helpers/{pump_component,a11y_matchers,fixtures}.dart
```

No `KdCard`: `theme.dart:79-89` already themes `Card` correctly (white fill, 1dp border, radius 16, zero margin, zero elevation) and a wrapper would only give call sites a way to repaint it. No `KdActionButton` family: the theme already sets a 48dp floor on all three button types. Both cuts follow from "the theme is already right, do not restate it".

Two package rules, enforced by review and by the `no_flutter_imports` CI guard's sibling:
- **No component imports `AppLocalizations`.** All copy is injected as `String`. This is why component tests can pass real Nepali literals with no l10n plumbing.
- **No component accepts `color`, `elevation`, `shape` or `textStyle` overrides.** A call site that can repaint a card is how the 1.05:1 invisible card returns.

**Token housekeeping this forces, and it is a real finding.** `theme.dart:35-36` declares `errorContainer: Color(0xFFF6DCDC)` and `onErrorContainer: Color(0xFF5C1010)` as raw hex inside the theme, outside `tokens.dart`, and outside `contrast_test.dart`. Those are the only two unaudited colours left in the design system after Module 12. They become `KdColors.dangerBand` and `KdColors.dangerInk`, the theme points at the tokens, and `contrast_test.dart` gains `scheme.errorContainer == KdColors.dangerBand` — the same class of guard as the existing `scheme.primary == KdColors.primary`.

**`KdStateVisual` closes a live inconsistency.** `history_screen.dart:57-73` gives all three states a glyph and a state rail; `diagnosis_result_view.dart:67` gives confident and out-of-scope no glyph at all and paints uncertain with `KdColors.warning` instead of `KdColors.stateUncertainRail` — the same hex today, two tokens, one edit from drift. One owner, one switch.

**Test:** see section 7 for the matrix. `kd_state_card_test.dart` asserts, without reading a single colour: each state renders its own glyph and no other's; each card is exactly one semantics node whose label begins with the state name; every state renders at least one enabled action.

### Item 6 — app screens, routes, ARB

```
app/lib/src/handbook/handbook_home_screen.dart      # /handbook
app/lib/src/handbook/crop_entries_screen.dart       # /handbook/crop/:cropKey
app/lib/src/handbook/symptom_browse_screen.dart     # /handbook/see  [?tag=]
app/lib/src/handbook/entry_screen.dart              # /handbook/entry/:id
app/lib/src/handbook/entry_section_screen.dart      # /handbook/entry/:id/:section
app/lib/src/handbook/search_screen.dart             # /handbook/search
app/lib/src/handbook/handbook_providers.dart
app/lib/src/router.dart                             # EDIT: 6 routes
app/lib/src/app_services.dart                       # EDIT: KbDatabase + double-open guard + dispose
app/lib/src/home_screen.dart                        # EDIT: Diagnose tile stops saying "coming soon"
app/lib/l10n/app_{en,ne,hi}.arb                     # EDIT
app/pubspec.yaml                                    # EDIT: assets: - assets/kb/
app/test/handbook/{browse,entry,search}_test.dart
app/test/handbook/screen_matrix_test.dart
app/test/l10n_lint_test.dart
```

`AppServices` gains the second connection. Because this module creates it, this module also pays the recorded debt: `AppServices.open()` gets a double-open guard and `main()` gets a `dispose` path, for both databases. Adding a second connection to a composition root that already has no guard would double a known defect.

**The entry screen is two levels, and that is the fix for "the answer is five viewports down".** At 320×640 scale 2.0 in Nepali the viewport is 512dp and one `bodyMedium` line is 51.2dp, so a single-page entry with five symptoms, five actions, four do-nots, three confusions and five prevention lines is roughly six screenfuls.

- **Level 1** (`/handbook/entry/:id`): `KdEntryPhoto` → display name + `KdCertaintyBadge(notAssessed)` → `one_line` → **"Do this now"** inline (max 5 actions) → four `KdListRow`s with counts and chevrons for "What you see", "Do not do this", "Do not mix this up", "Next season" → `handbookNotIt` action. Roughly 1570dp at 2.0 in Nepali, about three viewports; about 1.2 at scale 1.0.
- **Level 2** (`/handbook/entry/:id/:section`): one section, full width, its own scroll.

The farmer arrived here from a symptom or a name, so identification is largely done; what she came for is what to do, and it is above the second fold.

**Test:** `screen_matrix_test.dart` (section 7). `browse_test.dart` — a tag tile with zero entries is not rendered; a tag tile with no example photo is not rendered; an entry with no text row in the active language is not returned; potato and maize render `KdEmptyState` with the coverage tone and a working action.

### Item 7 — Home wiring

The Diagnose tile keeps saying "coming soon" (no model). A new hero row on Home routes to `/handbook`, and empty History gains an action pointing at it. The handbook is the first user-reachable destination in eleven modules; it must be one tap from the launcher.

**Test:** `app/test/home_layout_test.dart` gains the handbook tile to its existing 27-case loop and its 48dp target loop.

---

## 3. The content schema

### 3.1 Drift tables — `packages/core_data/lib/src/kb/kb_tables.dart`

Eighteen tables plus one virtual. The shape is mostly `(parent, parent_text)` pairs, because row-per-language is what makes a fourth language a set of INSERTs rather than a schema migration (D-06: new languages are data, not code).

```dart
import 'package:core_domain/core_domain.dart';
import 'package:drift/drift.dart';

// ---------------------------------------------------------------- pack meta
@DataClassName('KbMetaRow')
class KbMeta extends Table {
  TextColumn get key => text()();          // pack_version, pack_schema_version,
  TextColumn get value => text()();        // built_at_ms, channel, content_commit
  @override Set<Column<Object>> get primaryKey => {key};
}

// --------------------------------------------------- controlled vocabularies
/// The taxonomy is DATA. `kind` is one of 'symptom_tag' | 'plant_part' |
/// 'action_kind' | 'harm'. Adding a ninth symptom tag is an INSERT in a pack an
/// already-installed binary can read; a Dart enum here would make it an app
/// release, and `textEnum` stores by NAME so an old binary would crash on a
/// newer pack.
@DataClassName('KbVocabRow')
@TableIndex(name: 'idx_kb_vocab_kind', columns: {#kind, #sortRank})
class KbVocab extends Table {
  TextColumn get kind => text()();
  TextColumn get key => text()();
  /// Browse-by-see needs a picture. It is a designated crop of an agronomist
  /// supplied entry photo (D-54), so it costs no illustrator and no new bytes.
  TextColumn get examplePhotoId => text().nullable()();
  IntColumn get sortRank => integer()();
  @override Set<Column<Object>> get primaryKey => {kind, key};
}

@DataClassName('KbVocabTextRow')
class KbVocabTexts extends Table {
  TextColumn get kind => text()();
  TextColumn get key => text()();
  TextColumn get lang => text()();
  TextColumn get label => text()();        // <= 8 grapheme clusters in ne/hi
  TextColumn get hint => text().nullable()();
  @override Set<Column<Object>> get primaryKey => {kind, key, lang};
}

// ------------------------------------------------------------------ people
@DataClassName('KbReviewerRow')
class KbReviewers extends Table {
  TextColumn get id => text()();           // 'rev.engineer.draft'
  TextColumn get displayName => text()();
  TextColumn get credential => text()();
  TextColumn get organisation => text()();
  @override Set<Column<Object>> get primaryKey => {id};
}

// ------------------------------------------------------------------ entries
@DataClassName('KbEntryRow')
@TableIndex(name: 'idx_kb_entry_crop', columns: {#cropKey, #sortRank})
@TableIndex(name: 'idx_kb_entry_label', columns: {#modelLabel})
class KbEntries extends Table {
  TextColumn get id => text()();                    // 'tomato.late_blight'
  IntColumn  get contentVersion => integer()();     // D-43 recall anchor
  TextColumn get cropKey => text()();               // joins Crop.key
  TextColumn get pathogenKind => text().nullable()();
  TextColumn get pathogenBinomial => text().nullable()();
  IntColumn  get severityRank => integer()();       // 0 healthy .. 3 crop loss
  IntColumn  get prevalenceRank => integer()();
  IntColumn  get sortRank => integer()();
  /// D-35: the ONLY bridge from a raw classifier key to a name a farmer reads.
  /// Nullable and indexed: the handbook ships before any model exists.
  TextColumn get modelLabel => text().nullable()();
  /// Computed by the build from signoff.yaml. An author cannot write it (D-57).
  TextColumn get lifecycle => textEnum<KbLifecycle>()();
  TextColumn get authoredBy => text().references(KbReviewers, #id)();
  TextColumn get reviewedBy => text().references(KbReviewers, #id).nullable()();
  IntColumn  get reviewedAtMs => integer().nullable()();
  IntColumn  get validFromMs => integer()();
  /// The offline recall mechanism (D-58). A phone with no signal cannot receive
  /// a revocation, so the horizon IS the revocation list. Max 400 days.
  IntColumn  get validUntilMs => integer()();
  TextColumn get heroPhotoId => text()();           // NOT NULL, validator rule 6
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbEntryTextRow')
class KbEntryTexts extends Table {
  TextColumn get entryId => text().references(KbEntries, #id)();
  TextColumn get lang => text()();
  TextColumn get displayName => text()();           // D-35
  TextColumn get oneLine => text()();               // <= 18 words / 100 chars
  TextColumn get whenItHappens => text().nullable()();
  TextColumn get nativeReviewedBy => text().nullable()();   // the D-06 gate
  IntColumn  get nativeReviewedAtMs => integer().nullable()();
  @override Set<Column<Object>> get primaryKey => {entryId, lang};
}

/// Nothing queries this in Module 14: there is no jurisdiction setting and no
/// picker. It is safe because validator rule 19 (D-56) refuses a release entry
/// tagged for only one jurisdiction. A join table rather than a JSON blob,
/// because a blob cannot be indexed or joined and would have to be rebuilt as
/// this table the day the filter turns on.
@DataClassName('KbEntryJurisdictionRow')
class KbEntryJurisdictions extends Table {
  TextColumn get entryId => text().references(KbEntries, #id)();
  TextColumn get jurisdiction => textEnum<Jurisdiction>()();
  @override Set<Column<Object>> get primaryKey => {entryId, jurisdiction};
}

// ----------------------------------------------------------------- symptoms
@DataClassName('KbSymptomRow')
@TableIndex(name: 'idx_kb_symptom_tag', columns: {#tagKey, #partKey})
class KbSymptoms extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(KbEntries, #id)();
  IntColumn  get seq => integer()();
  TextColumn get tagKey => text()();                // kb_vocab kind=symptom_tag
  TextColumn get partKey => text()();               // kb_vocab kind=plant_part
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isDiagnostic => boolean().withDefault(const Constant(false))();
  TextColumn get photoId => text().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbSymptomTextRow')
class KbSymptomTexts extends Table {
  TextColumn get symptomId => text().references(KbSymptoms, #id)();
  TextColumn get lang => text()();
  TextColumn get text => text()();                  // <= 14 words / 90 chars
  @override Set<Column<Object>> get primaryKey => {symptomId, lang};
}

// ------------------------------------------------------------------ actions
@DataClassName('KbActionRow')
@TableIndex(name: 'idx_kb_action_order', columns: {#entryId, #riskClass, #seq})
class KbActions extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(KbEntries, #id)();
  IntColumn  get seq => integer()();
  TextColumn get kindKey => text()();               // kb_vocab kind=action_kind
  /// Ascending sort key, so IPM ordering is structural rather than an editorial
  /// habit (D-25). This is a Dart enum because it is app behaviour, not content.
  TextColumn get riskClass => textEnum<RiskClass>()();
  TextColumn get whenClass => text()();             // 'today' | 'this_week' | 'ongoing'
  IntColumn  get withinDays => integer().nullable()();

  // --- CHEMICAL BLOCK. Present in the schema, EMPTY in every launch pack
  // (D-53). Amounts are TEXT holding a decimal literal, never REAL: 2.5 must
  // round trip byte identical, and a float printing as 2.4999999 on one device
  // is a defect nobody catches in review. Doses are structured fields and are
  // NEVER translated: validator rule 12 rejects a digit followed by a unit word
  // in prose, in Latin OR Devanagari digits.
  TextColumn get activeIngredient => text().nullable()();
  TextColumn get formulationCode => text().nullable()();
  TextColumn get concentrationPercent => text().nullable()();
  TextColumn get doseMin => text().nullable()();
  TextColumn get doseMax => text().nullable()();
  TextColumn get doseUnit => text().nullable()();   // 'gram' | 'millilitre'
  TextColumn get doseBasis => text().nullable()();  // 'per_litre_water'
  IntColumn  get preHarvestIntervalDays => integer().nullable()();
  IntColumn  get reEntryIntervalHours => integer().nullable()();
  IntColumn  get maxApplicationsPerSeason => integer().nullable()();
  TextColumn get resistanceGroup => text().nullable()();
  TextColumn get sourceCitation => text().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbActionTextRow')
class KbActionTexts extends Table {
  TextColumn get actionId => text().references(KbActions, #id)();
  TextColumn get lang => text()();
  TextColumn get instruction => text()();
  TextColumn get caution => text().nullable()();
  TextColumn get verifyLocally => text().nullable()();  // required if chemical
  @override Set<Column<Object>> get primaryKey => {actionId, lang};
}

// ------------------------------------------------------------------- donts
@DataClassName('KbDontRow')
class KbDonts extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(KbEntries, #id)();
  IntColumn  get seq => integer()();
  TextColumn get harmKey => text()();               // kb_vocab kind=harm
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbDontTextRow')
class KbDontTexts extends Table {
  TextColumn get dontId => text().references(KbDonts, #id)();
  TextColumn get lang => text()();
  TextColumn get text => text()();
  @override Set<Column<Object>> get primaryKey => {dontId, lang};
}

// -------------------------------------------------------------- confusions
/// `otherEntryId` is NULLABLE and is not a foreign key. This breaks the
/// bootstrap deadlock that made `content-schema`'s worked entry unbuildable:
/// entry #1 must be allowed to say "do not mix this up with early blight"
/// before an early blight entry exists. What the farmer needs is the
/// distinguishing sentence, not the link; the link is a bonus when it resolves.
@DataClassName('KbConfusionRow')
class KbConfusions extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(KbEntries, #id)();
  IntColumn  get seq => integer()();
  TextColumn get otherEntryId => text().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbConfusionTextRow')
class KbConfusionTexts extends Table {
  TextColumn get confusionId => text().references(KbConfusions, #id)();
  TextColumn get lang => text()();
  TextColumn get otherName => text()();             // shown even when unlinked
  TextColumn get tellApart => text()();             // the ONE separating fact
  @override Set<Column<Object>> get primaryKey => {confusionId, lang};
}

// ------------------------------------------------------------------ photos
@DataClassName('KbPhotoRow')
class KbPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();
  TextColumn get role => textEnum<PhotoRole>()();   // hero | detail | tagExample
  TextColumn get assetPath => text()();             // 'assets/kb/photos/<id>.jpg'
  IntColumn  get widthPx => integer()();
  IntColumn  get heightPx => integer()();
  IntColumn  get bytes => integer()();
  TextColumn get sha256 => text()();
  /// Focal point in [0,1]. A square tag tile is a BoxFit.cover crop around this
  /// point, so the browse picture costs zero extra bytes.
  RealColumn get focusX => real().withDefault(const Constant(0.5))();
  RealColumn get focusY => real().withDefault(const Constant(0.5))();
  TextColumn get licence => text()();               // 'own'|'ccBy'|'ccBySa'|'licensed'|'publicDomain'|'pending'
  TextColumn get credit => text()();
  BoolColumn get inInstallPack => boolean().withDefault(const Constant(true))();
  @override Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('KbPhotoTextRow')
class KbPhotoTexts extends Table {
  TextColumn get photoId => text().references(KbPhotos, #id)();
  TextColumn get lang => text()();
  TextColumn get altText => text()();
  @override Set<Column<Object>> get primaryKey => {photoId, lang};
}

// ------------------------------------------------------------------ search
/// One table for names, synonyms, symptom text and body prose. `folded` is the
/// only FTS-indexed value, so there is exactly ONE indexed column and the
/// column-filter syntax that `content-schema` got wrong cannot be written.
@DataClassName('KbSearchDocRow')
@TableIndex(name: 'idx_kb_doc_folded', columns: {#folded})
class KbSearchDocs extends Table {
  IntColumn  get id => integer().autoIncrement()();  // FTS content_rowid
  TextColumn get entryId => text().references(KbEntries, #id)();
  TextColumn get lang => text()();
  TextColumn get field => text()();                  // 'name'|'synonym'|'symptom'|'body'
  IntColumn  get weight => integer()();              // 100 | 80 | 50 | 30
  TextColumn get native => text()();                 // as authored, for display
  TextColumn get folded => text()();                 // foldForSearch(native)
}
```

`packages/core_data/lib/src/kb/kb.drift`:

```sql
CREATE VIRTUAL TABLE kb_fts USING fts5(
  folded,
  content='kb_search_docs',
  content_rowid='id',
  tokenize='trigram case_sensitive 0'
);
```

Trigram, not `unicode61`: there is no Devanagari stemmer in SQLite and Nepali glues postpositions onto the noun, so `पात` must match inside `पातहरूमा`. `unicode61` indexes whole words and matches none of them. The cost, stated rather than discovered later: **queries under three characters never match**, handled by an explicit prefix scan on `kb_search_docs.folded` for `field IN ('name','synonym')`.

The search query, with both of `content-schema`'s bugs fixed:

```sql
SELECT d.entry_id, d.lang, d.field, d.native,
       bm25(kb_fts) AS score
FROM kb_fts
JOIN kb_search_docs d ON d.id = kb_fts.rowid
WHERE kb_fts MATCH ?                     -- a bare quoted phrase, one column
  AND d.lang IN (?, 'en')
ORDER BY bm25(kb_fts) * (1.0 + d.weight / 100.0) ASC
LIMIT 50;
```

`bm25()` returns a negative value where smaller is better, so multiplying by a larger weight factor makes a name hit **more** negative and `ASC` puts it first. `content-schema` divided, which demoted every name hit below every body hit.

`KbDatabase`:

```dart
@DriftDatabase(tables: [ /* the 18 above */ ], include: {'kb.drift'})
class KbDatabase extends _$KbDatabase {
  KbDatabase(super.executor);

  /// The PACK schema version, independent of AppDatabase.schemaVersion. A pack
  /// declaring a higher value than this is refused with a visible KdStateCard,
  /// never a crash.
  static const int supportedPackSchema = 1;

  @override int get schemaVersion => supportedPackSchema;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
```

### 3.2 The Dart model — `packages/core_domain/lib/src/kb/`

```dart
/// Never a bare String. If Nepali is missing the UI must SAY so rather than
/// silently render English, because a silent English paragraph in a Nepali app
/// is the exact failure D-06 exists to prevent.
@immutable
final class KbText {
  const KbText({required this.text, required this.requested, required this.resolved});
  final String text;
  final AppLanguage requested;
  final AppLanguage resolved;
  bool get isFallback => requested != resolved;
}

enum RiskClass { cultural, biological, chemical }   // ascending sort key, D-25
enum PhotoRole { hero, detail, tagExample }
enum KbLifecycle { draft, approved }
/// Only `notAssessed` is constructible in Module 14: no model exists and this
/// module writes no mapper. The other three are the shape the mapper will fill.
enum CertaintyBand { notAssessed, mightBe, probably, looksLike }

@immutable
final class KbEntry {
  const KbEntry({
    required this.id, required this.contentVersion, required this.cropKey,
    required this.severityRank, required this.lifecycle,
    required this.displayName, required this.oneLine,
    required this.heroPhoto, required this.symptoms, required this.actions,
    required this.donts, required this.confusions, required this.photos,
    required this.reviewedBy, required this.validUntil,
    this.modelLabel, this.whenItHappens, this.pathogenBinomial,
  }) : assert(symptoms.length > 0, 'an entry a farmer cannot recognise is not an entry');

  final String id;
  final int contentVersion;
  final String cropKey;
  final int severityRank;
  final KbLifecycle lifecycle;
  final KbText displayName;
  final KbText oneLine;
  final KbText? whenItHappens;
  final String? pathogenBinomial;
  final String? modelLabel;
  final KbPhoto heroPhoto;
  final List<KbSymptom> symptoms;
  /// Sorted by RiskClass ascending then seq. Sorting is done once, here.
  final List<KbAction> actions;
  final List<KbDont> donts;
  final List<KbConfusion> confusions;
  final List<KbPhoto> photos;
  final KbReviewer? reviewedBy;
  final DateTime validUntil;

  bool isStale(DateTime trustedNow) => trustedNow.isAfter(validUntil);
}

@immutable
final class KbAction {
  const KbAction({
    required this.id, required this.seq, required this.kindKey,
    required this.riskClass, required this.whenClass, required this.instruction,
    this.caution, this.withinDays, this.chemical,
  }) : assert(riskClass != RiskClass.chemical || chemical != null,
              'a chemical action without a dose block is unrepresentable');
  final String id; final int seq; final String kindKey;
  final RiskClass riskClass; final String whenClass;
  final KbText instruction; final KbText? caution; final int? withinDays;
  final KbChemical? chemical;
}

/// Every field is required. This is the point: an action carrying a dose but no
/// pre-harvest interval, no re-entry interval, no application cap, no
/// jurisdiction and no citation cannot be built.
@immutable
final class KbChemical {
  const KbChemical({
    required this.activeIngredient, required this.doseMin, required this.doseMax,
    required this.doseUnit, required this.doseBasis,
    required this.preHarvestIntervalDays, required this.reEntryIntervalHours,
    required this.maxApplicationsPerSeason, required this.sourceCitation,
    required this.verifyLocally, required this.jurisdictions,
  }) : assert(jurisdictions.length > 0);
  final String activeIngredient;
  final String doseMin, doseMax;      // decimal literals, never double
  final String doseUnit, doseBasis;
  final int preHarvestIntervalDays, reEntryIntervalHours, maxApplicationsPerSeason;
  final String sourceCitation;
  final KbText verifyLocally;
  final Set<Jurisdiction> jurisdictions;
}
```

The repository port:

```dart
abstract interface class KbRepository {
  Future<KbPackInfo> packInfo();
  Future<List<FacetCount>> cropCounts({required AppLanguage lang});
  /// Only tags that have BOTH a nonzero count and an example photo.
  Future<List<FacetCount>> symptomTagCounts({String? cropKey, required AppLanguage lang});
  Future<List<KbEntrySummary>> entries({String? cropKey, String? tagKey, required AppLanguage lang});
  Future<KbEntry?> entryById(String id, {required AppLanguage lang});
  /// D-35: the model-label bridge. Returns null before a model exists.
  Future<KbEntry?> entryByModelLabel(String label, {required AppLanguage lang});
  Future<List<SearchHit>> search(String query, {required AppLanguage lang, int limit = 30});
}
```

**Two query rules that live in SQL, not in a comment.**

*Language visibility.* Every browse and search query carries `AND EXISTS (SELECT 1 FROM kb_entry_texts t WHERE t.entry_id = e.id AND t.lang = :lang)`. A partially translated pack degrades to **fewer entries**, never to a mixed-language screen. Sections that are null *within* a translated entry render `handbookNotInLanguage`.

*Absence is not a negative.* A filter on a facet an entry does not carry must not delete that entry:

```sql
AND ( NOT EXISTS (SELECT 1 FROM kb_symptoms s WHERE s.entry_id = e.id)
      OR EXISTS   (SELECT 1 FROM kb_symptoms s WHERE s.entry_id = e.id AND s.tag_key = :tag) )
```

Otherwise a sparse facet silently deletes untagged entries and the farmer never learns the list shrank for a bad reason.

### 3.3 The authoring shape

Authoring is **YAML in git**, not JSON and not a spreadsheet. YAML because entries carry multi-line prose and author notes to the reviewer, which JSON cannot express; git because a spreadsheet cannot hold the photo files that are a required field, and a one-way Sheets export is a second build to keep green. `tools/kb build` emits the JSON pack; the JSON is generated, so hand-editing it is impossible.

The trigger for revisiting, written down now so it is not relitigated monthly: **build an authoring portal when a non-technical author is blocked on git for the second time, or when the entry count passes 100, whichever is first.**

`content/kb/entries/<id>/common.yaml` — language-invariant facts:

```yaml
schema_version: 1
id: <crop>.<slug>
content_version: <int>
crop_key: <key from LaunchCropCatalog>
pathogen_kind: <string|null>
pathogen_binomial: <string|null>
severity_rank: 0..3
prevalence_rank: 0..3
sort_rank: <int>
model_labels: [<raw classifier key>, ...]      # [] is legal
jurisdictions: [NP, IN]                        # both, until D-56 is lifted
valid_from: YYYY-MM-DD
valid_until: YYYY-MM-DD                        # <= valid_from + 400 days
authored_by: <reviewer id>
hero_photo_id: <photo id>                      # REQUIRED
symptoms:
  - { seq: 1, tag: <vocab key>, part: <vocab key>, primary: true,
      diagnostic: false, photo_id: <id|null> }
actions:
  - { id: act.1, seq: 1, kind: <vocab key>, risk_class: cultural,
      when: today, within_days: 1 }
donts:
  - { seq: 1, harm: <vocab key> }
confusions:
  - { seq: 1, other_entry_id: <id|null> }       # null is legal, see 3.1
photos:
  - { id: <id>, role: hero, file: photos/<name>.jpg,
      focus_x: 0.0..1.0, focus_y: 0.0..1.0,
      licence: own|ccBy|ccBySa|licensed|publicDomain|pending,
      credit: <string>, in_install_pack: true }
```

`text.<lang>.yaml` — prose only:

```yaml
lang: <en|ne|hi>
entry_id: <id>
display_name: <string>
one_line: <string>
when_it_happens: <string|null>
symptoms:  { 1: <string>, ... }
actions:   { act.1: { instruction: <string>, caution: <string|null> }, ... }
donts:     { 1: <string>, ... }
confusions:{ 1: { other_name: <string>, tell_apart: <string> }, ... }
photo_alt: { <photo id>: <string>, ... }
terms:     [ { term: <string>, kind: name|synonym|local }, ... ]
```

`signoff.yaml` — the file `review_status` is computed from:

```yaml
entry_id: <id>
signatures:
  - scope: content            # everything language-invariant plus text.en
    reviewer: <reviewer id>
    signed_at: <ISO8601 UTC>
    content_hash: "sha256:<hex>"
    artefact: <path|null>
  - scope: language:ne
    reviewer: <reviewer id>
    signed_at: <ISO8601 UTC>
    content_hash: "sha256:<hex>"
```

Two scopes, not four: `content` and `language:<lang>`. That is exactly the D-06 gate and nothing more, and adding scopes later is a validator change, not a schema change. **The canonical hash includes the sha256 of every referenced photo file**, which closes the hole that let a photo be swapped under an intact signature.

Built pack envelope, `app/assets/kb/kb-<pack_version>.json`:

```json
{
  "pack_schema_version": 1,
  "pack_version": "2026.08.1",
  "channel": "draft",
  "built_at_ms": 1785000000000,
  "content_commit": "<git sha>",
  "vocab":     [ { "kind": "...", "key": "...", "example_photo_id": null,
                   "sort_rank": 10, "texts": { "en": { "label": "...", "hint": "..." } } } ],
  "reviewers": [ { "id": "...", "display_name": "...", "credential": "...",
                   "organisation": "..." } ],
  "entries":   [ { "...": "the merged common.yaml + text.*.yaml + computed lifecycle" } ],
  "search_docs": [ { "entry_id": "...", "lang": "ne", "field": "name",
                     "weight": 100, "native": "...", "folded": "..." } ]
}
```

`search_docs` are **precomputed by the builder** using the same `foldForSearch` the query path calls. One implementation, one test suite, no possible drift between build time and query time — which matters here because this repo's pure-Dart tests fall back to `winsqlite3.dll` on Windows while the device runs the SQLite bundled by `sqlite3_flutter_libs`, so any normalization that depended on tokenizer options could make the test path and the device path disagree with no test noticing.

### 3.4 `AppDatabase` v1 → v2, spelled out

```dart
@DataClassName('DiagnosisRow')
@TableIndex(name: 'idx_diagnoses_created', columns: {#createdAtMs})
class Diagnoses extends Table {
  TextColumn get id => text()();
  TextColumn get cropKey => text().nullable()();
  TextColumn get resultState => textEnum<ResultState>()();
  TextColumn get predictionsJson => text()();
  TextColumn get modelVersion => text()();
  TextColumn get imagePath => text().nullable()();
  IntColumn  get createdAtMs => integer()();

  // --- v2. The D-43 advice-recall anchor: which entry, at which content
  // version, from which pack, was shown for this diagnosis. All three nullable,
  // because every pre-v2 row predates the KB and an out-of-scope result
  // resolves to no entry at all. They will sit null through several releases;
  // adding them now, while they legitimately can be null, is far cheaper than
  // adding them after a model ships and a backfill is impossible.
  TextColumn get kbEntryId => text().nullable()();
  IntColumn  get kbContentVersion => integer().nullable()();
  TextColumn get kbPackVersion => text().nullable()();

  @override Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Diagnoses, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // EXPAND ONLY (D-28). Nothing is dropped, renamed, or tightened to NOT
    // NULL. CONTRACT is schema 3 and only after a release has shipped that
    // never reads the pre-v2 shape.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(diagnoses, diagnoses.kbEntryId);
        await m.addColumn(diagnoses, diagnoses.kbContentVersion);
        await m.addColumn(diagnoses, diagnoses.kbPackVersion);
      }
    },
  );
}
```

Three columns and no new user-side tables. `kb_bookmarks`, `kb_entry_opens` and `kb_revocations` are all cut (section 8).

### 3.5 What makes this schema durable

Six properties, each of which is what a proposal got wrong somewhere:

1. **Facts and prose are separate files with separate reviewers.** A dose is `dose_min`/`dose_max`/`unit`/`basis` in a file translators never open. A number that is never translated can never be mistranslated. `content-schema` invented this and then violated it in its own template; the split survives, the template is fixed.
2. **Row per language, keyed `(parentId, lang)`.** A fourth language is a set of INSERTs into a pack an installed binary already reads. A column per language would make it an `ALTER TABLE`, a codegen run, an app release, and a pack schema bump, which contradicts D-06's "new languages are data, not code".
3. **Taxonomy is data, behaviour is code.** Symptom tags, plant parts, action kinds and harm codes are vocab rows. Only `RiskClass`, `PhotoRole` and `KbLifecycle` are Dart enums, and each is app behaviour. A ninth symptom tag ships in a pack; it does not ship in a release.
4. **`review_status` has exactly one writer, and it is the build.** An author cannot type it. The hash covers the photo bytes, not just the credit line.
5. **Prose fields carry no numbers and no unlinked ids.** Validator rule 12 rejects a digit-plus-unit in prose in Latin *and* Devanagari digits; `confused_with.other_entry_id` is nullable so entry #1 is not deadlocked on entry #2.
6. **The dangerous fields are all-or-nothing.** `KbChemical` requires ingredient, dose, unit, basis, PHI, REI, application cap, citation, local-verification line and jurisdiction simultaneously. There is no representation of a half-specified chemical, so there is nothing for the validator to have to catch.

---

## 4. The worked entry

`content/kb/entries/tomato.late_blight/`

> **DRAFT. MUST NOT SHIP. WRITTEN BY AN ENGINEER, NOT AN AGRONOMIST.**
> Every agronomic claim below requires review and signature by a credentialed plant pathologist before it can reach a farmer. This is enforced, not requested: `signoff.yaml` carries no `content` signature, so `kb build --channel release` refuses this entry and `pack_builder_test.dart` asserts that refusal. `kb lint` passes, so the file lives in the repo and CI stays green. It exists to teach the shape, the reading level, and the standard of evidence.

**`common.yaml`**

```yaml
schema_version: 1
id: tomato.late_blight
content_version: 1
crop_key: tomato
pathogen_kind: oomycete
pathogen_binomial: Phytophthora infestans   # never shown to the farmer
severity_rank: 3
prevalence_rank: 3
sort_rank: 10

model_labels: [Tomato___Late_blight]
jurisdictions: [NP, IN]
valid_from: 2026-08-01
valid_until: 2027-08-01                     # 365 days, under the 400 cap

authored_by: rev.engineer.draft             # NOT an agronomist. See signoff.yaml.
hero_photo_id: ph.tomato.late_blight.leaf

symptoms:
  - { seq: 1, tag: patches_wet_edge,   part: leaf,        primary: true,
      diagnostic: false, photo_id: ph.tomato.late_blight.leaf }
  - { seq: 2, tag: powdery_growth,     part: leaf,        primary: false,
      diagnostic: true,  photo_id: ph.tomato.late_blight.underside }
  - { seq: 3, tag: streaks_dark,       part: stem,        primary: false, diagnostic: false }
  - { seq: 4, tag: patches_on_fruit,   part: fruit,       primary: false, diagnostic: false }
  - { seq: 5, tag: whole_plant_collapse, part: whole_plant, primary: false, diagnostic: false }

# CULTURAL ONLY. This launch pack carries zero chemical rows (D-53). The
# chemical block exists in the schema and is unrepresentable without an
# ingredient, a dose, a PHI, an REI, an application cap, a citation, a
# verify-locally line and a jurisdiction, all at once.
actions:
  - { id: act.1, seq: 1, kind: remove_and_destroy, risk_class: cultural, when: today, within_days: 1 }
  - { id: act.2, seq: 2, kind: irrigation_change,  risk_class: cultural, when: today }
  - { id: act.3, seq: 3, kind: spacing_and_staking,risk_class: cultural, when: this_week }
  - { id: act.4, seq: 4, kind: sanitation,         risk_class: cultural, when: this_week }
  - { id: act.5, seq: 5, kind: monitoring,         risk_class: cultural, when: ongoing }

donts:
  - { seq: 1, harm: spreads_disease }
  - { seq: 2, harm: spreads_disease }
  - { seq: 3, harm: spreads_disease }
  - { seq: 4, harm: damages_crop }

confusions:
  - { seq: 1, other_entry_id: null }        # early blight, not yet written
  - { seq: 2, other_entry_id: null }        # septoria, not yet written

photos:
  - id: ph.tomato.late_blight.leaf
    role: hero
    file: photos/leaf-patch.jpg
    focus_x: 0.52
    focus_y: 0.41
    licence: pending                        # BLOCKS `--channel release`
    credit: PENDING
    in_install_pack: true
  - id: ph.tomato.late_blight.underside
    role: detail
    file: photos/underside-fuzz.jpg
    focus_x: 0.48
    focus_y: 0.55
    licence: pending
    credit: PENDING
    in_install_pack: true
```

**`text.en.yaml`**

```yaml
lang: en
entry_id: tomato.late_blight
display_name: Late blight
one_line: A fast rot that can kill a tomato plant in three days of cool wet weather.
when_it_happens: Cool nights, wet leaves, cloudy days.

symptoms:
  1: Brown wet looking patches start at the edge or tip of a leaf.
  2: Early in the morning a fine white growth shows under the patch.
  3: Dark greasy marks run along the stem and go right around it.
  4: Hard brown patches spread over the fruit. The skin looks greasy.
  5: In cool wet weather the whole plant can fall over in three days.

actions:
  act.1:
    instruction: Pull out the worst plants today. Do not shake them.
    caution: Carry them out in a bag. Bury or burn them away from the field.
  act.2:
    instruction: Water at the root, never over the leaves.
    caution: Water in the morning so the leaves dry before night.
  act.3:
    instruction: Tie the plants up and leave space so air moves between them.
  act.4:
    instruction: Wash your hands and tools after touching sick plants.
  act.5:
    instruction: Walk the field every two days. This one moves fast after rain.

donts:
  1: Do not put sick leaves on the compost heap. The rot lives there.
  2: Do not leave pulled plants at the edge of the field.
  3: Do not walk through the field while the plants are wet.
  4: Do not keep seed or fruit from a plant that had this.

confusions:
  1:
    other_name: Early blight
    tell_apart: Early blight makes rings inside the spot, like a target, and has no white growth underneath.
  2:
    other_name: Septoria leaf spot
    tell_apart: Septoria makes many small round spots with grey centres. Late blight makes a few big patches.

photo_alt:
  ph.tomato.late_blight.leaf: A tomato leaf with a large brown wet patch spreading in from the edge.
  ph.tomato.late_blight.underside: The underside of the same leaf with fine white growth along the patch edge.

terms:
  - { term: late blight, kind: name }
  - { term: blight,      kind: synonym }
  - { term: leaf rot,    kind: local }
  - { term: jhulsa,      kind: synonym }
  - { term: dadhuwa,     kind: synonym }
```

**`text.ne.yaml`** — DRAFT, pending the D-06 native agronomist gate. Written by an engineer. It must be **rewritten by a native agronomist writer, not translated by a translator**: the writer has to know what farmers in the target districts actually call this.

```yaml
lang: ne
entry_id: tomato.late_blight
display_name: पछौटे डढुवा
one_line: चिसो र भिजेको मौसममा गोलभेँडाको बिरुवा तीन दिनमै मार्ने छिटो फैलिने रोग।
when_it_happens: चिसो रात, भिजेको पात, बादल लागेको दिन।

symptoms:
  1: पातको किनार वा टुप्पोबाट भिजेजस्तो खैरो दाग सुरु हुन्छ।
  2: बिहान सबेरै त्यही दागको मुनि मसिनो सेतो ढुसी देखिन्छ।
  3: डाँठमा कालो चिल्लो धर्सो लाग्छ र वरिपरि घेर्छ।
  4: फलमा खैरो कडा दाग फैलिन्छ। बोक्रा चिल्लो देखिन्छ।
  5: चिसो भिजेको मौसममा पूरै बिरुवा तीन दिनमै ढल्छ।

actions:
  act.1:
    instruction: सबैभन्दा बिग्रेका बिरुवा आजै उखेल्नुहोस्। नहल्लाउनुहोस्।
    caution: झोलामा हालेर बारीबाट टाढा लगी पुर्नुहोस् वा जलाउनुहोस्।
  act.2:
    instruction: पातमाथिबाट होइन, जरामा पानी हाल्नुहोस्।
    caution: बिहान सिँचाइ गर्नुहोस्, ताकि रातिअघि पात सुकोस्।
  act.3:
    instruction: बिरुवा उभ्याएर बाँध्नुहोस् र बीचमा हावा चल्ने ठाउँ छाड्नुहोस्।
  act.4:
    instruction: रोगी बिरुवा छोएपछि हात र औजार धुनुहोस्।
  act.5:
    instruction: दुई दिनमा एकपटक बारी घुम्नुहोस्। पानी परेपछि यो छिटो फैलिन्छ।

donts:
  1: रोगी पात कम्पोस्टमा नहाल्नुहोस्। रोग त्यहीँ बाँच्छ।
  2: उखेलेका बिरुवा बारीको छेउमा नछाड्नुहोस्।
  3: बिरुवा भिजेको बेला बारीभित्र नहिँड्नुहोस्।
  4: रोग लागेको बिरुवाको बीउ वा फल नराख्नुहोस्।

confusions:
  1:
    other_name: अगौटे डढुवा
    tell_apart: अगौटे डढुवाको दागभित्र निशानाजस्तो गोलो घेरा हुन्छ र मुनि सेतो ढुसी हुँदैन।
  2:
    other_name: सेप्टोरिया
    tell_apart: सेप्टोरियाले धेरै साना गोला दाग बनाउँछ। पछौटे डढुवाले थोरै ठूला दाग बनाउँछ।

photo_alt:
  ph.tomato.late_blight.leaf: गोलभेँडाको पातमा किनारबाट फैलिएको ठूलो खैरो भिजेको दाग।
  ph.tomato.late_blight.underside: त्यही पातको मुनिपट्टि दागको किनारमा मसिनो सेतो ढुसी।

terms:
  - { term: पछौटे डढुवा, kind: name }
  - { term: डढुवा,       kind: synonym }
  - { term: मरुवा,       kind: local }
  - { term: झुल्सा,      kind: local }
  - { term: dadhuwa,     kind: synonym }
  - { term: jhulsa,      kind: synonym }
```

**`text.hi.yaml`** — DRAFT, pending D-06. Same status.

```yaml
lang: hi
entry_id: tomato.late_blight
display_name: पिछेती झुलसा
one_line: ठंडे गीले मौसम में टमाटर के पौधे को तीन दिन में मार देने वाला तेज़ रोग।
when_it_happens: ठंडी रातें, गीले पत्ते, बादल वाले दिन।
symptoms:
  1: पत्ते के किनारे या नोक से गीले जैसे भूरे धब्बे शुरू होते हैं।
  2: सुबह जल्दी उसी धब्बे के नीचे महीन सफ़ेद फफूँद दिखती है।
  3: तने पर काली चिकनी धारी बनती है और चारों ओर घेर लेती है।
  4: फल पर भूरे कड़े धब्बे फैलते हैं। छिलका चिकना लगता है।
  5: ठंडे गीले मौसम में पूरा पौधा तीन दिन में गिर जाता है।
actions:
  act.1:
    instruction: सबसे ख़राब पौधे आज ही उखाड़ें। उन्हें हिलाएँ नहीं।
    caution: थैले में भरकर खेत से दूर ले जाकर गाड़ें या जलाएँ।
  act.2:
    instruction: पत्तों पर नहीं, जड़ में पानी दें।
    caution: सुबह सिंचाई करें, ताकि रात से पहले पत्ते सूख जाएँ।
  act.3:
    instruction: पौधों को बाँधकर खड़ा करें और बीच में हवा की जगह छोड़ें।
  act.4:
    instruction: रोगी पौधे छूने के बाद हाथ और औज़ार धोएँ।
  act.5:
    instruction: दो दिन में एक बार खेत घूमें। बारिश के बाद यह तेज़ फैलता है।
donts:
  1: रोगी पत्ते खाद के ढेर में न डालें। रोग वहीं जीवित रहता है।
  2: उखाड़े हुए पौधे खेत के किनारे न छोड़ें।
  3: पौधे गीले हों तब खेत में न चलें।
  4: रोग वाले पौधे का बीज या फल न रखें।
confusions:
  1:
    other_name: अगेती झुलसा
    tell_apart: अगेती झुलसा के धब्बे में निशाने जैसे गोल घेरे होते हैं और नीचे सफ़ेद फफूँद नहीं होती।
  2:
    other_name: सेप्टोरिया
    tell_apart: सेप्टोरिया कई छोटे गोल धब्बे बनाता है। पिछेती झुलसा कुछ बड़े धब्बे बनाता है।
photo_alt:
  ph.tomato.late_blight.leaf: टमाटर के पत्ते पर किनारे से फैलता बड़ा भूरा गीला धब्बा।
  ph.tomato.late_blight.underside: उसी पत्ते के नीचे धब्बे के किनारे महीन सफ़ेद फफूँद।
terms:
  - { term: पिछेती झुलसा, kind: name }
  - { term: झुलसा,        kind: synonym }
  - { term: पिछेता,       kind: local }
  - { term: jhulsa,       kind: synonym }
```

**`signoff.yaml`**

```yaml
entry_id: tomato.late_blight
signatures: []
# Empty on purpose. lifecycle computes to `draft`, so:
#   kb build --channel draft   -> included, rendered behind handbookDraftWarning
#   kb build --channel release -> REFUSED, non-zero exit
# pack_builder_test.dart asserts both. Do not add a signature to make CI green.
```

**`content/kb/reviewers.yaml`**

```yaml
- id: rev.engineer.draft
  display_name: KrishiDoc engineering
  credential: Not an agronomist
  organisation: KrishiDoc
```

That credential string is deliberate: if this ever renders, it renders as the truth.

---

## 5. ARB keys

All 34 keys below are new. `ne` and `hi` are **DRAFT pending the D-06 native agronomist gate**, sent to review as complete sentences and never as fragments, with the reviewer asked to confirm a farmer can repeat the sentence back. No em dashes, no en dashes. Symptom tag labels, plant part labels and disease names are **not here**: they are KB vocab and entry data (D-35).

| key | en (exact) | ne (DRAFT) | hi (DRAFT) |
|---|---|---|---|
| `handbookTitle` | Crop handbook | बाली पुस्तिका | फसल पुस्तिका |
| `handbookOffline` | Works with no internet. | इन्टरनेट नभए पनि चल्छ। | बिना इंटरनेट भी चलता है। |
| `handbookBrowseCrop` | Pick your crop | आफ्नो बाली छान्नुहोस् | अपनी फसल चुनें |
| `handbookBrowseSymptom` | Show me what I can see | मैले देखेको कुरा देखाउनुहोस् | जो दिख रहा है वह दिखाएँ |
| `handbookSearch` | Search by name | नामले खोज्नुहोस् | नाम से खोजें |
| `handbookEverythingAbout` | Everything about {crop} | {crop} बारे सबै | {crop} के बारे में सब |
| `handbookCount` | `{count, plural, =1{1 problem} other{{count} problems}}` | `{count, plural, other{{count} समस्या}}` | `{count, plural, other{{count} समस्या}}` |
| `handbookSectionSee` | What you see | के देखिन्छ | क्या दिखता है |
| `handbookSectionDo` | Do this now | अहिले यो गर्नुहोस् | अभी यह करें |
| `handbookSectionDont` | Do not do this | यो नगर्नुहोस् | यह न करें |
| `handbookSectionConfuse` | Do not mix this up | यीसँग नमिलाउनुहोस् | इनसे न मिलाएँ |
| `handbookSectionWhen` | When it comes | कहिले आउँछ | कब आता है |
| `handbookOpen` | Open {name} | {name} खोल्नुहोस् | {name} खोलें |
| `handbookNoEntriesTitle` | Nothing here yet. | यहाँ अहिले केही छैन। | यहाँ अभी कुछ नहीं है। |
| `handbookNoEntriesBody` | This crop has not been written up yet. | यो बालीको बारेमा अझै लेखिएको छैन। | इस फसल के बारे में अभी लिखा नहीं गया। |
| `handbookNoEntriesAction` | See what is here | के के छ हेर्नुहोस् | जो है वह देखें |
| `handbookNoPicturesTitle` | No pictures yet. | अहिले तस्बिर छैन। | अभी तस्वीर नहीं है। |
| `handbookNoPicturesBody` | An agronomist has not sent photos yet. | कृषि प्राविधिकले तस्बिर पठाएका छैनन्। | कृषि विशेषज्ञ ने तस्वीर नहीं भेजी। |
| `handbookNoPicturesAction` | Pick your crop instead | बरु बाली छान्नुहोस् | बदले में फसल चुनें |
| `handbookSearchNoneTitle` | Nothing matched that word. | त्यो शब्द मिलेन। | वह शब्द नहीं मिला। |
| `handbookSearchNoneBody` | Try one word, or look by what you see. | एउटै शब्द लेख्नुहोस्, वा देखेको कुराबाट खोज्नुहोस्। | एक शब्द लिखें, या जो दिखता है उससे खोजें। |
| `handbookSearchNoneAction` | Show me the pictures | तस्बिरहरू देखाउनुहोस् | तस्वीरें दिखाएँ |
| `handbookNotADiagnosis` | This is a handbook page. | यो पुस्तिकाको पाना हो। | यह पुस्तिका का पन्ना है। |
| `handbookNotADiagnosisBody` | The app has not looked at your plant. Compare the picture with your leaf. | एपले तपाईंको बिरुवा हेरेको छैन। तस्बिर आफ्नो पातसँग मिलाउनुहोस्। | ऐप ने आपका पौधा नहीं देखा। तस्वीर को अपने पत्ते से मिलाएँ। |
| `handbookNotIt` | This is not it. Show me the others. | यो होइन। अरू देखाउनुहोस्। | यह नहीं है। दूसरे दिखाएँ। |
| `certaintyNotAssessed` | The app has not looked at your plant. | एपले तपाईंको बिरुवा हेरेको छैन। | ऐप ने आपका पौधा नहीं देखा है। |
| `handbookNoSpray` | This page does not say what to spray. Ask a crop technician. | यो पानाले के छर्ने भन्दैन। कृषि प्राविधिकलाई सोध्नुहोस्। | यह पन्ना नहीं बताता क्या छिड़कें। कृषि प्राविधिक से पूछें। |
| `handbookPhotoPending` | Photo coming. An agronomist has not sent one yet. | तस्बिर आउँदैछ। कृषि प्राविधिकले पठाएका छैनन्। | तस्वीर आनी है। कृषि विशेषज्ञ ने नहीं भेजी। |
| `handbookPhotoCredit` | Photo: {credit} | तस्बिर: {credit} | तस्वीर: {credit} |
| `handbookReviewedBy` | Checked by {name}, {credential}. | {name}, {credential} ले जाँच्नुभयो। | {name}, {credential} ने जाँचा। |
| `handbookDraftWarning` | Not checked by an agronomist. Do not follow this yet. | कृषि प्राविधिकले जाँचेका छैनन्। अहिले यो नमान्नुहोस्। | कृषि विशेषज्ञ ने नहीं जाँचा। अभी इसे न मानें। |
| `handbookStale` | This page is over a year old. Some of it may have changed. | यो पाना एक वर्षभन्दा पुरानो छ। केही फेरिएको हुन सक्छ। | यह पन्ना एक साल से पुराना है। कुछ बदल सकता है। |
| `handbookNotInLanguage` | This part is not in your language yet. | यो भाग तपाईंको भाषामा अझै छैन। | यह हिस्सा आपकी भाषा में अभी नहीं है। |
| `handbookPreparing` | Getting the handbook ready. | पुस्तिका तयार हुँदैछ। | पुस्तिका तैयार हो रही है। |
| `handbookPackFailedTitle` | The handbook could not open. | पुस्तिका खुलेन। | पुस्तिका नहीं खुली। |
| `handbookPackFailedAction` | Try again | फेरि प्रयास गर्नुहोस् | फिर कोशिश करें |

Copy caps, enforced by `app/test/l10n_lint_test.dart`: every English value ≤ 14 words and ≤ 90 characters; every `ne`/`hi` value ≤ 90 grapheme clusters; no value in any locale contains U+2014 or U+2013. The longest string above (`handbookNotADiagnosisBody`, 14 words / 78 chars EN, 62 clusters NE) is the one that fails first and is in the full matrix.

Note on `handbookNoSpray`: the cognitive review's instruction to use कृषि प्राविधिक rather than the abstract विशेषज्ञ is followed, and the Latin-script initialism "JT/JTA" is deliberately not seeded into the English source, because a farmer who cannot read cannot read an acronym in a foreign script and a translator would carry it straight through.

---

## 6. Component APIs

```dart
// ---------------------------------------------- packages/design_system/lib/src/state_visual.dart
/// The single owner of state -> appearance. This currently exists in two places
/// that already disagree: history_screen.dart:57-73 gives every state a glyph
/// and a rail, while diagnosis_result_view.dart:67 paints uncertain with
/// KdColors.warning instead of KdColors.stateUncertainRail (same hex today, two
/// tokens, one edit from drift) and gives confident and out-of-scope no glyph.
///
/// Glyphs are chosen for SILHOUETTE difference, not interior detail. The old
/// pairing put check_circle_outline next to help_outline: two circles, identical
/// outline at 24dp at arm's length in sun. These are placeholders for the
/// deferred commissioned pictograms; swapping them is a one-line change here.
@immutable
final class KdStateVisual {
  const KdStateVisual._({required this.glyph, required this.rail,
                         required this.band, required this.ink});
  final IconData glyph;
  final Color rail, band, ink;
  static KdStateVisual of(ResultState state);
}

// -------------------------------------------- components/kd_state_card.dart
enum KdStateTone { confident, uncertain, outOfScope, neutral, warning }

/// A titled card with a 6dp tone rail, a tinted header band carrying the glyph
/// and title, a white body, and at least one action. There is no action-free
/// constructor: this app has shipped three dead-end states and will not ship a
/// fourth.
class KdStateCard extends StatelessWidget {
  const KdStateCard({
    required this.tone,
    required this.title,
    required this.semanticsLabel,
    this.body,
    this.actions = const <KdCardAction>[],
    this.glyph,
    super.key,
  });

  final KdStateTone tone;
  final String title;
  final String? body;
  /// Spoken as one sentence, state name FIRST, because "not checked" changes
  /// what the rest of the card means.
  final String semanticsLabel;
  final List<KdCardAction> actions;
  final IconData? glyph;
}

@immutable
final class KdCardAction {
  const KdCardAction({required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}
// Actions render VERTICALLY, full width, never in a horizontal Row.
// `escalateToClinic` expands 1.42x into Nepali and a side-by-side pair
// overflows at 320dp before any font scaling. This is a layout fact, not a
// preference.

// ------------------------------------------- components/kd_empty_state.dart
/// The CAUSE, which decides where blame points. Typed rather than styled,
/// because P0-7 was a copy defect with a structural root: the app blamed the
/// farmer's photo for what was really a coverage limit.
enum KdEmptyTone {
  invitation,   // nothing here YET, and that is normal
  coverage,     // WE do not have this. The app's limit, never her mistake.
  failure,      // something broke
}

class KdEmptyState extends StatelessWidget {
  const KdEmptyState({
    required this.tone,
    required this.headline,
    /// REQUIRED. A surface with nothing on it and nothing to do is a dead end.
    required this.action,
    this.body,
    this.glyph,
    super.key,
  });

  final KdEmptyTone tone;
  final String headline;
  final String? body;
  final KdCardAction action;
  final IconData? glyph;
}

// --------------------------------------------- components/kd_list_row.dart
class KdListRow extends StatelessWidget {
  const KdListRow({
    required this.title,
    this.supporting,
    this.leading,
    this.trailingCount,
    this.showChevron = false,
    this.rail,
    this.onTap,
    this.semanticsLabel,
    super.key,
  }) : assert(rail == null || leading != null,
              'a colour rail never carries meaning alone: pair it with a glyph');

  final String title;
  /// One short line. Never a paragraph.
  final String? supporting;
  /// KdEntryPhoto, or an Icon sized with kdScaledIcon. Nothing else.
  final Widget? leading;
  /// A plain numeral. Never a widget, so nothing can be smuggled into the
  /// trailing slot that competes with the title for horizontal space.
  final int? trailingCount;
  final bool showChevron;
  final Color? rail;
  final VoidCallback? onTap;
  final String? semanticsLabel;
}
```

**The rule that keeps `KdListRow` usable, and the reason the three proposals' versions were not.** At 320dp the content column is 288dp; inside a card with a 1dp border each side and 12dp padding each side it is 254dp. A 56dp leading plus two 12dp gaps plus a badge of intrinsic width leaves a title column of 45dp, which at Devanagari `bodyLarge` 18sp × 2.0 with an average advance near 0.5em holds two glyphs per line. So:

- `KdListRow` renders as a Row **only while `MediaQuery.textScalerOf(context).scale(16) <= 20`** (scale ≤ 1.25). Above that it stacks: leading above, title and supporting below, count and chevron on their own trailing line.
- `trailingCount` is an `int`, not a `Widget`, precisely so a badge cannot be placed beside a title.
- No `maxLines`, no `overflow`, no ellipsis, at any scale. A truncated Nepali disease name is a different disease name and the farmer cannot recover the missing half. Rows wrap and grow, and `expectNoTruncation` enforces it at render time rather than by convention.

```dart
// -------------------------------------- components/kd_certainty_badge.dart
class KdCertaintyBadge extends StatelessWidget {
  const KdCertaintyBadge({
    required this.band,
    required this.label,
    required this.semanticsLabel,
    super.key,
  });

  final CertaintyBand band;
  /// Short reviewed phrase. The full sentence lives in the card.
  final String label;
  /// e.g. "Certainty: the app has not looked at your plant". The pips are silent.
  final String semanticsLabel;
}
```

A pill with a 1dp `KdColors.border`, `KdRadius.xl`, `KdColors.surface` fill, a three-pip meter, then the label in `labelMedium` explicitly coloured `KdColors.inkBody`. Pips are `KdSpacing.sm` discs: filled `KdColors.inkStrong`, empty a 1.5dp `KdColors.border` ring. `notAssessed` renders zero filled pips.

**Owned contrast, which is what the Improvement Plan asked for and what none of the proposals delivered.** The UI review's complaint was that the certainty chip "never sets `labelStyle` so it inherits `onSurfaceVariant` and passes 7.21:1 BY ACCIDENT, chosen by nobody, tested by nothing." The badge therefore sets its own label colour and its own pip colours, and `contrast_test.dart` asserts those specific pairs by name. It introduces **no new colour tokens**, because the ordinal is carried by countable pips and by words, not by hue — the Module 12 three-rails arithmetic applied one level down. Measured with the repo's own calculator: filled pip against empty pip **4.78:1**, empty pip ring on surface **3.88:1**, label on fill **17.16:1**. If the assertion ever disagrees with those numbers, the assertion is right and this document is wrong.

The badge takes **no `double`**. There is no constructor that accepts a probability, so false precision on an uncalibrated model is unrepresentable rather than merely discouraged. It is also not tappable, and a test asserts it carries no tap action so the 48dp floor cannot be silently acquired.

```dart
// ------------------------------------------- components/kd_entry_photo.dart
class KdEntryPhoto extends StatelessWidget {
  const KdEntryPhoto({
    required this.photo,
    required this.pendingLabel,
    required this.aspect,
    this.altText,
    super.key,
  });

  /// Null renders the pending state at the exact size the photo will occupy,
  /// so the page does not reflow when photos land. It is not a "loading"
  /// state, not a broken-asset glyph, and not a grey rectangle that reads as a
  /// failed download.
  final KbPhoto? photo;
  final String pendingLabel;
  /// KdEntryPhoto.hero = 4/3, KdEntryPhoto.tile = 1/1.
  final double aspect;
  final String? altText;

  static const double hero = 4 / 3;
  static const double tile = 1;
}
```

Internally wraps the provider in `ResizeImage(provider, width: (renderWidth * devicePixelRatio).round())`. A crop list of 20 rows against 1024px photos would otherwise hold 20 decoded bitmaps at roughly 4 MB each, which is 80 MB of image cache on the 1 GB reference device (D-14). The component owning the resize means no call site can forget it. Square tile crops use `Alignment(focusX * 2 - 1, focusY * 2 - 1)` with `BoxFit.cover`, so a symptom tag picture costs zero extra bytes. **No network providers, at all**: the app is fully offline and a `NetworkImage` reachable from a component is a silent online dependency waiting to be added.

```dart
// --------------------------------------- components/kd_section_header.dart
class KdSectionHeader extends StatelessWidget {
  const KdSectionHeader({required this.title, this.count, super.key});
  final String title;
  final int? count;
}
```

`titleSmall` in `KdColors.inkMuted`, `Semantics(header: true)`, `KdSpacing.lg` above and `KdSpacing.smd` below. Latin locales get `title.toUpperCase()` and `letterSpacing: 0.6`; **Devanagari locales get neither**, gated on `KdType.isTallScript(Localizations.localeOf(context))`. The script has no case, and the letter spacing that conventionally accompanies a small-caps header is exactly what breaks the shirorekha. This is the second caller `KdType.isTallScript` has been waiting for.

```dart
// ---------------------------------------------- components/kd_app_bar.dart
/// Clamps the TITLE ONLY to text scale 1.3.
///
/// kToolbarHeight is a fixed 56dp. KdType._devanagari titleLarge is 22sp at
/// height 1.50, so at scale 2.0 the title needs 22 * 2.0 * 1.50 = 66dp and
/// clips today, on every screen in the app, in Nepali. Clamped: 22 * 1.3 * 1.50
/// = 42.9dp, which fits. The real page heading is repeated in the scroll body
/// at full scale, so nothing is lost.
class KdAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KdAppBar({required this.title, this.actions = const <Widget>[], super.key});
  final String title;
  final List<Widget> actions;
  @override Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
```

This is a shipping defect that `browse-by-sight` found and nothing else did. It lands regardless of everything else in this module.

---

## 7. The layout matrix that must pass

`packages/design_system/test/component_matrix_test.dart` and `app/test/handbook/screen_matrix_test.dart`. One file each, so a new component or screen cannot be added without entering the matrix.

**Dimensions**, identical to `home_layout_test.dart` so failures are comparable:

- screens: `320x640` (the supported floor), `360x800` (the volume device), `412x915` (mid-range)
- scales: `1.0` (default), `1.3` (Android "Large"), `2.0` (system slider maximum)
- locales: `ne` first (it wraps soonest, so it fails first), then `hi`, then `en`

**Full matrix (27 cases each):** `EntryScreen` level 1, `EntrySectionScreen`, `SymptomBrowseScreen`, `CropEntriesScreen`, `KdListRow`, `KdStateCard`, `KdEmptyState`.

**Worst case only (`320x640`, scale `2.0`, `ne`):** `HandbookHomeScreen`, `SearchScreen`, `KdCertaintyBadge`, `KdEntryPhoto`, `KdSectionHeader`, `KdAppBar`.

**Five assertions per case.** The first four are what the proposals had; the fifth is the one all three critiques found missing and is the reason their own harnesses certified their own failures.

1. `expect(tester.takeException(), isNull, reason: '<what> at <size> x<scale> in <locale>')`. An overflow reports through `FlutterError` during paint; reading it explicitly names the exact combination in the failure message.
2. **No horizontal overflow beyond the viewport.** Every rendered box: `getSize(...).width <= screen.width` and `getTopLeft(...).dx >= 0`. `takeException` catches a `RenderFlex` overflow but not a child painting outside a `Stack` or an unclipped `Row` inside a `SingleChildScrollView`.
3. **`expectNoTruncation(tester)`.** Walks every `RenderParagraph` and asserts `didExceedMaxLines` is false. This is the assertion behind banning `maxLines`: the ban has to be enforced at render time, not by convention.
4. **`expectTouchTargets(tester)`.** After `tester.ensureSemantics()`, walks the semantics tree and asserts every node carrying `SemanticsAction.tap` or `SemanticsFlag.isButton` has a transformed rect of at least 48×48. Generic rather than per-widget, so it catches the whole 32dp ActionChip class of defect in any future component for free.
5. **`expectMinTextColumn(tester, 120)`.** Walks every `RenderParagraph` and asserts its layout constraint width is at least 120dp. **This is the new one.** Text that wraps to two glyphs per line is not an overflow, is not truncation, does not exceed the viewport, and does not shrink a touch target, so assertions 1 to 4 all pass on a row whose title column has collapsed to 45dp and whose height has ballooned to 403dp. 120dp is roughly seven Devanagari clusters at `bodyLarge` scale 2.0, which is the floor below which a Nepali line stops being a line.

**No goldens, and the reason is the repo's own.** Widget tests render with no real font loaded, so a golden would pin the layout of placeholder boxes and prove nothing about whether Devanagari fits, while breaking on every unrelated platform font change. No Devanagari font is bundled either, so glyph extents are not deterministic. `home_layout_test.dart` already states this and it still holds.

**Fixtures matter.** `packages/design_system/test/helpers/fixtures.dart` carries real worst-case Nepali strings, not `'Late blight'`. Testing only English is exactly how the home overflow hid for four modules.

**Amended existing test.** `packages/design_system/test/diagnosis_result_view_test.dart:26-27` asserts `expect(find.byType(FilledButton), findsNothing)` on the confident card. That assertion is the thing pinning P0-6 in place. It is **inverted** this module to "every state carries at least one action, and the confident state carries a correction path", per the cognitive review's explicit instruction.

---

## 8. Cut list

| Cut | Reason |
|---|---|
| All chemical rows in the launch pack (D-53) | Dose-bearing rows are the slowest to review, the only content that can injure someone, and they need a registration feed nobody has; the block stays in the schema, unpopulated, and turns on with a pack update and no app release. |
| The jurisdiction picker and `SettingsKeys.jurisdiction` | With no chemical rows there is nothing to filter, and adding a blocking first-run decision before any value contradicts the measured "decisions before value: 2 to 3, do not touch it". |
| `kb_revocations` and `GET /v1/kb/revocations` | A revocation delivered in a pack is pointless (a phone with the old pack does not have the revocation either) and a pushed one needs a network call, which would unfreeze the backend this module exists to keep frozen. `valid_until` is the offline recall mechanism. |
| The second (chemical) validity horizon | No chemical rows ship, so a second horizon would be a column computed and never read, which is the P0-5 defect wearing a schema. |
| `kb_bookmarks`, `kb_entry_opens` | Two tables and a ranking input for a feature nobody asked for, in a module that must ship a schema. |
| The 35-consonant romanization transliterator and the eight-stage sloppy fold | Its own author's risk register concedes it is one person's guess whose failure mode is silent zero recall, and its aspirate collapse makes फल and पल collide. Synonym rows an agronomist writes are content, testable, and correct by construction. |
| Damerau-Levenshtein search fallback | Adds a linear scan and a threshold nobody has validated, to fix a zero-result rate nobody has measured. |
| Eight hand-drawn `CustomPainter` symptom glyphs | An engineer drawing plant pathology is a cheaper wrong answer substituted for a deferred right one; the tag picture is a crop of a real photo instead. |
| Material Icons as symptom metaphors | `blur_on`, `scatter_plot`, `grain`, `eco`, `local_florist` are desktop-toolbar metaphors, and for a non-reader a confidently wrong picture is worse than none. Material Icons stay for chrome (back, search, close, chevron), where the metaphor is about the app. |
| `KdCertaintyBanding`, `ModelPack.confidenceSplit`, `certainty_band` column | Requires a trained model that does not exist, invents three policy decisions no calibration set justifies, and its headroom formula bands a 0.62 answer as "good match" against a low-threshold pack, re-opening P0-5. |
| `KdCard`, the five-role button family, `KdShutterButton`, `KdCoachBanner`, `KdConfirmSheet`, `KdSkeletonRow`, `KdHeroActionCard`, `KdQuietTile`, `KdContextPill` | The theme already sets what mattered (48dp on all three button types, card fill/border/radius/margin); the rest belong to Module 13's Home restructure or Module 15's capture choreography, and extracting a component whose behaviour changes next module is how a design system acquires a wrong abstraction. |
| Google Sheets authoring, `kb pull`, `kb check` | A spreadsheet cannot hold the photo files that are a required field, mangles decimals on CSV round-trip, and a one-way export is a second build to keep green. Git plus YAML plus `kb new` covers 30 entries and four authors. |
| The authoring portal (D-34/D-36) | Correct at 300 entries and 20 external contributors, wrong now; trigger recorded so the decision is not relitigated monthly. |
| Scoped four-way sign-off hashes | Over-engineered at one entry, and the first schema change breaks every signature in a scope, spending the exact scarce resource the scoping was meant to conserve. Two scopes. |
| WebP photo encoding | `package:image` has no WebP encoder and does not decode HEIC, so this would mean shelling out to `cwebp` on CI and every dev machine, a native toolchain dependency against D-09's language cap. |
| Refactoring `home_screen.dart` tiles onto new components | The one P0 that is genuinely closed, with a 27-case guard validated against the broken layout; Module 13 restructures Home, and churning it now risks a closed defect for no user-visible gain. |
| Refactoring `history_screen.dart` | It renders `predictions.first.label`, the raw English classifier key, and no records exist; a refactor would render that raw label bigger and more prominent. It lands when `entryByModelLabel` has a model to resolve. |
| Human audio packs | The single highest-value follow-up for this audience, and it needs recorded voice, which is the same human-bandwidth constraint as R1. The `audio` columns are deliberately absent too: adding them is one pack schema bump, cheaper than shipping three unread columns. |
| Bikram Sambat dates, relative timestamps, dark theme, sunlight theme | Real, all deferred, all recorded as decisions rather than omissions. |

---

## 9. Decisions needing a new D-number

**D-52 — The knowledge base ships as a JSON content pack seeded into a separate device database.**
*Context:* the KB must be replaceable and evictable (D-14, D-47) while user history is not, and D-10 requires SQLite with FTS5 on device.
*Decision:* the KB ships as `assets/kb/kb-<version>.json`, is seeded by an idempotent seeder keyed on `pack_version` into `kb.sqlite`, a file separate from `app.sqlite`. The FTS5 index is built on device by one `rebuild` after the seed transaction. No prebuilt `.db` is shipped and no KB table is added to `AppDatabase`.
*Consequences:* a content reset is never a transaction over the farmer's history; the repo does not acquire an unverified read-only drift path; the app's first-run seed cost is bounded and must be measured on the reference device before D-49 scope. *Status: A.*

**D-53 — The launch knowledge base carries no chemical actions.**
*Context:* D-21 makes the curated KB the sole treatment truth and D-25 requires IPM-first; dose-bearing rows are the slowest to review, need a registration feed that has no machine-readable source, and are the only content that can injure a user.
*Decision:* release packs contain zero rows with `risk_class: chemical`. The chemical block remains in the schema and is unrepresentable without active ingredient, dose, unit, basis, pre-harvest interval, re-entry interval, application cap, source citation, local-verification line and jurisdiction, all simultaneously. Entries with no chemical action render `handbookNoSpray`, which names a person rather than a network.
*Consequences:* amends D-21 and D-25 in scope, not in principle; the chemical surface turns on with a pack update and no app release; R1's slowest rows leave the launch critical path. *Status: A\*, amending D-21/D-25.*

**D-54 — Symptom-tag imagery is a designated crop of an agronomist-supplied entry photo.**
*Context:* browse-by-what-you-see is meaningless to a non-reader without pictures, and the illustration set is deferred for want of a designer.
*Decision:* each vocabulary term may carry `example_photo_id` plus a focal point; the tile is a square `BoxFit.cover` crop around that point. A tag tile renders only when it has both a nonzero entry count and an example photo. `kb build --channel release` refuses a pack in which any tag reachable from a shipped entry lacks one.
*Consequences:* the browse picture costs no illustrator, no designer week, and zero extra bytes; symptom browse is genuinely empty until the first photo lands, which is honest and is a named exit criterion rather than a hidden failure. *Status: A.*

**D-55 — Search normalization is minimal; romanization is content, not an algorithm.**
*Context:* D-50 requires Devanagari trigram FTS plus synonyms, and farmers type both scripts.
*Decision:* `foldForSearch` performs NFC, ZWJ/ZWNJ stripping, Devanagari-to-Latin digit mapping, ASCII lowercasing and whitespace collapsing, and nothing else. It is implemented once in `core_domain` and called identically at build time and query time. Romanized forms (`jhulsa`, `dadhuwa`) are authored synonym rows.
*Consequences:* the failure mode of a wrong transliteration table (zero results, indistinguishable from a genuine miss, with no failing test) is eliminated; recall becomes an agronomist's editable data rather than an engineer's unvalidated guess; a query corpus is still required before launch and is recorded as such. *Status: A\*, refining D-50.*

**D-56 — Entries are tagged for both jurisdictions until a jurisdiction setting exists.**
*Context:* D-21 requires jurisdiction tagging, but the app has no jurisdiction state, no picker, and no safe way to infer one (device locale is unreliable in this market, SIM MCC is unreliable at the border, GPS needs a permission D-12 deliberately avoids).
*Decision:* `kb_entry_jurisdictions` ships as a join table and nothing queries it. `kb build --channel release` refuses any entry tagged for fewer than both jurisdictions. The gate lifts, and the filter turns on, when `SettingsKeys.jurisdiction` and its picker exist.
*Consequences:* the absence of a filter is safe by construction rather than merely unnoticed; the join table means turning the filter on is a query change, not a schema migration and a re-tag of every row. *Status: A\*, amending D-21.*

**D-57 — `review_status` is computed by the build and cannot be authored.**
*Context:* D-06 requires a native agronomist review gate, and a procedural promise in a document is not a gate.
*Decision:* `lifecycle` is derived by `kb build` from `signoff.yaml` over a canonical hash of the entry's scope, and the hash includes the sha256 of every referenced photo file. Two scopes: `content` and `language:<lang>`. Changing a single byte after signature demotes that scope to unsigned and drops the entry from the release pack. No human performs this step, so no human can forget it.
*Consequences:* unreviewed content is unshippable by construction rather than by discipline; swapping a photo file under an intact credit line no longer preserves a signature; a schema change invalidates the signatures in the scopes it touches, which is a real and accepted revalidation cost. *Status: A.*

**D-58 — The validity horizon is the only recall mechanism at launch; revocation lists are deferred.**
*Context:* D-21 promises revocation lists and D-43 promises an advice-recall ledger, but a phone with no signal cannot receive either, and building the endpoint would unfreeze the backend work the Improvement Plan froze.
*Decision:* every entry carries `valid_until` (maximum 400 days from sign-off), evaluated against a clock-skew-guarded `trustedNow` that falls back to the pack build time when the device clock is impossible. An expired entry renders `handbookStale` and keeps all its content. No revocation table, no revocation endpoint, no push channel in Module 14. The three D-43 ledger columns land on `diagnoses` now, nullable, because adding them after a model ships is a backfill nobody can reconstruct.
*Consequences:* a device offline on day 5 of a needed correction acts on stale content until it reconnects and receives a new pack; there is no engineering fix and the only levers are conservative content and short horizons, so this is stated in the risk register in those words rather than implied away. `kb_revocations` moves into the user database the moment a push channel exists, so that a pushed revocation survives a wholesale pack replace. *Status: A\*, amending D-21/D-43 in sequencing.*

---

## 10. Install budget, honestly

| item | figure | running total |
|---|---|---|
| Release APK arm64 today (measured, Module 11) | 22.8 MB | 22.8 MB |
| Noto Sans Devanagari subset (recorded debt, still unbundled) | 0.26 MB | 23.1 MB |
| Module 14 pack: 1 entry, 3 languages, 2 photos at 800px q82 | 0.30 MB | 23.4 MB |
| At full D-49 scope: 30 entries × 3 languages of text | 0.55 MB | — |
| 30 entries × 2 photos at 800px q82 (~140 KB each) | 8.4 MB | — |
| FTS5 trigram index over ~90 language-entries plus synonyms | 2.0 MB | — |
| **Projected at D-49 scope** | | **~34 MB** |

Against the D-47 budget of 60 MB, with three per-crop int8 LiteRT packs still to come. Photos are the constraint, not text, which is why `KbPhotos.inInstallPack` exists as the lever from day one: at ten crops with four photos each the photo bill alone is 22 MB and the lever must already be in the schema. The 8-to-12 MB photo estimates in two of the proposals imply 55 to 80 KB per file, which is roughly 0.6 bits per pixel and is not what any of them specified; leaf close-ups are high-frequency and are the worst realistic case for JPEG.

---

## 11. Exit criteria

Module 14 is done when all of these are true, and not before:

1. `dart run tools/kb lint` is green on the committed worked entry, and `dart run tools/kb build --channel release` on that same entry **exits non-zero**, asserted by test.
2. `migration_test.dart` has been run once against `schemaVersion = 1` and **watched to fail**, before being trusted.
3. The trigram search test runs on CI (Linux, libsqlite3-dev) and is not skipped there, with a test that fails if the skip fires under CI.
4. Every case in section 7's matrix passes, including `expectMinTextColumn`.
5. `contrast_test.dart` asserts `scheme.errorContainer == KdColors.dangerBand` and the three badge pairs.
6. A farmer opening `/handbook` on a 320×640 device at scale 2.0 in Nepali can reach the worked entry's "Do this now" list in two taps, with no overflow and no truncated word.
7. The two photos from item 0 exist, are licensed, and pass the release-channel gate. **Without them the code ships and degrades honestly, but the module's headline feature is an empty grid, and that is not a close.**