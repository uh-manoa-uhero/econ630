# Week 1 — ISLR 1 + 2 — Statistical learning, bias–variance, KNN

Sessions: **Tue 08/25** (course intro, instructor-led) and **Thu 08/27**.

**No write-up is collected for Week 1.** This material is introduced in class, and
the Sunday-before deadline would fall on 08/23, before the semester begins. The
first submission is Week 2's, due **Sun 08/30 at 8 pm** — so read ISLR 3 and write
that up during Week 1. See [the deadline table](README.md#deadlines).

Still do everything below: it is what the Thursday session works through, and
Midterm 1 covers it.

Week 1 also starts the R onboarding. No prior R is assumed — the Ch 2 lab is
deliberately gentle, and Weeks 1–3 ramp up together with a statistics review.

## Prepare before Tuesday

| Step | What | Roughly |
|---|---|---|
| 1. Read | ISLR Ch 1 and Ch 2 — [statlearning.com](https://www.statlearning.com/) | 2–3 hrs |
| 2. Watch | Stanford *Statistical Learning*, Ch 1–2 — [YouTube playlist](https://www.youtube.com/playlist?list=PLOg0ngHtcqbPTlZzRHA2ocQZqB1D_qZ5V) | 2 hrs |
| 3. Review | [Prediction & time series notes](https://special-adventure-gw99jmk.pages.github.io/) — Ch 1 and 2 | 1–2 hrs |
| 4. Run | `chapters/chap02.R` from the notes — edit and re-run it | 2 hrs |
| 5. Self-check | ISLR Ch 2 applied exercises against the published solutions | 2 hrs |

**Install R and Positron before the first session** if you have not already — see
*Required hardware and software* in the syllabus. Bring the laptop to class.

## Do this during Week 1 (not collected)

1. **Summary** — one to two pages on what statistical learning is and the
   bias–variance tradeoff. In your own words: why does test error fall and then
   rise as flexibility increases, and what makes KNN more flexible at small *k*?
2. **Conceptual exercises** — ISLR Ch 2, exercises **1, 2, 3, and 4**.

Exercise 3 asks you to sketch the bias, variance, training-error, test-error, and
irreducible-error curves and explain their shapes. Draw it by hand and label the
axes — this is the single most useful figure in the first half of the course, and
you will refer back to it in Blocks II and III. Keep it; you will want it before
Midterm 1.

## For the presenter

I lead the Tuesday session in Week 1 (course intro plus Ch 1–2), so the Thursday
slot is the first student-led session. See [presentations.md](../presentations.md).

## Watch out for

- **Flexibility is not accuracy.** The most flexible model wins on *training*
  error essentially by construction; the whole subject exists because that tells
  you almost nothing about test error.
- **Small *k* means more flexible, not less.** `k = 1` fits every training point
  exactly. Students routinely have this backwards on the first midterm.
- **Irreducible error does not go away.** No amount of model tuning removes it.
  Knowing where the floor is stops you from chasing it.
