# Project specification — Expenses Frontend

This document describes **what the product is for** and **what users can do**. Implementation constraints (architecture, API ownership, tooling) live in [`AGENTS.md`](./AGENTS.md) and [`TECHNICAL_STACK.md`](./TECHNICAL_STACK.md).

## Product intent

A **personal expense tracking** app: one user signs in, records spending through a conversational flow and a dedicated report view, and relies on the **backend API** to store and return every expense the app displays.

## Authentication

- The user can **sign in** and **sign out**.
- The client is only “logged in” for product purposes when both **identity** (per current stack: Google Sign-In via Firebase) and **API session** are valid; see `AGENTS.md` for the expected contract.

## Chatbox — receipts

- The user can **upload a receipt image** from the chatbox.
- The app sends the image to the **API** (format as defined by the API, e.g. multipart upload).
- **Parsing, line items, and persistence** are server responsibilities: saved item details come back from the API; the app does not treat local-only state as authoritative.

## Chatbox — manual line items

- The user can enter an **item name** and **price**, then **submit**.
- On success, the line item is **saved through the API** (same source of truth as receipts).

## Reports

- A **report** area lets the user **filter by a date range**.
- The UI shows a **list of expenses** for that range.
- A **total** for the filtered list is shown **at the bottom of the list** (totals must reflect **API-derived** figures, not ad-hoc client sums unless they match the API contract).

## Data authority

All expense records, lists, and aggregates shown in the app are **owned by the backend** and loaded or confirmed via **API responses**. The client may cache or draft UX locally, but not as a parallel system of record.

## Related docs

- [`AGENTS.md`](./AGENTS.md) — engineering expectations, Riverpod, HTTP boundaries.
- [`TECHNICAL_STACK.md`](./TECHNICAL_STACK.md) — platforms, stack, `.env` configuration.
