# App Compact Page Retrofit Design

**Goal:** Define one cross-theme compact page retrofit standard for the whole app, then use it to systematically refactor sleep-related pages first.

**Scope:** Global page layout density, responsive behavior, component reuse, and retrofit order. This is not a one-page mockup spec and is not limited to dark pages.

## Decision

- Create a reusable global compact retrofit standard under `glacier/visual-specs/`.
- Index it from Glacier documentation so future page work starts from the same rules.
- Use the standard to drive the next refactor batch:
  - `HomePostSleepPage`
  - `MorningFeedbackPage`
  - `CantSleepPage`
  - `NightAwakeningLogPage`

## Why This Approach

- Existing Glacier docs already define tokens, component references, and page-specific guidance.
- What is missing is a retrofit-focused standard that answers practical implementation questions:
  - When to keep two columns vs degrade to one
  - How compact pages should handle wrapping and card height
  - Which shared components must be preferred first
  - How to avoid fixed-size layout traps during retrofit
- Writing that once will reduce repeated design decisions and speed future page cleanup.

## Core Rules Captured

- Compact means higher scan efficiency, not arbitrary compression.
- Layout rules must be theme-agnostic and survive future dark mode rollout.
- Token usage is mandatory.
- Content-driven height beats fixed card height.
- Text should wrap before structure degrades.
- Shared components and semantic radius tokens are the default path.

## Rollout Strategy

1. Publish the global retrofit standard.
2. Index it in Glacier docs.
3. Write a sleep-page implementation plan against that standard.
4. Refactor sleep pages one by one with tests.
