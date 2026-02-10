# Numeric Input Localization Policy (Inspector)

Date: 2026-02-09

## Problem

Transform editing has historically been fragile when users type decimals with a separator that does not match the current locale.

Examples:

- Locale expects comma, user types `1.5`
- Locale expects period, user types `1,5`
- Non-Latin keyboards may produce other decimal symbols

This has been a recurring pain point in RCP-like workflows, especially during rapid transform edits.

## Decision

Use **open input, localized output**.

- Output/display remains locale-native (Foundation/SwiftUI numeric formatting).
- Input parsing is permissive and accepts common decimal symbols across locales.

This is effectively a "reverse-open localization" strategy: strict locale for display, broad acceptance for input.

## Parsing Rules

When committing a numeric text field:

1. Trim whitespace.
2. Accept Unicode digits.
3. Treat common decimal symbols as decimal candidates:
   - `.`, `,`, Arabic decimal `٫`, fullwidth variants.
4. Treat common grouping separators as ignorable:
   - spaces, apostrophes, thin spaces, Arabic thousands separator, underscore.
5. Use the **last** decimal candidate as the decimal separator.
6. Remove all grouping separators.
7. Normalize to a canonical decimal (`.`) and parse to `Double`.
8. Re-render using locale formatter for display.

## Why This Policy

- Matches real typing behavior from international users.
- Reduces failed commits during repetitive transform edits.
- Keeps UI formatting culturally correct without forcing users to switch keyboard habits.
- Avoids brittle "locale-only input" failures that are hard to diagnose.

## Scope

This policy is for inspector numeric entry paths (Transform axis fields first).  
It can be reused for any future numeric fields where fast manual input matters.

