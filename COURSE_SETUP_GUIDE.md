# Setting up a course on GitHub

A complete runbook for the arrangement used by ECON 630 (Fall 2026): lecture notes
as private Quarto websites, a public syllabus, announcements and Q&A in
Discussions, and homework collected in one private repository per student.

Written to be reusable — for a different course, a different semester, or to hand
to an agent as a specification. Everything here was learned by building it, and
the traps in [§10](#10-traps-worth-knowing-about) are the ones that actually bit.

**Worked example throughout:** organization `uh-manoa-uhero`, course repository
`econ630`, notes repositories `islr_notes` and `effect_notes`.

---

## 1. Decide the shape first

Three repositories, because they have different audiences and lifespans:

| Repository | Contents | Visibility | Lifespan |
|---|---|---|---|
| `<course>` | Syllabus, schedule, assignment rules, Discussions | Repo private; **syllabus site public** | Per course |
| `<subject>_notes` | Lecture notes, one per body of material | Private, site private | Across courses |
| `<course>-f26-hw-<user>` | One student's submissions | Private | Per semester |

Notes live apart from the course because the same notes serve several offerings.
Homework lives apart because everything in a shared repository is readable by
everyone with access to it — that single fact drives most of this design.

### Prerequisites

- **A GitHub organization on Enterprise Cloud.** Private Pages requires it:
  *"To publish a GitHub Pages site privately, your organization must use GitHub
  Enterprise Cloud."* A personal account cannot do it — its Pages sites are always
  public.
- **`gh` CLI**, authenticated: `brew install gh && gh auth login`
- **Quarto** and, for notes with executable code, **R** with `renv`

---

## 2. Set the organization up once

Before adding a single student. Both settings are under
**Settings → Member privileges**.

### Base permissions → "No permission"

This is the most consequential setting in the whole arrangement and the easiest to
miss. Base permissions grant every organization *member* a default level of access
to *every* repository the organization owns, and the default is **Read**.

Team membership makes students organization members. So with the default left in
place, adding a student to a team gives them read access to every repository in the
organization — the notes, other students' homework, and anything else the
organization keeps there.

Verify from the command line rather than trusting the UI:

```bash
gh api orgs/<ORG> --jq .default_repository_permission    # must print: none
```

### Repository creation

Restrict members to **private repositories only** if you let students create
anything. Prevents a student publishing their own coursework to the world.

### Know who else can see everything

```bash
gh api orgs/<ORG>/members?role=admin --jq '.[].login'
```

Organization owners hold admin on every repository the organization owns,
including each student's homework repository. This cannot be switched off at the
repository level. Say so in the student-facing text rather than claiming
submissions are visible only to the student and the instructor.

---

## 3. Create repositories without the push collision

When creating a repository on GitHub, **leave "Add a README" and "Choose a
license" unchecked**. An auto-initialized repository has a root commit your local
history does not share, and your first push is rejected:

```
! [rejected]  main -> main (fetch first)
```

If it happens anyway, replay your work on top rather than force-pushing over it:

```bash
git fetch origin
git rebase origin/main        # your commit lands on top; LICENSE is untouched
git push -u origin main
```

Create the repository **in the organization**, not a personal account. Transferring
later works (Settings → General → Transfer ownership) but the Pages URL and any
existing links change.

---

## 4. A Quarto notes repository

### Configuration

```yaml
project:
  type: book              # or default, for a single document
  output-dir: docs        # GitHub Pages serves / or /docs only

execute:
  freeze: auto            # skip re-executing unchanged documents
```

For a single-document project, **restrict what renders** or Quarto will render
every `.qmd` and `.md` in the project and publish them all:

```yaml
project:
  type: default
  output-dir: docs
  render:
    - index.qmd
```

### What to commit, and what not to

Commit **sources only**. Everything derived is regenerable:

```gitignore
/docs/                              # rendered site — published to gh-pages instead
/_freeze/                           # local render accelerator
/.quarto/                           # Quarto internals
/site_libs/                         # stray from single-file renders
*_cache/                            # knitr caches
chapters/chap*_files/               # figure staging
/<book>.tex                         # only if keep-tex is on
.DS_Store
```

Two decisions worth understanding rather than copying:

**`_freeze/`.** Quarto's own guidance is to commit it: *"You should check the
contents of `_freeze` into version control so that others rendering the project
don't need to reproduce your computational environment."* That is right when the
rendered output is also committed, because the figures dedup against it — measured
on one repository, `_freeze` looked like 29.5 MB but cost only **10.9 MB** of new
objects. Once `docs/` moves off `main`, nothing dedups against it and it costs full
price. Commit it only if you render from more than one machine.

**`keep-tex: true`.** It retains the assembled `.tex` at the project root, and that
file references figures by relative path — 120 `\includegraphics` in one book. Keep
it and you must also track `chapters/chap*_files/`, whose PDFs embed a
`/CreationDate` and so are new objects on *every* render. Drop `keep-tex` unless
you hand-compile the LaTeX.

### Why the rendered site does not belong on `main`

Two things make every render rewrite essentially the whole output:

- `date: last-modified` restamps every page
- PDF figures embed `/CreationDate` and `/ModDate`

Measured on a 15-chapter book: **~51 MB of guaranteed new objects per render**, up
to ~108 MB. Committing that to `main` a dozen times approaches GitHub's 1 GB
recommendation. So publish the output to a branch that gets replaced instead.

### The publish script

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BRANCH=gh-pages
[ -f docs/index.html ] || { echo "run 'quarto render' first" >&2; exit 1; }
URL=$(git remote get-url origin)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -R docs/. "$TMP/"
find "$TMP" -name '.DS_Store' -delete
touch "$TMP/.nojekyll"          # stop Jekyll dropping files starting with _
git -C "$TMP" init -q -b "$BRANCH"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "Site build $(date '+%Y-%m-%d %H:%M')"
git -C "$TMP" push -f "$URL" "$BRANCH"
```

A fresh single-commit branch every time, so only one copy of the output is ever
reachable and repository size stays flat however often you publish. Nothing of
value is lost: the site regenerates from `main`.

**Test it against a local bare repository before pointing it at GitHub.** This is
how the "renders every file in the project" bug was found:

```bash
git init -q --bare /tmp/testremote.git
sed 's|URL=$(git remote get-url origin)|URL=/tmp/testremote.git|' \
  scripts/publish_site.sh > scripts/.test.sh
bash scripts/.test.sh
git -C /tmp/testremote.git ls-tree -r --name-only gh-pages   # exactly what publishes
rm scripts/.test.sh
```

---

## 5. Private Pages

1. `./scripts/publish_site.sh` — create `gh-pages` **before** changing settings, so
   the site is never briefly empty.
2. **Settings → Pages** → source `gh-pages` / `/` (root) → Save.
3. Set visibility to **Private**.
4. Verify, unauthenticated:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://<subdomain>.pages.github.io/
# 302 -> gated (correct).  200 -> the site is PUBLIC.
```

### The URL is generated and unguessable

Private sites are served from a random subdomain — `fantastic-adventure-v611vgo.pages.github.io`
— not `<org>.github.io/<repo>`. GitHub assigns it *"to ensure that other
repositories in your organization cannot publish content on the same origin."* Read
it off Settings → Pages; it survives a repository rename but is reissued if Pages
is disabled and re-enabled.

If the URL you see is `<org>.github.io/<repo>`, **the site is public.** That is a
legitimate choice for a syllabus — it lets prospective students read it without a
GitHub account — but it must match what your documents claim.

### Order of operations when migrating an existing site

Pages serving `main` / `/docs` and you are moving to `gh-pages`: publish, switch
the source, verify, *then* push the commit that stops tracking `docs/`. Push first
and the site goes blank until you switch.

---

## 6. The course repository

```
README.md              # student landing page
index.qmd              # syllabus source
_quarto.yml            # render: [index.qmd], output-dir: docs
presentations.md       # session schedule, sign-ups, seed text for the pinned thread
assignments/
  README.md            # the standing weekly assignment, deadlines, how to submit
  hw-repo-README.md    # text seeded into each student's homework repository
scripts/
  publish_site.sh
  create_hw_repos.sh
  check_submissions.sh
  feedback.sh
.github/DISCUSSION_TEMPLATE/
  announcements.yml    # filename MUST equal the category slug
  q-a.yml
```

Keep executables in `scripts/`, student-facing prose at the root or in
`assignments/`, and `.github/` for things GitHub locates by path convention.

### One generic assignment, not fourteen

The syllabus schedule already gives the chapter and videos for each week. Writing a
separate spec per week duplicates it and is fourteen documents to maintain. State
the standing rule once: *look up the week in the schedule and write up the
conceptual exercises from the chapter it names.*

### Discussions

Enabling Discussions seeds six categories, including **Announcements**
(announcement format — only maintainers post) and **Q&A** (question/answer format).
Both are usually what you want; delete the rest.

Category forms live at `.github/DISCUSSION_TEMPLATE/<category-slug>.yml` and use
[GitHub's form schema](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema)
— top-level `title`, `labels`, `body`; each body element needs `type`
(`markdown`, `input`, `textarea`, `dropdown`, `checkboxes`, `upload`) and
`attributes`.

**Two things make a form silently do nothing:** the file is not on the default
branch, or the filename does not match the category slug. "Q&A" slugs to `q-a`.
There is no error message either way.

### Making sure announcements are actually seen

Two mechanisms, with opposite failure modes — use both:

- **Watching the repository** is a standing subscription. Discussions are covered
  by the custom option: *"choose to only be notified when updates to one or more
  types of events (issues, pull requests, releases, security alerts, or
  discussions)"*. Tell students to set **Custom → Discussions**. Fails silently for
  anyone who never sets it up, and you cannot check who did.
- **@mentioning the team** — `@<ORG>/<team-slug>` — notifies its members for that
  post and subscribes them to the thread, so they get replies too. Requires the
  team to be **visible**: *"Visible teams can be viewed and @mentioned by every
  organization member."* A team created with `privacy=closed` is visible; a
  `secret` team is not mentionable this way. Fails only if you forget to do it.

The mention is the one you control, so use it for anything that matters. Watching
is the net for everything else.

For a sign-up thread, do not use a form — a form creates a *new* discussion each
time, and you want one pinned thread people comment on. Keep the authoritative
schedule in a repository file and say so in the thread, or you will spend the term
editing the thread instead of a table.

---

## 7. Student access

One team per offering, so the roster is visible in one place and expires cleanly:

```bash
gh api -X POST orgs/<ORG>/teams -f name='econ630-fall2026' -f privacy=closed
```

Grant it **Read** on the course repository and each notes repository. Read is
enough for everything students do: view the sites, read the repository, post in
Discussions.

**Do not add yourself.** Organization owners already have admin everywhere, so the
team stays a pure enrollment list — glance at it to see who has access, empty it at
the end of term to revoke everything at once.

**Never grant the team access to a homework repository.** That single action makes
every submission readable by the whole class.

---

## 8. Homework collection

### What not to use, and why

| Option | Verdict |
|---|---|
| GitHub Classroom | **Retired.** Decommissioned 2026-08-28, closed to new users 2026-05-22. |
| Classroom 50 | Works, but new and unproven, and its due dates are labels: *"submissions after it are marked late, and nothing is blocked."* A real cutoff needs a manual **Close submission** per assignment. |
| LMS (Lamakū / D2L) | Genuinely good — private, gradebook, and an **end date** that closes the folder server-side. Choose it if you are willing to work in the LMS. |
| Issues or Discussions | **No.** Everything in a shared repository is readable by everyone with access, so classmates would read each other's work. |

### One private repository per student

Nothing outside GitHub, private by construction, and immune to a product being
discontinued. `scripts/create_hw_repos.sh`:

- takes `--team <slug>` and reads the roster from the team's membership
- creates `<course>-f26-hw-<username>`, private
- seeds its README from `assignments/hw-repo-README.md` via the contents API
- grants the student **push** (write), enough to upload through the web UI
- is idempotent — re-run after a late enrollment and only the new repository appears
- refuses to run if base permissions are not `none`

**The tradeoff: no automatic cutoff.** One repository per student for the whole
term means no per-week folder to close. Lateness rests on the upload timestamp,
which GitHub sets server-side for web uploads and a student cannot backdate. State
the policy as discretionary rather than promising a lockout you do not have.

### Students submit without knowing Git

**Add file → Upload files → drag the PDF → Commit changes.** No terminal, no
clone. Name files `weekNN.pdf` so tooling can find them.

### Checking and responding

```bash
./scripts/check_submissions.sh 03 2026-09-06T20:00:00-10:00   # who, when, LATE/MISSING
./scripts/feedback.sh 03 alice-hi "Good summary; see exercise 4."
```

Point-and-click alternatives, both of which email the student:

- **Commit comment** — open the PDF (GitHub renders PDFs inline), click **History**,
  click the commit, comment at the bottom. Anchors the remark to that submission.
- **Issue** — repo → Issues → New issue. Better when you expect a reply.

### No invitation email?

Adding someone who already has access returns `204 No Content` and sends nothing —
which is the case for organization owners, including yourself. A self-test will
never produce an invitation. Check for a real one with:

```bash
gh api repos/<ORG>/<REPO>/invitations --jq '.[].invitee.login'
```

---

## 9. Build the schedule from the real calendar

Do not assume the term runs Monday to Friday without interruption.

1. Get the registrar's calendar for that specific term — first and last day of
   instruction, the examination period, and every non-instructional day.
2. Compute the actual meeting dates and subtract holidays that fall on class days.
3. Check the **session budget** before writing any schedule:

```
sessions available   = meeting dates − holidays on class days
sessions needed      = topics × sessions-per-topic + in-class exams
```

For ECON 630 that was 30 available against 32 needed, so three weeks had to run as
single sessions. Discovering that while writing the syllabus is much cheaper than
discovering it in November.

```python
from datetime import date, timedelta
start, last = date(2026,8,24), date(2026,12,10)
holidays = {date(2026,11,3): "Election Day", date(2026,11,26): "Thanksgiving"}
d, sessions = start, []
while d <= last:
    if d.weekday() in (1, 3):        # Tue, Thu
        sessions.append(d)
    d += timedelta(days=1)
held = [s for s in sessions if s not in holidays]
print(len(sessions), "dates,", len(held), "held")
```

Put the dates in the schedule *and* anywhere else they appear — the assessment
table, the sign-up sheet, the assignment deadlines — and make one file
authoritative so they cannot drift.

---

## 10. Traps worth knowing about

Each of these cost real time.

**Amending a pushed commit.** `git commit --amend` after pushing creates diverging
histories with the same message and timestamp. Amend only while unpushed; after
that, make a normal commit.

**`git rm` with several paths.** It aborts entirely if *any* pathspec does not
match, silently doing nothing. Loop over paths instead.

**`set -euo pipefail` plus `grep`.** `grep` exits 1 when it finds nothing — often
the healthy case — and under `pipefail` that kills the script. Wrap it:
`$({ grep ... || true; } | wc -l)`.

**Nested code fences.** Wrapping a block that itself contains ``` needs a
four-backtick fence, or the inner fence closes the outer one.

**Unclosed code fences.** An edit that eats a closing fence renders everything
after it as one monospace blob, and a plain-text diff looks fine. Count fences:
`awk '/^```/{n++} END{print n%2}'`.

**Documentation drift.** The same policy stated in two files will diverge. Keep one
authoritative statement and have the others link to it — especially for text that
gets copied into student repositories, where you cannot easily fix all the copies.

**Stale claims after a decision changes.** Submission tooling changed three times
here; each change left assertions behind in files nobody thought to check. After
any decision reversal, `grep` for the old tool's name across every document.

**Quarto default projects render everything.** Without a `render:` list, every
`.qmd` and `.md` becomes a published page. One site was serving 76 files and
6.6 MB instead of 3 files and 2.1 MB, including output from a deleted source file.

**Interactive zsh does not treat `#` as a comment.** Paste-ready commands with
trailing comments fail with confusing errors.

**Git deduplicates by content.** Identical files at different paths cost one
object. Cleaning up "duplicates" often saves nothing — measure before restructuring
for size.

---

## 11. Order of operations

```
[ ] Organization: base permissions = No permission
[ ] Organization: note who the owners are; adjust student-facing text accordingly
[ ] Create repositories in the org, WITHOUT auto-init
[ ] Notes repos: output-dir docs, gitignore derived files, add publish_site.sh
[ ] Test publish_site.sh against a local bare repo
[ ] Render, publish, set Pages source, set visibility, verify with curl
[ ] Record each generated subdomain in the READMEs
[ ] Course repo: syllabus (render list!), README, presentations.md, assignments/
[ ] Pull the academic calendar; compute sessions; check the session budget
[ ] Write the schedule; propagate dates everywhere; pick one authoritative file
[ ] Enable Discussions; keep Announcements + Q&A; add category forms; delete the rest
[ ] Push, then confirm the forms actually appear under New discussion
[ ] Create the team; grant Read on course + notes repos; add students
[ ] gh auth login; create_hw_repos.sh --team <slug>
[ ] Verify one real student sees an invitation and can upload
[ ] Pin the sign-up thread
```

---

## 12. Recurring work during the term

| When | What |
|---|---|
| Content changed | `quarto render && ./scripts/publish_site.sh`, then commit and push `main` |
| Late enrollment | Add to the team, re-run `create_hw_repos.sh --team <slug>` |
| After a deadline | `./scripts/check_submissions.sh <week> <deadline>` |
| Occasionally | `./scripts/feedback.sh <week> <user> "..."`, or comment in the web UI |
| End of term | Empty or delete the team — revokes access to all repositories at once |

### Publishing and pushing are independent — you need both

`publish_site.sh` copies your **local working-tree `docs/`** and force-pushes it to
`gh-pages`. It never reads `main`, locally or on the remote. So:

- **Pushing `main` does not update the site.** Only `publish_site.sh` does.
- **Publishing does not require `main` to be pushed.** The site can be current
  while your sources exist only on your laptop.

They serve different purposes and neither substitutes for the other: publishing
makes the site current, pushing makes your sources safe. Do both.

`git status` staying clean after a render is expected, not a failure: `docs/` is
gitignored.
