---
name: Friendly Intelligence
colors:
  surface: '#f8faf9'
  surface-dim: '#d8dada'
  surface-bright: '#f8faf9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f3'
  surface-container: '#eceeed'
  surface-container-high: '#e6e9e8'
  surface-container-highest: '#e1e3e2'
  on-surface: '#191c1c'
  on-surface-variant: '#3f4945'
  inverse-surface: '#2e3131'
  inverse-on-surface: '#eff1f0'
  outline: '#707974'
  outline-variant: '#bfc9c3'
  surface-tint: '#276956'
  primary: '#276956'
  on-primary: '#ffffff'
  primary-container: '#9ee0c8'
  on-primary-container: '#226552'
  inverse-primary: '#92d4bc'
  secondary: '#74593f'
  on-secondary: '#ffffff'
  secondary-container: '#fed9b8'
  on-secondary-container: '#795d43'
  tertiary: '#70585b'
  on-tertiary: '#ffffff'
  tertiary-container: '#eacbce'
  on-tertiary-container: '#6c5457'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#aef0d8'
  primary-fixed-dim: '#92d4bc'
  on-primary-fixed: '#002118'
  on-primary-fixed-variant: '#03513f'
  secondary-fixed: '#ffdcbe'
  secondary-fixed-dim: '#e3c0a0'
  on-secondary-fixed: '#2a1704'
  on-secondary-fixed-variant: '#5a422a'
  tertiary-fixed: '#fbdbde'
  tertiary-fixed-dim: '#debfc2'
  on-tertiary-fixed: '#281719'
  on-tertiary-fixed-variant: '#574144'
  background: '#f8faf9'
  on-background: '#191c1c'
  surface-variant: '#e1e3e2'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  chat-bubble:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  bubble-padding: 12px 16px
  container-gap: 24px
---

## Brand & Style

The design system is defined by a "Soft Minimalism" aesthetic that prioritizes approachability, warmth, and clarity. It is designed to transform the often intimidating experience of interacting with AI into a friendly, supportive conversation. 

The visual language draws inspiration from modern lifestyle apps, utilizing high-density whitespace, a gentle pastel palette, and exaggerated roundedness to create a "cute" but professional environment. The emotional goal is to evoke a sense of calm and competence. Key characteristics include:

- **Optimistic Tone:** Every interaction feels encouraging rather than purely transactional.
- **Visual Playfulness:** Subtle use of whimsical illustrations and soft iconography to humanize technical tasks.
- **Clarity through Structure:** Despite the soft edges, the layout remains strictly organized to ensure the AI's information is easy to parse and act upon.

## Colors

The palette is anchored in desaturated, warm pastels that provide distinction without visual fatigue. 

- **Primary (Mint):** Used for primary actions, positive reinforcement, and AI identity markers. It represents growth and clarity.
- **Secondary (Peach):** Utilized for secondary highlights, information callouts, and conversational variety.
- **Tertiary (Soft Pink):** Reserved for delicate accents or soft warnings that need to be noticed without causing alarm.
- **Neutral (Cloud & Charcoal):** The background is a soft off-white (`#F7F9F8`) to reduce glare. Typography uses a soft charcoal rather than pure black to maintain the gentle aesthetic.
- **Surfaces:** Containers use pure white (#FFFFFF) to pop against the neutral background, creating a subtle layered effect.

## Typography

This design system uses **Plus Jakarta Sans** for all levels to maintain a contemporary, optimistic feel. The typeface’s open apertures and geometric foundations ensure high legibility in chat interfaces.

- **Scale:** Headlines use a tight tracking and bold weights to ground the page. 
- **Chat Hierarchy:** The `chat-bubble` style is specifically tuned for readability in constrained widths, featuring a slightly increased line-height to make long AI explanations feel less dense.
- **Case Usage:** Labels should use sentence case or all-caps with generous letter-spacing to distinguish them from conversational text.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** model with generous safe areas to maintain an airy, uncluttered feel.

- **The Chat Stream:** Centrally aligned on desktop with a max-width of 768px to ensure comfortable reading lines. On mobile, it spans the full width minus the 20px margins.
- **Rhythm:** An 8px-based spacing system is used, but internal component padding often utilizes 12px or 20px to break the rigidity and feel more "organic."
- **Gaps:** Use wide gaps (24px+) between distinct AI "thoughts" or cards to help the user process information in bite-sized chunks.

## Elevation & Depth

This design system avoids heavy shadows, instead relying on **Tonal Layers** and **Soft Inner Glows** to communicate hierarchy.

- **Surface Tiers:** Background is Level 0. Main cards and chat bubbles are Level 1 (White). Floating actions (like the "Send" button) are Level 2.
- **Shadows:** When necessary, use extremely diffused, low-opacity shadows (e.g., `box-shadow: 0 8px 24px rgba(149, 157, 165, 0.1)`). Shadows should feel like ambient light rather than a direct light source.
- **Interaction:** Upon hover, elements should lift slightly using a subtle transform and a tiny increase in shadow spread, maintaining the "squishy" and tactile nature of the UI.

## Shapes

The shape language is the core of the system's "cute" and "friendly" personality. 

- **Corner Radii:** Standard components use a 16px (1rem) radius. Large cards and chat bubbles use 24px (1.5rem).
- **Pill Shapes:** Interactive triggers, such as primary buttons, tags, and the input field, should be fully pill-shaped (rounded-full).
- **Asymmetry:** Chat bubbles for the user should have a slightly smaller radius on the bottom-right corner to point toward the input, while AI bubbles use a smaller radius on the bottom-left.

## Components

### Chat Bubbles
User bubbles use a light grey or the Secondary Peach color with right-alignment. AI bubbles use the Primary Mint or pure White with left-alignment. Both feature generous 24px corner radii.

### Buttons
Primary buttons are pill-shaped, using the Primary Mint color with bold, white text. Secondary buttons use a ghost style with a 2px mint border.

### Input Field
A large, pill-shaped container with a subtle 1px light-grey border. On focus, the border transitions to Primary Mint. The "Send" action is a circular button within the input field.

### AI Suggestion Chips
Small, pill-shaped chips floating above the input. These use the Tertiary Pink or Secondary Peach backgrounds with 50% opacity to suggest they are optional, temporary actions.

### Cards
Rich AI responses (like charts or lists) should be wrapped in white cards with 24px rounded corners and a very soft ambient shadow. Use the pastel palette for data visualization to maintain consistency.