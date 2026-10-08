# Development Workflow Document — Orpheus

The normative version of [Workflow](../initial/Workflow.md). Where the two
disagree, this one is correct.

## 1. Branching

| | |
| --- | --- |
| **Default branch** | `develop` |
| **Pattern** | `<kind>/uc-<number>-<short-name>`, cut from `develop` |
| **Kinds** | `feature`, or `fix` for a defect |
| **Example** | `feature/uc-14-resume-a-track` |

Work that is not a use case takes the same pattern without the `uc-` segment:
`fix/scan-progress-strip`. Names are lowercase: letters, digits, `.`, `_` and
`-`.

Work branches merge into `develop` by pull request. A release is a
`release/<major>.<minor>.<patch>` branch cut from `develop` and merged into
`main` by pull request; it carries no commits of its own, so the version bump
and the changelog for a release land on `develop` first, through a work branch.
The release is tagged `v<version>` on its merge commit on `main`, where
`<version>` is the `version:` in `pubspec.yaml` without its build number — a
pre-release included: `v1.3.0-beta.1` is built from `1.3.0-beta.1+<build>`.
`.github/workflows/branch-policy.yml` enforces all of this on every pull request
into `develop` or `main`, and the steps are in
[CONTRIBUTING.md](../../CONTRIBUTING.md#releasing).

One branch per issue. A branch carrying two use cases cannot be reviewed against
either specification.

## 2. Commits

Conventional Commits, all lower case, subject in the imperative mood and no
longer than 50 characters including the type prefix. The type is one of `feat`,
`fix`, `refactor`, `docs`, `build`, `chore`, `test`, `ci` or `perf`, whatever
the branch is called. A blank second line, then a
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
- Opened against `develop`. Only a `release/` branch is opened against `main`.
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

- Committing to `develop` or `main` directly.
- Adding a dependency without recording it in the
  [Technology Stack Document](Technology%20Stack%20Document.md).
- Widening a platform permission without saying so in the manifest comment and
  in the README.
- Adding a network call. The lyrics lookup (`FR-LY-13`) and the desktop
  release check (`BR-03`) are the only two, and there is no circumstance under
  which a third is in scope without amending `NFR-02`, `BR-03` and the manifest
  first.
- Adding a permission to the Android package. CI pins the whole set, so this
  fails the build until it has been argued for in the manifest, the README and
  the Operations & Infrastructure Document.
