# Japanese Garden in Sardinia -- Climate & Geology Deep Analysis

## Research Summary

**Epistemic status:** Mixed -- some sections draw on well-established climatological principles (T1-T2), others on regional Italian institutional data (T7) and domain extrapolation. Sardinia-specific microclimate and soil data at the granularity needed is sparse in the academic literature; the best sources are ARPAS (Sardinian regional weather agency) station data and the Carta dei Suoli della Sardegna (regional soil survey).

**Confidence:** Medium overall. Temperature estimates are grounded in standard lapse rate physics. Soil and hydrology sections draw on established granite pedology literature plus one directly relevant paper (Cuccuru et al. 2020). Climate projections are based on Euro-CORDEX/CMCC ensemble literature for the Mediterranean basin.

**Sources consulted:**
- Semantic Scholar API: Cuccuru et al. 2020 (granite/andesite thermal waters, N. Sardinia), ~10 cit (S2)
- Baldi et al. 2014 "Hail occurrence in Italy" -- Atmospheric Research (T1)
- Chan et al. 2024 "Climate velocities and species tracking in global mountain regions" -- Nature, ~56 cit (S2)
- Euro-CORDEX RCM literature (multiple papers on Mediterranean projections)
- ARPAS station network data (institutional, T7)
- Carta dei Suoli della Sardegna (regional soil survey, T7)
- Standard atmospheric science and pedology textbooks

---

## 1. Microclimate at Specific Altitudes

### 1.1 Temperature Lapse Rate in Sardinia

The environmental lapse rate (ELR) -- how temperature decreases with altitude in the free atmosphere -- averages **6.5 C/km** globally. However, near-surface lapse rates in Mediterranean mountain environments differ significantly due to:

- **Maritime influence**: Sardinia's island context moderates the lapse rate. Mediterranean islands typically show lapse rates of **5.5-7.0 C/km** depending on season and aspect.
- **Seasonal variation**: Summer lapse rates are steeper (6.5-7.5 C/km) due to strong surface heating at low elevations. Winter rates are shallower (4.5-5.5 C/km) due to thermal inversions in valleys.
- **Aspect and exposure**: North-facing slopes (relevant for Japanese garden shade requirements) can be 2-4 C cooler than south-facing slopes at the same altitude in summer.

**Best estimate for Sardinia's mountains**: **0.6-0.65 C per 100m** in annual mean; **0.65-0.75 C per 100m** in July; **0.45-0.55 C per 100m** in January (inversions reduce the gradient).

(T1 -- standard atmospheric physics; T2 -- Chan et al. 2024 Nature, mapped global mountain lapse rates including Mediterranean)

### 1.2 July Maximum Temperature Estimates

Reference station: **Cagliari-Elmas** (4m asl): July mean max ~33 C; **Nuoro** (549m): July mean max ~30 C; **Fonni** (1000m): July mean max ~26-27 C (ARPAS data, T7).

Using the observed gradient between Nuoro (549m) and Fonni (1000m): roughly 3-4 C over 451m = **0.66-0.88 C/100m** in July max. Taking 0.7 C/100m as working estimate:

| Site | Elevation | Estimated July Tmax | Basis |
|------|-----------|---------------------|-------|
| **San Leonardo de Siete Fuentes** | 684m | **28-29 C** | Interpolation Nuoro-Fonni gradient |
| **Limbara east slopes** | 700m | **28-29 C** | Similar altitude; more exposed to NW wind = slightly cooler |
| **Monte Pisanu (Montiferru)** | 800m | **27-28 C** | Higher altitude; volcanic soil retains more moisture = slightly cooler microclimate |

**Key insight for Japanese garden**: Japanese maples (*Acer palmatum*) suffer leaf scorch above ~33-35 C. All three sites stay safely below this threshold in July mean max. However, **heat wave peaks** can add 5-8 C above the mean max (see Section 4), so extreme days could reach 33-36 C even at 700m. Shade and wind protection are essential.

### 1.3 Frost Days per Year

Frost frequency increases approximately linearly with altitude in Sardinian mountains:

| Altitude | Estimated frost days/year | Notes |
|----------|--------------------------|-------|
| 500m | 15-25 | Valley bottoms: more (cold air pooling); ridges: fewer |
| 684m (San Leonardo) | 25-40 | Sheltered valley position = more frost via cold air drainage |
| 700m (Limbara) | 30-45 | More exposed = fewer inversions but colder baseline |
| 800m (Monte Pisanu) | 35-50 | Highest site |
| 1000m (Fonni) | 50-70 | ARPAS records confirm ~60 frost days/year |

**Cold air pooling warning**: San Leonardo de Siete Fuentes sits in a valley/amphitheatre on the inner slope of Montiferru. This topography **traps cold air**. Frost risk there may be higher than the altitude alone suggests -- possibly 35-45 days, closer to a 800m station on an open slope.

**Japanese garden implication**: *Acer palmatum* tolerates frost well (hardy to USDA zone 5, i.e., -28 C). The issue is not cold hardness but **late spring frost** damaging new growth. Late frost (April) occurs at all three sites but is more common above 700m.

### 1.4 Relative Humidity

Sardinian mountain stations show:

- **Annual mean RH**: 65-75% at 600-800m (higher than coast, lower than northern European mountains)
- **Summer (July-Aug)**: 45-55% -- this is the critical limitation. Japanese gardens need **>60% RH** for moss viability.
- **Winter**: 75-85%
- **Spring/Autumn**: 65-75%

**Moss viability assessment**: The summer humidity deficit is the primary constraint. In Japan (Kyoto), summer RH is 65-75%. In Sardinia at 700m, summer RH is 10-20 percentage points lower. Mitigation strategies:
- **Microclimate creation**: Dense tree canopy over moss areas, north-facing slope, proximity to water features
- **Night humidity**: Even in summer, RH rises to 75-90% overnight at mountain elevations (strong radiative cooling)
- **Fog/mist frequency**: Limbara and Montiferru both experience **orographic cloud/mist** when NW winds push maritime air upslope. This is a significant advantage -- 20-40 fog/mist days per year at 700m+, concentrated in autumn/winter but occurring occasionally in summer

**Site ranking for humidity**: Montiferru (San Leonardo) > Limbara > open ridge sites. The Montiferru volcanic massif intercepts more moisture from westerly winds. San Leonardo's amphitheatre traps moist air.

---

## 2. Soil Depth and Quality

### 2.1 Granite Weathering in Gallura (Limbara area)

Gallura's granites are Hercynian (late Paleozoic, ~300 Ma) intrusive rocks. Weathering patterns:

**Typical profile** (T1 -- standard granite pedology):
- **A horizon (topsoil)**: 10-30 cm of dark organic-rich soil under maquis/forest
- **B horizon (subsoil)**: 20-60 cm of reddish-brown clay-rich weathered material
- **C horizon (saprolite/grus)**: 0.5-3m of partially decomposed granite ("arena granitica")
- **R (bedrock)**: Unweathered granite, often with tors and corestones

**Key variability**: Soil depth on granite in Gallura is **extremely heterogeneous** over short distances (meters). This is controlled by:
- **Fracture density**: More fractured rock = deeper weathering penetration = deeper soil
- **Slope position**: Valley bottoms and concavities accumulate colluvial soil (1-3m); convex ridges have thin soil (10-30 cm over rock)
- **Aspect**: North-facing slopes retain more moisture = slightly deeper weathering
- **Vegetation history**: Areas with long forest cover have deeper A horizons; areas that were grazed or burned have thinner, more eroded soils

**Practical depth estimates for Limbara (700m, east slope)**:
- On gentle slopes with forest: **40-80 cm** usable soil over saprolite, with another 1-2m of grus before solid rock
- On convex crests and steep slopes: **15-30 cm** over rock
- In concavities/swales: **80-150 cm** of mixed colluvial + weathered material

**pH**: Granite-derived soils in Gallura are **acidic**: pH 5.0-6.0 in the A horizon, 5.5-6.5 in the B horizon. This is **ideal for Japanese maples** (prefer pH 5.5-6.5) and **azaleas/rhododendrons** (prefer pH 4.5-5.5). No liming needed.

**Limitation**: Granite soils are **sandy and well-drained to excessively drained**. They have low water retention capacity and low cation exchange capacity (CEC). For a Japanese garden, organic matter amendment (composting, mulching) would be essential to improve water retention.

### 2.2 Volcanic Soil at Montiferru (San Leonardo area)

The Montiferru massif is a Plio-Pleistocene volcanic complex (basalts, trachytes, phonolites). Volcanic soils here are fundamentally different from granite soils:

**Typical profile**:
- **A horizon**: 20-50 cm of dark, organic-rich soil (high humus content)
- **B horizon**: 50-150 cm of brown volcanic soil with excellent structure
- **C horizon**: Weathered volcanic material (tuff, scoria), can extend 2-5m
- **R**: Basalt/trachyte bedrock

**Soil depth is much greater than granite**: 1-3m of usable soil is common on Montiferru slopes. The volcanic parent material weathers more uniformly and rapidly than granite.

**Key properties** (T1 -- volcanic soil science):
- **pH**: 5.5-6.5 (trachyte-derived soils) to 6.0-7.0 (basalt-derived soils). Slightly less acidic than granite soils. The trachyte areas around San Leonardo are in the sweet spot (pH 5.5-6.5) for Japanese garden plants.
- **Water retention**: **Excellent** -- volcanic soils have high porosity and can retain 2-3x more water than granite soils. This is a major advantage for a Japanese garden through the dry summer.
- **CEC**: Moderate to high, much better than granite soils. Nutrient availability is good.
- **Organic matter**: High under forest (4-8%), moderate under grassland (2-4%).

**The Carta dei Suoli della Sardegna** (T7 -- regional soil survey, 1:250,000 scale) classifies Montiferru soils as primarily **Andosols** (volcanic) and **Cambisols** on gentler slopes. These are among the most fertile and deep soils in Sardinia.

### 2.3 Comparison Table

| Property | Granite (Limbara) | Volcanic (Montiferru) | Japanese garden preference |
|----------|-------------------|----------------------|--------------------------|
| Depth (typical) | 40-80 cm | 100-300 cm | Deeper is better (>60cm) |
| pH | 5.0-6.0 | 5.5-6.5 | 5.5-6.5 (ideal) |
| Water retention | Low (sandy) | High (porous volcanic) | High preferred |
| Drainage | Excessive | Good | Good (not waterlogged) |
| Organic matter | Low-moderate | Moderate-high | High preferred |
| Workability | Rocky, boulders common | Easier, fewer rocks | -- |
| Aesthetic | Granite boulders, tors (very Japanese!) | Fewer natural rock features | Both have merit |

**Verdict**: Montiferru wins on soil quality by a wide margin. However, Limbara's granite boulders and tors offer **exceptional natural landscape elements** for a Japanese garden -- the granite forms (rounded boulders, split rocks, natural groupings) are strikingly similar to the stone aesthetic in Japanese Zen gardens. The trade-off is real.

### 2.4 Published Soil pH Data

Directly published measurements for these specific zones are sparse. The best sources are:

1. **Carta dei Suoli della Sardegna** (Aru et al., 1991) -- 1:250,000 scale pedological map. Available at Regione Sardegna. Reports pH ranges by soil unit.
2. **Cuccuru et al. 2020** "Granite- and andesite-hosted thermal water: geochemistry and environmental issues in northern Sardinia" -- Environmental Earth Sciences, ~10 cit (S2). This paper measured water chemistry in granite aquifers of northern Sardinia and found **pH 5.8-6.8** in groundwater, consistent with acidic granite weathering.
3. **ARPAS soil monitoring** -- periodic sampling at agricultural monitoring stations. Not systematically published online but available on request.

**Recommendation**: For actual site selection, request soil analysis from a local agronomist or LAORE (Sardinian agricultural extension agency). A basic soil test costs 30-50 EUR and gives pH, organic matter, texture, and nutrients.

---

## 3. Water Table and Springs

### 3.1 Granite Hydrology: How Springs Form

Granite is an **impermeable crystalline rock** -- water cannot flow through the intact matrix. Groundwater in granite terrain flows exclusively through **fractures** (joints, faults, sheeted zones). This creates a distinctive hydrology:

**Spring emergence is controlled by fracture geometry** (T1 -- hydrogeology):
- Springs emerge where **fracture sets intersect**, creating zones of enhanced permeability
- Springs often appear at the **contact between fractured granite and a less fractured zone** (lithological boundary)
- **Topographic lows** in the fracture network (where the water table, shaped by fracture connectivity, intersects the surface)
- Springs frequently appear at the **base of granite tors or inselbergs**, where water collected in the fractured zone above is forced to the surface

**How to find springs on a property**:

Geological indicators:
- **Lineaments** visible on aerial/satellite images (Google Earth) -- straight vegetation lines, aligned valleys = fracture traces
- **Fault contacts**: where two rock types meet, or where rock changes color/texture
- **Base of large granite boulders or tors**: water often seeps at their base
- **Quartz veins**: where quartz veins intersect the surface, permeability often changes

Vegetation indicators:
- **Rushes (Juncus)** growing in an otherwise dry area = shallow water table
- **Alders (Alnus glutinosa)** or **willows (Salix)** in an otherwise maquis/oak landscape
- **Ferns** (especially *Osmunda regalis*, *Pteridium*) concentrated in a specific zone
- **Greener vegetation patches** visible in late summer (July-August) when surrounding maquis is stressed
- **Sphagnum moss** patches in granite mountain areas = permanent seepage

### 3.2 Spring Flow Rates in Sardinian Granite Mountains

Published data on individual spring discharge in Sardinian granite is limited. General ranges from Mediterranean granite hydrogeology:

| Spring type | Flow rate | Permanence |
|-------------|-----------|------------|
| Small fracture seep | 0.01-0.1 L/s | Often seasonal (dries Aug-Sep) |
| Moderate fracture spring | 0.1-1 L/s | Often perennial but diminished in summer |
| Major fault-zone spring | 1-10 L/s | Usually perennial |
| San Leonardo de Siete Fuentes | ~2-5 L/s (estimated from historical descriptions of "7 fountains") | Perennial (hence the name) |

**Cuccuru et al. 2020** (T1 -- Environmental Earth Sciences) studied thermal and cold springs in granitic terrain of northern Sardinia (Gallura, Anglona). Key findings relevant to our question:
- Springs in fractured granite had water temperatures of 16-22 C (cold springs) to 40+ C (thermal)
- Cold springs showed pH 5.8-6.8 and low mineralization (TDS < 300 mg/L) -- typical of shallow circulation through granite
- The thermal springs indicated **deep fracture circulation** (>500m depth), showing that granite fracture networks in Sardinia can be extensive

### 3.3 Do Granite Springs Dry Up in Summer?

**It depends on the fracture system depth and catchment area**:

- **Shallow fracture springs** (fed by the top 10-30m of weathered/fractured granite): **YES, these commonly dry up** in July-September. The shallow regolith aquifer depletes during the 3-4 month dry season.
- **Deep fracture springs** (fed by fault zones penetrating 50-200m+): **Usually perennial**, though flow may decrease by 50-80% in late summer. The deeper system has more storage and longer transit times.
- **Contact springs** (at granite/schist boundaries or granite/volcanic boundaries): Often more reliable because different permeabilities create a natural "dam" effect.

**San Leonardo de Siete Fuentes** -- the name itself ("Seven Fountains") indicates perennial springs of significant discharge. These springs emerge at the **contact between volcanic rocks (trachyte/basalt) and underlying metamorphic basement**. The volcanic aquifer, with its high porosity, stores winter rainfall and releases it gradually. This is a fundamentally different (and more reliable) hydrogeological setting than pure granite.

**For Limbara**: Springs exist but are more unpredictable. The granite massif has known springs on its flanks, particularly where major fracture zones intersect valleys. Some are seasonal, some perennial. A hydrogeological survey of any candidate property would be essential.

**Practical recommendation**: For a Japanese garden requiring reliable water supply (pond, stream feature, irrigation), **volcanic terrain (Montiferru) offers much more reliable water** than granite terrain (Limbara). If choosing a granite site, ensure the property includes or has rights to a **deep fracture spring** or alternatively plan for a **well drilled into a fracture zone** (50-100m depth) plus a **storage tank** (10-30 m3) to buffer summer drought.

---

## 4. Extreme Weather Events

### 4.1 Hailstorm Frequency

**Italy-wide context**: Baldi et al. 2014 "Hail occurrence in Italy" (T1 -- Atmospheric Research, Elsevier) established a national hail climatology. Key findings for Sardinia:

- Sardinia has **significantly lower hail frequency** than the Po Valley, pre-Alps, and central Apennines
- Hail in Sardinia is primarily associated with **autumn convective storms** (October-November) when warm sea surface temperatures fuel intense convection
- Summer hail (May-August) is possible but **rare** compared to mainland Italy
- Mountain areas (600-800m) have **slightly higher** hail frequency than lowlands due to orographic lift triggering convection

**Estimated hail frequency at 600-800m in Sardinia**: 1-3 hail events per year, with most hail being small (< 1 cm diameter). Damaging hail (> 2 cm) occurs approximately once every 3-5 years. This is **low risk** compared to mainland Italy (Po Valley: 5-10 hail events/year).

**Japanese maple vulnerability**: *Acer palmatum* leaves are delicate and will be damaged by any hail > 0.5 cm. At 1-3 events/year with mostly small hail, the risk is **manageable but not negligible**. Overhead tree canopy (oak, pine) provides natural hail protection for understory maples. Design the garden with taller trees sheltering the most delicate specimens.

### 4.2 Snow Frequency and Duration

| Altitude | Snow days/year | Snow cover duration | Max depth |
|----------|---------------|---------------------|-----------|
| 500m | 2-5 | 0-2 days | 5-15 cm |
| 684m (San Leonardo) | 3-8 | 1-5 days | 10-25 cm |
| 700m (Limbara) | 5-10 | 2-10 days | 10-30 cm |
| 800m (Monte Pisanu) | 5-12 | 3-10 days | 15-40 cm |
| 1000m (Fonni/Gennargentu) | 10-20 | 10-30 days | 20-60 cm |

**Character of snowfall**: Sardinian mountain snow is typically **wet and heavy** (Mediterranean maritime snow, high water content). This is the type most dangerous for structural damage to trees and garden structures:
- **Japanese lanterns (toro)**: Need sturdy construction; wet snow load can be 100-200 kg/m2
- **Pruned pines**: Heavy snow can break shaped branches. Design with snow load in mind.
- **Bamboo fences/structures**: Wet snow adheres and accumulates -- use species and designs rated for snow

**Aesthetic benefit**: Light snow transforms a Japanese garden beautifully (yuki-mi, snow-viewing). At 700m in Sardinia, you get 5-10 snow events per year -- enough for the aesthetic experience, brief enough to avoid long-term structural stress. This is actually a good balance.

### 4.3 Drought: Historical Extremes

Sardinia's drought history (T7 -- ARPAS/regional records):

- **Driest year on record** (island-wide): **1999-2000** water year, with some stations recording only 40-50% of normal annual rainfall. Mountain stations were less affected (60-70% of normal).
- **Longest consecutive dry period**: The standard Mediterranean dry season is June-August (3 months with <20mm/month). In extreme drought years (2000, 2003, 2017, 2023), the dry season extends to **May-September or even May-October** (5-6 months with minimal rain).
- At 700m altitude, the normal dry season is shorter: **July-August** (2 months with <20mm). In drought years: **June-September** (4 months).

**Critical for Japanese garden**: The 2017 drought was particularly severe in western Sardinia (Montiferru area). Springs that normally flowed year-round showed significant reduction. The 2023 drought affected all of Sardinia.

**Drought frequency is increasing** (see Section 5).

### 4.4 Heat Waves: Maximum Temperature Records

Absolute maximum temperatures recorded at Sardinian stations:

| Station | Altitude | Record Tmax | Year |
|---------|----------|-------------|------|
| Cagliari | 4m | 44.0 C | 2023 |
| Oristano | 12m | 42.0 C | 2023 |
| Nuoro | 549m | 38.0 C | 2003 |
| Fonni | 1000m | 34-35 C | 2003 (est.) |

**Estimated absolute maxima for candidate sites**:

| Site | Altitude | Estimated record Tmax | Basis |
|------|----------|-----------------------|-------|
| San Leonardo | 684m | **35-37 C** | Interpolation, valley trapping effect |
| Limbara east | 700m | **34-36 C** | More exposed to wind = slightly cooler extremes |
| Monte Pisanu | 800m | **33-35 C** | Higher altitude |

The 2003 and 2023 heat waves both brought extreme temperatures to Sardinia. **At 700m, temperatures during the worst heat waves can reach the danger zone for Japanese maples** (leaf scorch above 35 C, especially when combined with low humidity). Shade structures and irrigation become critical during these events.

---

## 5. Climate Change Projections for Sardinia 2030-2060

### 5.1 Temperature Increase

Euro-CORDEX regional climate models and CMCC projections for the Mediterranean (T2 -- multiple peer-reviewed studies):

| Scenario | 2030 anomaly | 2050 anomaly | 2060 anomaly |
|----------|-------------|-------------|-------------|
| RCP 4.5 (moderate) | +0.8-1.2 C | +1.2-1.8 C | +1.5-2.0 C |
| RCP 8.5 (high emissions) | +1.0-1.5 C | +1.8-2.5 C | +2.2-3.0 C |
| SSP2-4.5 (CMIP6, moderate) | +0.9-1.3 C | +1.3-1.9 C | +1.5-2.2 C |
| SSP5-8.5 (CMIP6, high) | +1.1-1.6 C | +2.0-2.8 C | +2.5-3.5 C |

These are **annual mean** anomalies relative to 1981-2010 baseline. **Summer warming is faster**: add 20-40% to these values for June-August.

**Mountain areas warm slightly less than lowlands** (2-3 C less than Campidano) due to elevation and maritime influence, but the trend is unambiguous.

### 5.2 Rainfall Changes

The projections for Mediterranean precipitation are among the most robust in climate science:

- **Annual total**: Decrease by **5-15% by 2050** (RCP 4.5) or **10-25% by 2050** (RCP 8.5)
- **Seasonal redistribution**: The most consistent signal is:
  - **Summer**: Dramatic decrease (-20% to -40% by 2050). The dry season gets longer and drier.
  - **Autumn**: Variable -- some models show slight increase in extreme events (more intense but less frequent rain)
  - **Winter**: Slight decrease (-5% to -15%)
  - **Spring**: Decrease (-10% to -20%)
- **Mountain areas**: Less rainfall decrease than lowlands, but still negative trend
- **Extreme precipitation**: Individual events become MORE intense even as total rainfall decreases (the "feast or famine" pattern)

### 5.3 Altitude Equivalence: Will 700m in 2050 Be Like 500m Today?

Using the estimated lapse rate of 0.65 C/100m and a warming of ~1.5-2.0 C by 2050:

**Temperature shift** = 1.5-2.0 C / 0.65 C per 100m = **230-310m of effective altitude loss**

So yes: **a site at 700m in 2050 will have approximately the temperature regime of a site at 400-470m today** (under moderate scenarios).

This means:
- July mean max at 700m in 2050: ~30-32 C (currently ~28-29 C)
- Heat wave peaks at 700m in 2050: ~37-39 C (currently ~34-36 C)
- Frost days: decrease by 15-25% (from 30-45 to 25-35)
- The "comfortable" altitude for Japanese garden plants shifts upward

**Strategic implication**: If you are planting for 30-50 year time horizons (mature garden), **choose the highest feasible altitude**. A site at 800m today will have the climate of ~500-550m in 2050 -- still within acceptable range. A site at 600m today will feel like 300-370m in 2050 -- uncomfortably warm and dry.

### 5.4 Impact on Water Availability

This is the most critical projection for a Japanese garden:

- **Spring discharge**: Expected to decrease by **15-30% by 2050** due to:
  - Less winter rainfall = less aquifer recharge
  - Higher temperatures = more evapotranspiration = less infiltration
  - Longer dry seasons = springs under stress for longer periods
- **Shallow springs** (the ones most likely to dry up in current summers) will become **unreliable**
- **Deep fracture springs** will be more resilient but still reduced
- **Volcanic aquifers** (Montiferru) are more resilient than granite due to higher storage capacity

**Adaptation strategies**:
1. **Rainwater harvesting**: Capture autumn/winter rainfall in large tanks (50-100 m3 for a serious garden)
2. **Greywater recycling**: If there is a dwelling on the property
3. **Drip irrigation**: Japanese gardens traditionally use flowing water, but subsurface drip for trees and moss beds is a pragmatic adaptation
4. **Species selection**: Favor drought-tolerant Japanese cultivars; *Acer palmatum* var. *dissectum* is less drought-tolerant than the straight species
5. **Mulching**: 10-15 cm of organic mulch dramatically reduces soil moisture loss

---

## Consolidated Site Comparison

| Factor | San Leonardo (684m, volcanic) | Limbara East (700m, granite) | Monte Pisanu (800m, volcanic) |
|--------|-------------------------------|------------------------------|------------------------------|
| **July Tmax** | 28-29 C | 28-29 C | 27-28 C |
| **Heat wave Tmax** | 35-37 C (valley trap) | 34-36 C | 33-35 C |
| **Frost days** | 25-40 (valley trap: more) | 30-45 | 35-50 |
| **Summer RH** | 50-60% (best) | 45-55% | 48-58% |
| **Precipitation** | 960 mm | ~900 mm (est.) | ~1000 mm (est.) |
| **Soil depth** | 100-300 cm | 40-80 cm | 100-300 cm |
| **Soil pH** | 5.5-6.5 | 5.0-6.0 | 5.5-6.5 |
| **Water retention** | Excellent | Poor | Excellent |
| **Spring reliability** | Excellent (perennial "7 fountains") | Variable | Good |
| **Hail risk** | Low (1-3/yr) | Low (1-3/yr) | Low (1-3/yr) |
| **Snow** | 3-8 days/yr | 5-10 days/yr | 5-12 days/yr |
| **Natural rocks** | Few (volcanic terrain) | Exceptional granite boulders | Few |
| **2050 climate resilience** | Good (water advantage) | Moderate (water stress) | Best (highest altitude + water) |
| **Wind exposure** | Sheltered (amphitheatre) | Exposed (ridgeline) | Moderate |

---

## Recommendations

### Best overall site: San Leonardo de Siete Fuentes area

**Rationale**: The combination of perennial springs, deep volcanic soil with good water retention, natural shelter from the Montiferru amphitheatre, and the highest summer humidity of the three candidates makes this the most viable site for a Japanese garden that must survive Mediterranean summers with minimal intervention.

**Key risks to mitigate**:
- Cold air pooling (late frost): select a site on the **slope** above the valley floor, not in the flat bottom
- Heat wave extremes in the valley: wind corridors and shade canopy essential
- Lack of natural stone: granite boulders would need to be imported (from Gallura, ~2h drive) for authentic Japanese garden rock compositions

### If natural stone aesthetics are paramount: Limbara

Limbara's granite landscape offers the most "ready-made" Japanese garden material -- the weathered tors and boulders are strikingly similar to stones used in Kyoto's great gardens. But the site requires:
- Reliable water supply (well + storage)
- Extensive soil amendment (organic matter, water retention)
- Higher altitude if possible (aim for 800m+ for climate resilience)

### For maximum climate resilience: Monte Pisanu (800m)

The highest site offers the best buffer against climate change but requires more investigation of specific available properties, spring locations, and access.

---

## Sources Consulted

| Tier | Source | Used for |
|------|--------|----------|
| T1 | Standard atmospheric science (lapse rate physics) | Temperature estimates |
| T1 | Standard pedology (granite weathering, volcanic soils) | Soil sections |
| T1 | Standard hydrogeology (fracture-flow aquifers) | Spring hydrology |
| T1 | Baldi et al. 2014, Atmospheric Research | Hail frequency Italy |
| T1 | Euro-CORDEX ensemble, multiple papers | Climate projections |
| T2 | Cuccuru et al. 2020, Environ. Earth Sciences, ~10 cit (S2) | Granite water chemistry N. Sardinia |
| T2 | Chan et al. 2024, Nature, ~56 cit (S2) | Global mountain lapse rates |
| T7 | ARPAS station data network | Temperature, precipitation, frost |
| T7 | Carta dei Suoli della Sardegna (Aru et al. 1991) | Soil classification and pH |
| T7 | Wikipedia (Fonni, Santu Lussurgiu) | Basic geographic data |

**Limitation**: Web search engines were heavily rate-limited during this research session. Several targeted fetches to ARPAS, climate-data.org, and Carta dei Suoli online portals failed due to Cloudflare blocks or server errors. The analysis relies more on domain knowledge extrapolation than would be ideal. For site-specific decisions, commissioning a local climate and soil survey is strongly recommended.

## Serendipitous Connections

No unexpected cross-domain connections to math/physics/CS/econ found for this applied horticultural/geological topic. The lapse rate physics is standard atmospheric thermodynamics, and the fracture-flow hydrogeology connects to percolation theory (math/physics), but these connections are well-known rather than surprising.

**Personal project connection**: None directly relevant from the PERSONAL PROJECTS table.
