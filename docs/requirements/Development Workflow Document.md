# Development Workflow Document — Orpheus

The normative version of [Workflow](../initial/Workflow.md). Where the two
disagree, this one is correct.

## 1. Branching

| | |
| --- | --- |
| **Default branch** | `main` |
| **Pattern** | `<type>/uc-<number>-<short-name>` |
| **Types** | `feat`, `fix`, `refactor`, `docs`, `build`, `chore`, `test`, `ci`, `perf` |
| **Example** | `feat/uc-14-resume-a-track` |

Work that is not a use case takes the same pattern without the `uc-` segment:
`fix/scan-progress-strip`.

One branch per issue. A branch carrying two use cases cannot be reviewed against
either specification.

## 2. Commits

Conventional Commits, all lower case, subject in the imperative mood and no
longer than 50 characters including the type prefix. A blank second line, then a
body wrapped at 72 characters where the subject leaves a *why* unanswered.

```
feat: play in the background on android

Android had no way to keep playing once the application left the
screen. A foreground service is the only thing the system offers for
that, and the notification it posts is not decoration around it — the
two are one thing — so this adds both.
```

The body explains reasoning. It never replays the diff; `git log --stat`
already does that.

## 3. The issue lifecycle

| State | Meaning |
| --- | --- |
| **Todo** | Specified and not started. |
| **In Progress** | A branch exists. Entered at Step 3 of the workflow, not before. |
| **In Review** | A pull request is open. |
| **Done** | The pull request is merged and the issue is closed. |

One issue per use case, plus one for the foundation. Issues carry the milestone
their use case belongs to.

## 4. Stage boundaries

The work stops and waits for a human at four points:

1. after the specifications are read — before designing;
2. after the design and plan are written — before any code;
3. after the implementation — before testing;
4. after the tests are green — before the pull request.

A boundary crossed without a human is the failure this rule exists to prevent.
The cost of pausing is a message; the cost of not pausing is a branch built on a
misreading.

## 5. Pull requests

- Titled after the use case: `UC-14 — Resume a track where it stopped`.
- The body says what was built, which flows are covered, which alternative flows
  were implemented, and what was deliberately left out.
- The issue is linked so merging closes it.
- Nothing is merged with a failing analyzer or a failing suite.

## 6. Definition of Done

An issue is done when **all** of the following hold.

- [ ] Every flow in the use case is implemented, **including every alternative
      flow**. An alternative flow left out is a use case not done.
- [ ] `flutter analyze` reports no issues. There is no known-warnings list, and
      adding one is not an option.
- [ ] `flutter test` is green, and the new behaviour is covered by tests named
      Given-When-Then, one behaviour apiece.
- [ ] No test reaches outside its process (`NFR-08`).
- [ ] Both language catalogs are complete and every message carries a
      description (`FR-UX-09`).
- [ ] No colour literal exists outside `lib/core/theme/` (`FR-UX-08`).
- [ ] Every judgement call is documented where it lives, not only in a document
      (`NFR-10`).
- [ ] The README backlog row is marked done.
- [ ] The specifications still describe the application. Where the build taught
      us something the specification got wrong, the specification is corrected in
      the same pull request.

## 7. What is never done on a branch

- Committing to `main` directly.
- Adding a dependency without recording it in the
  [Technology Stack Document](Technology%20Stack%20Document.md).
- Widening a platform permission without saying so in the manifest comment and
  in the README.
- Adding a network call. The lyrics lookup (`FR-LY-13`) is the only one, and
  there is no circumstance under which a second is in scope without amending
  `NFR-02`, `BR-03` and the manifest first.
- Adding a permission to the Android package. CI pins the whole set, so this
  fails the build until it has been argued for in the manifest, the README and
  the Operations & Infrastructure Document.
