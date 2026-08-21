# ECON 630 — Econometrics III (Fall 2026)

**Prediction, Time Series, and Causal Inference** · 3 credits
Tue/Thu 9:00–10:15 am · 244 Saunders Hall · instruction 08/25–12/10, finals 12/14–18

Instructor: **Peter Fuleky** — <fuleky@hawaii.edu> — 508 Saunders Hall
Office hours by appointment, in person or via Zoom.

This repository is the hub for the course: the syllabus, assignments, and
announcements all live here.

## Start here

| | |
|---|---|
| **Syllabus** | https://uh-manoa-uhero.github.io/econ630/ ([PDF](https://uh-manoa-uhero.github.io/econ630/SYLLABUS_ECON630.pdf)) |
| **Prediction & time series notes** | https://special-adventure-gw99jmk.pages.github.io/ |
| **Causal inference notes** | https://fantastic-adventure-v611vgo.pages.github.io/ |

Read the syllabus first — it explains the flipped-classroom format, the weekly
rhythm, the schedule, and how you are graded.

## In this repository

| | |
|---|---|
| [Discussions](../../discussions) | Announcements, Q&A, and presentation sign-ups |
| [assignments/](assignments/) | Weekly specs and how to submit |
| [presentations.md](presentations.md) | Who leads which session |

**Announcements** is where schedule changes, exam logistics, and corrections to
the notes are posted — [watch this repository](../../subscription) so they reach
you by email. Ask course questions in **Q&A** rather than emailing, so the whole
class sees the answer; answering a classmate counts toward participation.

Homework goes to **your own private repository** — never in Discussions, which the
whole class can read. See [assignments/README.md](assignments/README.md).

## You need a GitHub account

The syllabus is public — read it without signing in. **Both lecture-note sites are
private to this class.** Sign in to GitHub with the account you gave me and they
open normally; if you are not signed in, or your account has not been added yet,
you will be redirected to a GitHub login page instead of the notes.

If you have not done this yet: create a free account at
[github.com](https://github.com/) and email me the username. No institutional
email is required, and you will not need to know anything about Git to read the
notes.

## Weekly rhythm

Each week, before the Tuesday session:

1. **Read** the assigned chapter in the original textbook (~2–3 hrs)
2. **Watch** the assigned video lecture(s) (~2 hrs)
3. **Review** the corresponding lecture notes (~1–2 hrs)
4. **Run** the lab code yourself (~2 hrs)
5. **Self-check** the exercises against the provided solutions (~2 hrs)
6. **Write up by hand** a summary plus the conceptual exercises, submitted by
   **Sunday 8 pm** (~2 hrs)
7. **Present or discuss** in class — both sessions

One enrolled student leads each session. There are more sessions than students,
so everyone leads more than once; sign-ups are arranged early in the term.

See the syllabus for the full schedule, the three blocks and their exams, and
the assessment weights.

## Course materials, free of charge

- *An Introduction to Statistical Learning* (2nd ed.) — [statlearning.com](https://www.statlearning.com/)
- *The Effect: An Introduction to Research Design and Causality* — [theeffectbook.net](https://theeffectbook.net/)
- [R](https://cran.r-project.org/) + [Positron](https://positron.posit.co/)

Verbeek Ch 8–9 (the time-series weeks) is not freely available; the lecture
notes cover that material in full and the lab data is provided.

## Repository layout

```
.
├── README.md                       # This page — student landing
├── index.qmd                       # Syllabus source (Quarto)
├── _quarto.yml                     # Renders index.qmd only, into docs/
├── LICENSE
├── presentations.md                # Session schedule, sign-ups, thread seed text
├── docs/                           # Rendered syllabus (untracked; published to gh-pages)
├── assignments/
│   ├── README.md                   # What is collected, deadlines, how to submit
│   ├── weekNN.md                   # Per-week reading, videos, exercises
│   ├── TEMPLATE.md                 # Blank weekly spec
│   └── hw-repo-README.md           # Text seeded into each student's homework repo
├── scripts/
│   ├── publish_site.sh             # Pushes docs/ to gh-pages as a single commit
│   ├── create_hw_repos.sh          # One private repo per student, write access
│   └── check_submissions.sh        # Who submitted week NN, and when
└── .github/DISCUSSION_TEMPLATE/    # Discussion category forms. GitHub locates these
                                      by path, and each filename must match its
                                      category slug (announcements, q-a).


## For the instructor: publishing the syllabus

The rendered syllabus lives on the `gh-pages` branch, not on `main`. Updating the
site and pushing `main` are **two independent actions** — pushing `main` does not
touch the site:

```bash
quarto render                                   # writes docs/ (gitignored)
./scripts/publish_site.sh                       # force-pushes docs/ to gh-pages
git add -A && git commit -m "..." && git push   # does NOT update the site
```

GitHub Pages serves branch `gh-pages` from `/` (root). The syllabus site is
published **publicly**, so anyone can read it; the two notes sites are private and
require GitHub Enterprise Cloud. Access to the notes and to this repository is
granted by adding students to the `econ630-fall2026` team, which has read access on
all three repositories.

Homework submission uses one private repository per student:

```bash
gh auth login                                          # once
./scripts/create_hw_repos.sh --team econ630-fall2026   # roster from the team
./scripts/check_submissions.sh 03 2026-09-06T20:00:00-10:00
```

`create_hw_repos.sh` reads the team's membership, so adding a student to the team
and re-running it is all a late enrollment needs; existing repos are left alone.

Two things that must hold, or submissions stop being private:

- **Base permissions must be "No permission"** (Settings > Member privileges).
  Team membership makes students organization members, and any higher base
  permission lets every member read every repository in the org. The script checks
  this and refuses to continue without confirmation.
- **Never give the `econ630-fall2026` team access to a homework repository** — that
  would make one student's work readable by the whole class.

`git status` stays clean after a render because `docs/` is gitignored — that is
expected, not a failed render.
