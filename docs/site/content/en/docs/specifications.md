---
title: Specifications
weight: 30
description: The normative documents this application is built to.
---

Orpheus is specified before it is built. Every use case is written down, agreed
and numbered before it is implemented, and the documents below are normative —
where this site and a specification disagree, the specification is right.

They live in the repository rather than being copied here, so there is one copy
of each and no chance of the two drifting apart.

## Start here

| Document | What it holds |
| --- | --- |
| [Vision](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Vision%20Document.md) | Stakeholders, positioning, and the `F-xx` features |
| [System Requirements](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/System%20Requirements%20Document.md) | The `FR-<AREA>-xx` and `NFR-xx` requirements, the data model, and traceability |
| [Use Case Specification](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Use%20Case%20Specification%20Document.md) | The `UC-xx` use cases, their flows, and their `AF-xx` alternatives |
| [Business Rules](https://github.com/artur-rios/orpheus/blob/main/docs/initial/Business%20Rules.md) | The domain entities and the `BR-xx` rules |

## How it is built and checked

| Document | What it holds |
| --- | --- |
| [Development Workflow](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Development%20Workflow%20Document.md) | The branch pattern, issue lifecycle, and Definition of Done |
| [Testing Specification](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Testing%20Specification%20Document.md) | How tests are written, named and run |
| [Technology Stack](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Technology%20Stack%20Document.md) | The single source of truth for every technology and version |
| [Operations &amp; Infrastructure](https://github.com/artur-rios/orpheus/blob/main/docs/requirements/Operations%20%26%20Infrastructure%20Document.md) | Layout, storage, startup, permissions, logging, and the `IR-xx` requirements |

## Context

| Document | What it holds |
| --- | --- |
| [Project Overview](https://github.com/artur-rios/orpheus/blob/main/docs/initial/Project%20Overview.md) | What it is, who it is for, and how success is measured |
| [Workflow](https://github.com/artur-rios/orpheus/blob/main/docs/initial/Workflow.md) | How one use case is delivered, step by step |
| [Brainstorm](https://github.com/artur-rios/orpheus/blob/main/docs/initial/Brainstorm.md) | The original free-form notes the project grew from |

## The promises that are checked, not asserted

Three of the rules in those documents are enforced by CI rather than trusted:

**The Android package asks for exactly the permissions it declares.** The
workflow reads them back out of the built package — the merged manifest, not the
one in the repository — and fails on anything not on the list. That is where a
permission wanted by a dependency would otherwise arrive unannounced.

**No test reaches outside its process.** Not to the developer's own preferences,
their application-support folder, their listening statistics, the native audio
engine, a platform media service, a music folder, or the network. Every one of
those is an interface bound in one composition root, and every one is overridden
in the test harness.

**The analyzer is clean, with no known-warnings list.** The moment there is one,
warnings stop being read.
