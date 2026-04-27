---
name: Nocturnal Sanctuary
colors:
  surface: '#131407'
  surface-dim: '#131407'
  surface-bright: '#393b29'
  surface-container-lowest: '#0d0f03'
  surface-container-low: '#1b1d0e'
  surface-container: '#1f2112'
  surface-container-high: '#292b1b'
  surface-container-highest: '#343625'
  on-surface: '#e3e4cc'
  on-surface-variant: '#bfc8c7'
  inverse-surface: '#e3e4cc'
  inverse-on-surface: '#303221'
  outline: '#8a9292'
  outline-variant: '#404848'
  surface-tint: '#9dd0ce'
  primary: '#9dd0ce'
  on-primary: '#003736'
  primary-container: '#0f4746'
  on-primary-container: '#82b4b3'
  inverse-primary: '#346665'
  secondary: '#a0d2aa'
  on-secondary: '#07381c'
  secondary-container: '#225031'
  on-secondary-container: '#8fc199'
  tertiary: '#c6c9af'
  on-tertiary: '#2f3220'
  tertiary-container: '#3e412e'
  on-tertiary-container: '#aaad94'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#b8ecea'
  primary-fixed-dim: '#9dd0ce'
  on-primary-fixed: '#00201f'
  on-primary-fixed-variant: '#194e4d'
  secondary-fixed: '#bcefc5'
  secondary-fixed-dim: '#a0d2aa'
  on-secondary-fixed: '#00210d'
  on-secondary-fixed-variant: '#225031'
  tertiary-fixed: '#e2e5ca'
  tertiary-fixed-dim: '#c6c9af'
  on-tertiary-fixed: '#1a1d0c'
  on-tertiary-fixed-variant: '#454935'
  background: '#131407'
  on-background: '#e3e4cc'
  surface-variant: '#343625'
typography:
  h1:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  h2:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  h3:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: '0'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin: 32px
---

## Brand & Style

This design system establishes a "Tactile Sanctuary" through a nocturnal lens. It is designed for users seeking a calm, grounded digital environment that mirrors the comfort of a well-lit home at twilight. The brand personality is sophisticated yet approachable, blending high-end architectural aesthetics with the warmth of organic materials.

The visual style is a hybrid of **Minimalism** and **Tactile Modernism**. It prioritizes generous negative space and a restricted color palette to reduce cognitive load, while utilizing soft-touch physical metaphors—such as deep-set surfaces and pill-shaped elements—to create a sense of physical presence. The emotional response is one of safety, focus, and quiet luxury.

## Colors

The palette is rooted in "Deep Petroleum" and "Dark Stone," providing a foundation that feels heavy and permanent. 

- **Primary (#0f4746):** Used for structural importance and subtle brand presence. It acts as the "shadow" of the brand.
- **Secondary/Accent (#bcefc5):** A luminous mint that acts as a light source. Use this sparingly for interactive triggers, active states, and critical information.
- **Surface Strategy:** We use a tiered system of dark greens and charcols. The background is nearly black, while surfaces use #1b1d0e and #1e2110 to create a sense of lifting from the earth.
- **Contrast:** Typography transitions from off-white for headlines to a muted sage-grey for body text, ensuring readability without the harshness of pure white-on-black.

## Typography

The typography leverages **Plus Jakarta Sans** for its friendly yet modern geometric proportions. 

Headlines are set with tight tracking and bold weights to anchor the page, appearing in the lightest neutral tones to "glow" against the dark background. Body text maintains a comfortable line height (1.6) to ensure the dark-mode reading experience does not fatigue the eye. Labels use a slightly increased letter spacing and semi-bold weights to maintain legibility at small scales against deep-colored surfaces.

## Layout & Spacing

This design system utilizes a **Fluid Grid** model with a soft 8px rhythmic base. The layout is intended to feel "airy" despite the dark palette.

Margins are generous (32px+) to prevent elements from feeling cramped against the screen edges. Content containers should typically span 8 or 10 columns in a 12-column grid to maintain a centered, editorial feel. Use "Large" (48px) and "Extra Large" (80px) vertical spacing to separate major sections, reinforcing the minimalist philosophy of quality over quantity.

## Elevation & Depth

In this nocturnal environment, depth is conveyed through **Tonal Layering** and **Ambient Shadows** rather than traditional lighting.

1.  **Level 0 (Background):** Pure #0a0a0a.
2.  **Level 1 (Cards/Surfaces):** #1b1d0e with a subtle 1px border of #2c2c2c (10% opacity) to define edges.
3.  **Level 2 (Floating elements):** #1e2110 with a diffused shadow: `0px 15px 30px rgba(0, 0, 0, 0.6)`.

Shadows should feel heavy and soft, mimicking the way light falls in a dimly lit room. Avoid harsh shadows; prefer "glow" effects (inner shadows) using the secondary mint color at very low opacities (5-10%) to suggest interactive elements are backlit.

## Shapes

The shape language is strictly **Organic and Full**. Following the `ROUND_FULL` directive, buttons, tags, and input fields should utilize a pill-shaped (fully rounded) radius. 

Larger containers (cards, modals) should use a minimum of 2rem (32px) corner radius to maintain the "Tactile Sanctuary" vibe. This softness counters the "tech" feel of the dark petroleum colors, making the interface feel more natural and less industrial. Avoid sharp corners entirely.

## Components

- **Buttons:** Primary buttons are pill-shaped, filled with the Luminous Mint (#bcefc5), using dark petroleum text for high contrast. Secondary buttons use a thick 2px border of the primary green with a subtle hover "glow."
- **Inputs:** Fields are dark surfaces (#1b1d0e) with fully rounded corners. The focus state is defined by a soft outer glow of the secondary mint color.
- **Chips/Tags:** Small, pill-shaped elements using the Primary Green (#0f4746) with secondary-colored text. 
- **Cards:** Utilize the "Level 1" surface (#1b1d0e). Images within cards should have a slight darkening overlay to ensure they sit harmoniously within the dark UI.
- **Selection Controls:** Checkboxes and radios should be oversized and soft. When active, they should "bloom" with the secondary mint color.
- **Steppers/Progress:** Use thin, elegant lines in primary green, with the secondary mint indicating "filled" or "active" progress.