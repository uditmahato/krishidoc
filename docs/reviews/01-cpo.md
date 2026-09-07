# Chief Product Officer Review (Module 12 pre-review)

VERDICT: an unusually well-built machine with no product attached. Eleven modules delivered zero user-reachable value: three of four home tiles say "coming soon", the fourth opens a History list structurally guaranteed to stay empty forever (records only exist via kDebugMode flows). The deeper problem is sequencing: everything built so far is plumbing converging on a diagnosis that cannot happen, while the register's own top risk (R1, KB editorial throughput) has zero code and zero content against it.

## Top findings

1. **No path to value; "coming soon" is doing the work of a product.** home_screen.dart:59-72 default snackbar at :107-111; history_screen.dart:28-34 always empty; 2 of 4 routes are dev surfaces. A 17.9 MB download that says "coming soon" three times burns the one install attempt you get. FIX: delete the coming-soon default so a dead tile cannot be added by omission; gate unbuilt tiles out of the tree entirely. S / High.

2. **A confident diagnosis gives a name and nothing to do.** diagnosis_result_view.dart:32-48 renders only diseaseName + certainty chip. Uncertain and out-of-scope both carry an action; the SUCCESS case is the only dead end. Only one certainty band exists in ARB. FIX: make treatment actions a REQUIRED field of ConfidentDiagnosis so a name-only result is a compile error, exactly as certainty already is. M app / L with content / High.

3. **Roadmap sequences identity and sync ahead of the top risk.** Module 10 shipped token rotation and reuse detection protecting data that does not exist, while LaunchCropCatalog is still 3 hardcoded keys. Content throughput is the risk you cannot buy your way out of late. FIX: move advisory/content ahead of sync/identity/consent; freeze backend identity until a shipped feature makes a network call. S / High.

4. **Home grid overflows in ne/hi at large font scale.** childAspectRatio: 1.2 (home_screen.dart:52) fixes tile height from width: ~113dp tile, ~96dp usable text on a 320dp phone. "रोग पहिचान गर्नुहोस्" at 200% wraps to three tall Devanagari lines and does not fit. The comment at :34-36 claims the ListView fixed V1's font-scaling finding: it fixed the page, not the tile. FIX: intrinsic-height tiles or single column above a scale threshold. Strategically: stop opening onto a launcher grid; open onto the farmer's crop context. S / M / High.

5. **"Ask a nearby crop expert" is a no-op** (result_preview_screen.dart:33) and the clinic directory that docs/seams/clinics.md:7 says "ships early" does not exist. Highest value per engineering hour in the product: needs no model, no server, no connectivity. FIX: bundled localized directory, tap-to-call, verified-on dates, as a first-class home destination. M / High.

6. **History is unreadable and untappable.** ListTile with no onTap, titled with the raw classifier key; DiagnosisRecord.imagePath is ignored. A farmer's mental index is visual. Retention lives here. FIX: thumbnail, KB display name, tap into detail with photo + advice given at the time. M / Med-High.

7. **Coaching tells farmers to do impossible things.** "Move somewhere brighter" / "Step out of direct sunlight" (app_en.arb:28-29) but the plant is in the ground, and there is no torch control on the CameraSession port. FIX: "Shade the leaf with your hand", "Turn on the light", plus a torch toggle. S copy / M with torch / Med.

8. **The app never states its coverage,** contradicting the principle written in launch_crop_catalog.dart:6-8. Only the debug capture screen shows it. Also no first-run language chooser: cheap handsets ship configured in English, so a Nepali user meets an English app and an unlabeled globe icon. FIX: plain coverage line on Home; first-run language screen with three large targets. S each / Med.

## Cut or defer
- **Cut the chatbot** from the near-term roadmap and the home grid: most expensive, highest-risk, least-offline feature, aimed at users on poor connectivity. Ship the offline KB search D-05 already promises, call it "Search", let that be the whole feature for a year.
- **Cut the Settings tile:** one setting exists and it is already in the app bar.
- **Defer backend identity, sync, consent** until a shipped feature makes a network call. Keep the model pack delivery path warm.
- **Defer the portals except the content authoring and agronomist review tool**, which is the only one that attacks R1.
- **Challenge:** replace the "Prepared N bytes" debug readout with the real OutOfScopeDiagnosis card today. Same effort, and the capture screen becomes one wire from shipping instead of one wire plus an unbuilt UI.

## The one thing to do next
**Ship KrishiDoc as an offline crop disease handbook, before any model exists.** Three crops x ~8 diseases, en/ne/hi, bundled via Play Asset Delivery so it works in airplane mode. Browsable by crop AND by what the farmer can see (spots, wilting, yellowing, holes, rot). Reference photo, plain-language symptoms, IPM-first actions, active-ingredient card. Clinic directory with tap-to-call alongside.

Five things it buys: converts a zero-value app into a real one; forces the top risk (editorial throughput) to be exercised while discovering a 3x overrun is still survivable; produces the exact assets the model release depends on (KB display names for History, treatment cards for the empty confident result, entry ids for citations); gives something to put in front of farmers to learn from; and repositions the camera correctly as an accelerator to a product that already works without it.

Test to hold to: a farmer with no signal, standing in a field, holding a diseased leaf, can find out what it probably is and what to do, in Nepali, in under a minute. Nothing in that sentence requires machine learning.

## Queue
- Plant photo journal (capture with crop tag, no diagnosis; seeds the D-20 flywheel; honest cost: a fourth sealed state, L not free)
- Gallery import (also the cheaper capture path on a 1 GB device)
- Audio playback of advice (D-35 already reserves human audio packs; may matter more than any text refinement)
- Season and calendar context ("common right now in your area", no ML needed)
- Dark or outdoor high-contrast mode (only kdLightTheme exists)
- Honest startup failure surface (locked or corrupt DB is currently a black screen)
