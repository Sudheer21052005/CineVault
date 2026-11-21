---
name: "CineVault Cinema Design System"
description: "A premium dark cinematic design system for movie and TV discovery and watchlist tracking."
---

## Overview

CineVault is an editorial, cinematic discovery and personal tracking interface for film and television enthusiasts. Rooted in modern movie theater ambiance, it pairs deep near-black negative space with crisp geometric typography, warm gold accents, and an electric blue primary highlight. CineVault is dedicated to discovery, information architecture, personal archiving, and viewing statistics—intentionally free of video playback controls, subscription pricing, and streaming commercialization.

## Colors

The CineVault palette is anchored by deep space tones, tiered dark surfaces, high-contrast readable type, and functional semantic indicators for viewing statuses.

- **Primary Electric Blue:** Directs user interaction, selection states, active navigation tabs, and primary action affordances.
- **Rating Gold:** Highlights ratings, critical acclaim, and star metrics without visual noise.
- **Status Semantics:** Distinct tokens for watched status, currently watching alerts, and error diagnostics.

```yaml
colors:
  canvas: "#0B0D12"
  surface-primary: "#121722"
  surface-elevated: "#192131"
  surface-secondary: "#202A3A"
  text-primary: "#F5F7FA"
  text-secondary: "#A8B1C2"
  text-muted: "#707B8F"
  primary: "#3B82F6"
  primary-hover: "#60A5FA"
  accent-gold: "#F4C95D"
  status-watched: "#39B982"
  status-watching: "#E9A23B"
  status-error: "#EF6262"
  light:
    primary: "#1D4ED8"
    on-primary: "#FFFFFF"
    surface: "#121722"
    on-surface: "#F5F7FA"
  dark:
    primary: "#3B82F6"
    on-primary: "#1E1E1E"
    surface: "#0B0D12"
    on-surface: "#F5F7FA"
    surface-container-low: "#121722"
    surface-container: "#192131"
    surface-container-high: "#202A3A"
    outline: "#232D3F"
```

## Typography

Typography pairs **Poppins** for modern geometric clarity across titles, navigation, and body copy, with **Spline Sans Mono** for timestamps, technical specs, aspect ratios, and numerical statistics.

```yaml
typography:
  display-lg:
    fontFamily: "Poppins"
    fontSize: 40px
    fontWeight: 700
    lineHeight: 48px
    letterSpacing: -0.5px
  display-lg-mobile:
    fontFamily: "Poppins"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 34px
    letterSpacing: -0.3px
  headline-xl:
    fontFamily: "Poppins"
    fontSize: 34px
    fontWeight: 600
    lineHeight: 42px
    letterSpacing: -0.4px
  headline-xl-mobile:
    fontFamily: "Poppins"
    fontSize: 24px
    fontWeight: 600
    lineHeight: 30px
    letterSpacing: -0.2px
  headline-lg:
    fontFamily: "Poppins"
    fontSize: 26px
    fontWeight: 600
    lineHeight: 34px
    letterSpacing: -0.2px
  headline-lg-mobile:
    fontFamily: "Poppins"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 26px
    letterSpacing: -0.1px
  headline-md:
    fontFamily: "Poppins"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 24px
  headline-sm:
    fontFamily: "Poppins"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 22px
  body-lg:
    fontFamily: "Poppins"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 24px
  body-md:
    fontFamily: "Poppins"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px
  body-sm:
    fontFamily: "Poppins"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
  label-lg:
    fontFamily: "Poppins"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 20px
    letterSpacing: 0.2px
  label-md:
    fontFamily: "Poppins"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 16px
    letterSpacing: 0.3px
  label-sm:
    fontFamily: "Poppins"
    fontSize: 10px
    fontWeight: 600
    lineHeight: 14px
    letterSpacing: 0.5px
  mono-sm:
    fontFamily: "Spline Sans Mono"
    fontSize: 11px
    fontWeight: 500
    lineHeight: 14px
```

## Layout & Spacing

CineVault implements a responsive layout model adhering to a rigorous 4-point spacing scale. Mobile viewports adopt a focused 390px canvas with sticky bottom navigation; wider viewports expand with compact navigation rails.

```yaml
spacing:
  space-1: 4px
  space-2: 8px
  space-3: 12px
  space-4: 16px
  space-5: 20px
  space-6: 24px
  space-8: 32px
  space-10: 40px
  space-12: 48px
```

## Elevation & Depth

Surfaces maintain cinematic restraint. Deep black backdrop `#0B0D12` supports layer `#121722` and elevated card surfaces `#192131` with `#202A3A` boundaries. Subtle hairline outlines (`border border-white/5` or `border border-[#202A3A]`) establish separation without harsh contrast or thick borders. No neon glows or heavy drop shadows are permitted.

## Shapes

Geometry balances crisp editorial framing with comfortable ergonomics:

```yaml
rounded:
  poster: 10px
  card: 16px
  chip: 20px
  full: 9999px
  sm: 4px
  md: 8px
```

- **Poster Cards:** 10px border radius preserves sharp film frame definition.
- **Surface & Dialog Cards:** 16px border radius delivers soft, tactile grouping.
- **Filter Chips & Status Pills:** 20px border radius provides pill-shaped touch targets.

## Motion & Micro-interaction

Micro-interactions feel instantaneous, responsive, and cinematic.

```yaml
motion:
  tap:
    duration: 120ms
    delay: 0ms
    timingFunction: cubic-bezier(0.2, 0, 0, 1)
  card-hover:
    duration: 180ms
    delay: 0ms
    timingFunction: cubic-bezier(0.2, 0, 0, 1)
  sheet-enter:
    duration: 280ms
    delay: 0ms
    timingFunction: cubic-bezier(0.05, 0.7, 0.1, 1)
  fade:
    duration: 150ms
    delay: 0ms
    timingFunction: ease-out
```

## Voice & Content Strategy

- **Tone:** Cultivated, respectful of cinema and television craft, quiet, concise.
- **Non-Commercial:** Pure discovery and personal archiving. Strictly never display "Watch Now", subscription prices, or stream player controls. Use actions like "Add to Watchlist", "Mark as Watched", "Inspect Details", "View Credits".
- **Empty States:** Calm, informative, single actionable suggestion.
- **Status Labels:** Explicit status badges ("Watched", "In Progress", "Plan to Watch", "Logged").

## Components

Component implementations live as individual HTML sticker sheet files in
`components/`. Each file contains the canonical, styled HTML components with
`<!-- COMPONENT: name -->` comment markers. Read each file before use.

- **Badge** → `@components/badge.html`: `badge-numeric`, `badge-dot`
- **Button** → `@components/button.html`: `button-primary`, `button-icon`, `button-with-icon`
- **Card** → `@components/card.html`: `card-elevated`, `card-interactive`, `card-interactive-2`
- **Carousel** → `@components/carousel.html`: `carousel-default`
- **Skeleton** → `@components/skeleton.html`: `skeleton-text`, `skeleton-card`
- **Tabs** → `@components/tabs.html`: `tabs-horizontal`, `tabs-with-icon`
