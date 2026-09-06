# ADR-0057: Compare supported crops against the seven-day city forecast without prescribing a crop

- **Status:** accepted
- **Decision id:** D-57
- **Date:** 2026-08-24
- **Owners:** Product + Eng (Agri and native-language review gates remain open)
- **Amends:** D-56's weather boundary; it does not relax the prohibition on forecast-only agronomic decisions

## Context

Farmers asked which crop fits the weather in a selected place. The app already
retrieves a seven-day Open-Meteo forecast for seven explicit Nepal city-centre
presets and supports tomato, potato and maize. A seven-day city forecast does
not establish field suitability: crop cycles are longer, and the result still
depends on soil, drainage, elevation, irrigation, variety, crop stage, local
planting calendar, disease pressure and the farmer's objective.

FAO EcoCrop publishes transparent optimal temperature ranges for the three
supported crops: tomato 20–27 °C, potato 15–25 °C and maize 18–33 °C. Those
ranges can support a narrow comparison, but not a planting, yield, treatment or
selling recommendation.

## Decision

Add a deterministic **7-day crop weather fit** comparison to the Weather
screen. It:

- compares each forecast day's mean of minimum and maximum temperature with
  the bundled FAO EcoCrop optimal range for tomato, potato and maize;
- ranks only those three supported crops and labels each fit as favourable,
  mixed or weak using a source-controlled, tested rule;
- shows forecast rain, peak wind and thunderstorm-day counts as factual context
  without using them to manufacture crop-specific agronomy;
- names both sources and keeps the missing field factors visible beside the
  result; and
- never changes the farmer's selected crop, creates work automatically, or
  claims that a crop should be planted, will succeed, or will yield well.

No new live API is added for this release. Reusing the already-fetched forecast
avoids a second network failure mode and keeps the result available with the
last visible forecast. NASA POWER is a useful future source for longer climate
history, but climate history still would not supply plot soil, irrigation,
variety or local validation. SoilGrids' maintainers currently advise against
farm-level use and have paused the beta REST service, so it is not a production
dependency.

## Rationale

**Why a comparison instead of a recommendation.** The result answers the useful
part of the request—how the next seven days' temperatures compare—without
hiding the evidence gap behind a precise-looking score.

**Why no AI label.** The calculation is a small auditable rule over published
ranges. Calling it AI would make the feature sound more capable without making
it more accurate.

**Why temperature determines rank.** EcoCrop's rainfall values are annual and
cannot honestly be converted into a seven-day planting threshold. Rain, wind
and storms remain visible planning context, but do not affect the crop order.

## Consequences

The Weather screen gains an immediately useful crop comparison with no extra
permission, credential or network request. It remains city-level and can be
wrong for a particular field. The bundled ranges and drafted Nepali/Hindi copy
require agronomist and native-language review before a field pilot.

Now forbidden:

- naming the result simply "crop recommendation" or "best crop to plant";
- exposing a percentage score that implies calibrated agronomic confidence;
- ranking additional crops without a reviewed profile and source;
- deriving pesticide, irrigation, fertiliser, planting-date, yield or market
  actions from the result; or
- removing the source and missing-input disclosure from the result surface.

Re-open this ADR when exact plot location/elevation, crop calendar, soil and
water inputs, longer climate history, Nepal-specific agronomy review and field
validation can support a genuinely decision-grade suitability model.

## Sources

- FAO EcoCrop tomato data sheet: https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=1379
- FAO EcoCrop potato data sheet: https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=1971
- FAO EcoCrop maize data sheet: https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=2175
- Open-Meteo forecast documentation: https://open-meteo.com/en/docs
- NASA POWER API documentation: https://power.larc.nasa.gov/docs/services/api/
- SoilGrids access notice: https://docs.isric.org/globaldata/soilgrids/SoilGrids_faqs_02.html
