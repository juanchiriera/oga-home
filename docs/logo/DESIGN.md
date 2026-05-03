# Design System Document

## 1. Overview & Creative North Star: "The Tactile Sanctuary"

This design system is built upon the North Star of **The Tactile Sanctuary**. We are moving away from the cold, clinical efficiency of traditional utility apps and toward a digital environment that feels like a well-curated home. 

The goal is "Organic Sophistication." We achieve this by rejecting the rigid, boxy constraints of standard mobile UI. Instead, we use **intentional asymmetry**, **exaggerated corner radii**, and **tonal depth** to create a layout that feels grown, not built. This system prioritizes the "breath" of the interface—using generous whitespace and soft transitions to reduce cognitive load and evoke a sense of calm management.

---

## 2. Colors & Surface Philosophy

The palette is rooted in nature, designed to feel grounded and premium. 

### The "No-Line" Rule
**Borders are prohibited for sectioning.** To create distinction between content areas, designers must use background color shifts or tonal transitions. For example, a `surface-container-low` card should sit on a `surface` background to create a "natural" edge. High-contrast 1px lines are too aggressive for a cozy environment.

### Surface Hierarchy & Nesting
We treat the UI as physical layers of fine paper or frosted glass. Use the `surface-container` tiers to define depth:
- **Base Layer:** `surface` (#fbfbe2) or `surface-container-lowest` (#ffffff).
- **Secondary Content:** `surface-container` (#efefd7).
- **Interactive Elements:** `surface-container-high` (#eaead1).

### The "Glass & Gradient" Rule
To elevate the "cozy" feel, use **Glassmorphism** for floating elements (like the AI Assistant or navigation bars). 
- **Recipe:** Apply a semi-transparent `surface-variant` with a 20px-40px backdrop blur.
- **Signature Textures:** For Hero CTAs, use a subtle radial gradient transitioning from `primary` (#0f4746) to `primary_container` (#2c5f5d) at a 45-degree angle. This adds "soul" and prevents the app from feeling flat.

---

## 3. Typography: Editorial Warmth

We utilize **Plus Jakarta Sans**, a clean, rounded sans-serif that balances modern geometric shapes with soft, friendly terminals.

*   **Display (lg/md/sm):** Reserved for moments of celebration (e.g., "Good morning, Sarah"). Use `display-md` with tight letter-spacing (-2%) to create an editorial feel.
*   **Headlines & Titles:** Use `headline-sm` for section headers. Never use all-caps; keep it sentence-case to maintain a conversational, approachable tone.
*   **Body (lg/md/sm):** `body-md` is your workhorse. Ensure a line-height of 1.5x to maintain the "breathing room" required by the brand.
*   **Labels:** Use `label-md` in `secondary` (#3a6847) for metadata. This provides a clear hierarchy without relying on bold weights.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved through **Tonal Layering**. Instead of shadows, stack containers:
- A `surface-container-low` (#f5f5dc) section can hold a `surface-container-highest` (#e4e4cc) card. The subtle shift in beige creates a sophisticated, soft lift.

### Ambient Shadows
When an element must "float" (e.g., a modal or the AI button):
- **Blur:** 30px to 60px.
- **Opacity:** 4%–8%.
- **Tint:** Use a shadow color derived from `on-surface` (#1b1d0e) rather than pure black. This mimics natural light filtered through a room.

### The "Ghost Border" Fallback
If a border is required for accessibility, use a **Ghost Border**: `outline-variant` (#bfc8c7) at **15% opacity**. Never use 100% opaque lines.

---

## 5. Components

### The AI Assistant (The Protagonist)
The AI is the heart of the home. 
- **Style:** Always use a `tertiary_container` (#6f5227) or a custom gradient. 
- **The Glow:** Apply an inner-glow (soft white) and an outer-glow (using `tertiary_fixed` at 30% opacity) to signify its "active" role. It should look like a soft light source behind the glass.

### Buttons
- **Primary:** Large radius (`xl`: 3rem). Background: `primary` (#0f4746). Text: `on_primary` (#ffffff).
- **Secondary:** `secondary_container` (#bcefc5). No border.
- **Tertiary:** Text-only using `primary` with a subtle `surface-variant` background on hover/tap.

### Cards & Lists
- **Rule:** Forbid divider lines. 
- **Separation:** Use 16px–24px of vertical whitespace or a subtle background shift to `surface-container-low`.
- **Corner Radius:** Use `lg` (2rem) for main cards and `md` (1.5rem) for nested elements.

### Input Fields
- **Style:** Soft-filled. Use `surface-container-highest` as the background. 
- **Focus State:** Instead of a thick border, use a subtle glow and shift the background color slightly toward `primary_fixed`.

---

## 6. Do's and Don'ts

### Do:
- **Embrace Asymmetry:** Allow some elements to bleed off-center or overlap slightly to feel "organic."
- **Use "Cozy" Spacing:** Favor 24px and 32px gutters over the standard 16px to give the content room to breathe.
- **Layer Tones:** Use the full range of beige and greens to create a rich, tactile experience.

### Don't:
- **Don't use 1px Dividers:** They shatter the "Tactile Sanctuary" illusion and feel like a spreadsheet.
- **Don't use Pure Black:** Even for text, use `on_surface` (#1b1d0e) to keep the contrast soft on the eyes.
- **Don't use Small Radii:** Avoid `none` or `sm` corners. Everything in this system should feel "sanded down" and safe to touch.