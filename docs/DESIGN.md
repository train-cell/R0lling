# R0lling — Bevel-inspired wellness design system

R0lling uses the visual language of the Bevel reference screens in `C:\Users\skyd3\antigarvity\ui understanding\IMG_0475.png`–`IMG_0490.png`: charcoal canvas, slate cards, rounded metric panels, restrained outlines, periwinkle/lime/amber accents, and a floating capsule navigation bar. The reference folder's `IMG_0491`–`IMG_0497` are separate Dribbble/Mobbin concepts and are not the Bevel target.

Reference-to-UI review remains incomplete: `IMG_0475`–`0477`, `IMG_0481`, and `IMG_0488`–`0489` show onboarding and stress/energy/biological-age/biomarker concepts with no matching source-backed product view or data definition. They remain open UI/feature scope; R0lling does not fabricate values to match them. Source-level styling of the implemented screens does not establish rendered parity.

This is a visual direction for R0lling, not a claim of pixel-level parity. The screenshots show health, fitness, and sleep screens; they do not include a direct equivalent of R0lling's Vault, Studio, or AI screens. Keep R0lling's own content and data contracts, and do not invent wellness readings to fill a visual layout.

## Theme tokens

The source of truth is `Sources/R0lling/UI/Theme.swift`.

| Token | Value | Use |
|---|---|---|
| `bgPrimary` | `#17181C` | Dark charcoal canvas |
| `bgSurface` | `#2A2B32` | Flat control fills and compatibility surfaces |
| `bgElevated` | `#343640` | Nested cards and controls |
| `heroCardGradient` | `#32343D` → `#25262D` | Raised card face used by the shared bevel modifier |
| `R0llingBevelCapsuleModifier` | layered slate face, highlight and lower rim | Raised quick-action and status pills |
| `borderSubtle` | `#41434D` | Quiet outlines and dividers |
| `textPrimary` | `#F5F5F7` | Main content |
| `textSecondary` | `#B9BAC4` | Supporting text |
| `accentPurple` | `#7068E8` | R0lling identity and actions |
| `accentCyan` | `#79AFFF` | Periwinkle/blue metric accent |
| `accentLime` | `#B8E34A` | Activity and focus indicators |
| `accentAmber` | `#F3BD55` | Strain and caution indicators |
| `statusSuccess` | `#62C99A` | Confirmed success/live state |
| `statusError` | `#F17B82` | Error state only |

## Layout and components

- Use a near-black page canvas with slate cards, approximately 20–22pt corner radii, a single quiet directional rim, and one restrained drop shadow. `R0llingBevelSurfaceModifier` handles key cards; `R0llingBevelCapsuleModifier` handles raised pills, including the Assistant quick-action toolbar. Avoid stacked outlines and neon glows.
- Keep page titles prominent and sentence-case. Put the key value first, then unit, date/source, and explanatory detail.
- Use separated circular indicators for independent measures, with an inset dark track, a fine outer rim, and a bright, restrained progress arc. Do not combine metrics with different units into a single ring. Mark heuristic values and unavailable readings clearly.
- The main app navigation uses Today, Journal, Fitness, and Health in a floating capsule, plus a separate circular “more” action. Vault and secondary screens remain reachable through that action.
- Use a stable color and label for each state; never communicate status by color alone.
- New surfaces use Dynamic Type, VoiceOver labels, and at least 44pt touch targets for icon actions.
- Product routes, encrypted data, permissions, and metric calculations must remain connected to their actual implementations; reference screenshots are not backend specifications.
- Settings and edit forms keep familiar iOS controls on raised slate surfaces with the shared directional bevel rim, charcoal canvas, and periwinkle tint. Text inputs inside raised cards use recessed bevel slots.
- The HealthKit card follows Bevel's two-column metric-card rhythm while each tile can retain a readable minimum width; it collapses to one column when the available width is too narrow or at accessibility text sizes. It supports six optional source-backed readings (HRV, resting heart rate, respiratory rate, blood oxygen, body temperature, and sleep duration); each has a vertical display-scale indicator like IMG_0482, explicitly labeled as visual scale only, not a clinical range or recovery score. Sleep detail adds the observed stage timeline plus selectable overnight HR, HRV, RR, and SpO₂ samples clipped to the primary episode; missing channels and gaps stay empty without fabricated or interpolated data. Unavailable values remain unavailable.
- Fitness has a selectable 30-day workout activity calendar and an expandable cumulative workout-duration chart whose unit matches the duration summary and comparison. Selecting a day shows the actual HealthKit workout type, start time, and duration; calendar buckets, query boundaries, and visible labels use the `Europe/Athens` timezone. The trend legend distinguishes the current and previous periods. It shows no synthetic workouts when HealthKit returns no samples. The former wellness hub remains available under Health.
- Primary send actions use the raised bevel treatment without a colored glow. Today microphone/send controls have state-aware VoiceOver labels.
- The floating capsule routes to Today, Journal, Fitness, and Health; the circular plus opens a modal-accessibility quick-action overlay over a dimmed destination and changes to a close icon. The panel has a close button, Escape shortcut, initial accessibility focus, and focus restoration to its launcher. Fitness also has the contextual top-right plus from `IMG_0486`, wired to the same action overlay. Six existing actions route to Vault, a new note, Files import, Assistant, Studio, and Settings; Journal remains in the primary dock. The grid uses three columns like Bevel `IMG_0490`, with one column at accessibility text sizes. No rendered Simulator/device comparison has run, so final visual parity is still unverified.
- The Today header follows Bevel `IMG_0478`'s upper-right share/profile utility capsule above the date. The localized date stays on one line when it fits and wraps into two lines instead of shrinking at narrow/accessibility widths. Its date control opens a graphical picker and reloads journal entries for the selected day; historical browsing changes the productivity calculation to that day and hides today's composer, clip, and share actions. The three-ring daily hero precedes a compact Health Monitor preview showing the latest real HRV, resting-HR, and sleep values with their sample age/source; it is explicitly labeled as recent data even while browsing older journal dates. “All measurements” opens the detailed Health tab. Share opens a Bevel-inspired composer with Overview/Nutrition/Summary/Stress categories, a six-card carousel with a raised bevel surface on every page, card-based VoiceOver page labels, customization, and PNG save/copy/system-share actions. Overview previews use ring artwork like `IMG_0479`/`IMG_0480`; adjacent card pairs show the same three HealthKit readings, then advance by two readings so all available measurements remain reachable. Their progress arcs reuse the Health tiles' display-only scales and label them as non-clinical, not as a score or recovery measure. It uses today's journal entries only when the user opts into journal text; Stress can be selected and shows a truthful no-data state until a real source is connected. The narrow-width action bar switches to compact controls. The R avatar badge routes to Settings because R0lling has no account profile image or initials. The glasses start/stop/connect action remains available as a raised icon beside the date; a separate bevel chip shows the real connection state, with VoiceOver action/status. No rendered Simulator/device comparison has run, so final visual parity is still unverified.

## Verification status

`TodayView`, the raised bevel surface across Today, wellness, Studio, Vault, Settings, Assistant composer, and edit-form cards, recessed editor inputs, the inset daily indicator rings, live focus progress, raised Photos/Files quick-action controls, compact metric pills, global theme, and main navigation have been updated toward this direction. The Today share action now opens a Bevel-inspired category/carousel composer and exports the selected artwork as PNG. The Fitness activity calendar selects the current day on first presentation and updates that selection with the rolling window. The source screenshots were inspected, but the iOS app cannot be rendered on the current Windows host. Compare a Simulator/device screenshot before claiming final visual parity; the static palette and layout code are not a visual QA result.
