#!/usr/bin/env bash
# Create the per-session threads of the exam question pool, in the "Exam
# questions" discussion category.
#
#   ./scripts/exam_question_threads.sh --dry-run          # show what would be created
#   ./scripts/exam_question_threads.sh --guide            # the pinned "how this works" thread
#   ./scripts/exam_question_threads.sh --block I          # one block's sessions
#   ./scripts/exam_question_threads.sh                    # every session, all three blocks
#
# Safe to re-run: a thread whose title already exists in the category is skipped,
# so re-run it after editing the session table below and only the new threads are
# created. Nothing is ever edited or deleted.
#
# One thread per class session, and each leader posts their five questions as five
# separate comments in their own session's thread. The comment is the unit of
# upvoting on GitHub -- upvoteCount lives on the comment, not on the question --
# so five questions in one comment would only ever get one score between them.
# One thread per session (rather than one per question) keeps the category
# browsable and puts each leader's questions where the class expects to find them.
#
# The category itself cannot be created from here: GitHub exposes no API for
# creating discussion categories. Create it once, by hand:
#
#   Discussions -> the pencil next to "Categories" -> New category
#     Name:   Exam questions
#     Emoji:  :question:
#     Format: Open-ended discussion        <- not Announcement, not Q&A, not Poll
#     Desc:   Session leaders propose exam questions; the class upvotes them.
#
# "Open-ended discussion" is the format that allows comment upvotes. Announcement
# would also stop students from posting at all.
set -euo pipefail

cd "$(dirname "$0")/.."

ORG=uh-manoa-uhero
REPO=econ630
CATEGORY_SLUG=exam-questions

# Sessions, one per line: block | week | date | topic | leader
# Instructor-led sessions, exam days, and the two holiday cancellations are absent
# on purpose. Keep this in sync with presentations.md when the schedule shifts.
SESSIONS=$(cat <<'EOF'
I|1|Thu 08/27|ISLR 1 + 2 -- statistical learning, bias-variance, KNN|Albert
I|2|Tue 09/01|ISLR 3 -- linear regression|Michelle
I|2|Thu 09/03|ISLR 3 -- linear regression|Vanessa
I|3|Tue 09/08|ISLR 4 -- classification: logistic, LDA/QDA, naive Bayes|Hao
I|3|Thu 09/10|ISLR 4 -- classification: logistic, LDA/QDA, naive Bayes|Marzuka
I|4|Tue 09/15|ISLR 5 -- resampling: cross-validation and the bootstrap|Rei
I|4|Thu 09/17|ISLR 5 -- resampling: cross-validation and the bootstrap|Michelle
I|5|Tue 09/22|ISLR 6 -- model selection and regularization|Vanessa
I|5|Thu 09/24|ISLR 6 -- model selection and regularization|Daewon
I|6|Tue 09/29|ISLR 7 -- beyond linearity: polynomials, splines, GAMs|Albert
II|7|Tue 10/06|ISLR 8 -- trees, random forests, boosting, BART|Tim
II|7|Thu 10/08|ISLR 8 -- trees, random forests, boosting, BART|Vanessa
II|8|Tue 10/13|ISLR 9 + 12 -- SVMs; unsupervised learning|Marzuka
II|8|Thu 10/15|ISLR 9 + 12 -- SVMs; unsupervised learning|Daewon
II|9|Tue 10/20|ISLR 10 -- deep learning|Hao
II|9|Thu 10/22|ISLR 10 -- deep learning|Hao
II|10|Tue 10/27|Verbeek 14 -- univariate time series: ARMA, unit roots|Vanessa
II|10|Thu 10/29|Verbeek 14 -- univariate time series: ARMA, unit roots|Michelle
II|11|Thu 11/05|Verbeek 15 -- VAR, cointegration, VECM|Tim
II|12|Tue 11/10|Verbeek 15 -- VAR, cointegration, VECM|Tim
III|13|Tue 11/17|Effect 5-8 + 10 -- identification, DAGs, back doors, treatment effects|Daewon
III|13|Thu 11/19|Effect 5-8 + 10 -- identification, DAGs, back doors, treatment effects|Rei
III|14|Tue 11/24|Effect 13 + 14 -- regression as causal adjustment; matching|Rei
III|15|Tue 12/01|Effect 16 + 17 + 18 -- fixed effects; event studies; DiD|Daewon
III|15|Thu 12/03|Effect 16 + 17 + 18 -- fixed effects; event studies; DiD|Michelle
III|16|Tue 12/08|Effect 19 + 20 -- instrumental variables; regression discontinuity|Hamid
III|16|Thu 12/10|Effect 19 + 20 -- instrumental variables; regression discontinuity|Hamid and Marzuka
EOF
)

exam_name() {
  case "$1" in
    I)   echo "Midterm 1" ;;
    II)  echo "Midterm 2" ;;
    III) echo "Final Exam" ;;
  esac
}

exam_detail() {
  case "$1" in
    I)   echo "**Midterm 1 -- Thu 10/01**, in class. Covers ISLR Ch 1-7." ;;
    II)  echo "**Midterm 2 -- Thu 11/12**, in class. Covers ISLR Ch 8-12 + Time Series Ch 14-15." ;;
    III) echo "**Final Exam -- 12/14-12/18**, slot TBA. Covers the causal material from *The Effect*." ;;
  esac
}

want_block=all
dry_run=false
guide_only=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --guide)   guide_only=true ;;
    --block)
      want_block=${2:-}
      case "$want_block" in
        I|II|III) ;;
        *) echo "error: --block takes I, II, or III" >&2; exit 1 ;;
      esac
      shift
      ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; exit 1 ;;
  esac
  shift
done

if ! command -v gh >/dev/null 2>&1; then
  echo "error: the gh CLI is required -- install it with: brew install gh" >&2
  exit 1
fi

# Repository and category ids, and the titles already posted, in one round trip.
lookup=$(gh api graphql \
  -f owner="$ORG" -f repo="$REPO" -f slug="$CATEGORY_SLUG" \
  -f query='
    query($owner:String!, $repo:String!) {
      repository(owner:$owner, name:$repo) {
        id
        discussionCategories(first:50) { nodes { id slug } }
        discussions(first:100) { nodes { title category { slug } } }
      }
    }')

repo_id=$(printf '%s' "$lookup" | python3 -c '
import json,sys
print(json.load(sys.stdin)["data"]["repository"]["id"])')

category_id=$(printf '%s' "$lookup" | python3 -c '
import json,sys
slug = "'"$CATEGORY_SLUG"'"
nodes = json.load(sys.stdin)["data"]["repository"]["discussionCategories"]["nodes"]
print(next((n["id"] for n in nodes if n["slug"] == slug), ""))')

if [ -z "$category_id" ]; then
  cat >&2 <<EOF
error: no discussion category with slug '$CATEGORY_SLUG' in $ORG/$REPO.

GitHub has no API for creating categories, so create it once by hand:
  https://github.com/$ORG/$REPO/discussions/categories

  Name: Exam questions   Emoji: :question:   Format: Open-ended discussion
  Description: Session leaders propose exam questions; the class upvotes them.

Then re-run this script.
EOF
  exit 1
fi

existing=$(printf '%s' "$lookup" | python3 -c '
import json,sys
slug = "'"$CATEGORY_SLUG"'"
nodes = json.load(sys.stdin)["data"]["repository"]["discussions"]["nodes"]
for n in nodes:
    if n["category"]["slug"] == slug:
        print(n["title"])')

already_posted() {
  printf '%s\n' "$existing" | grep -Fxq "$1"
}

create_discussion() {
  local title=$1 body=$2 pin=${3:-false}

  if already_posted "$title"; then
    echo "  exists, skipped: $title"
    return
  fi

  if [ "$dry_run" = true ]; then
    echo "  would create: $title"
    return
  fi

  local id
  id=$(gh api graphql \
    -f repoId="$repo_id" -f catId="$category_id" -f title="$title" -f body="$body" \
    -f query='
      mutation($repoId:ID!, $catId:ID!, $title:String!, $body:String!) {
        createDiscussion(input:{
          repositoryId:$repoId, categoryId:$catId, title:$title, body:$body
        }) { discussion { id number } }
      }' \
    --jq '.data.createDiscussion.discussion.id')

  echo "  created: $title"

  if [ "$pin" = true ]; then
    gh api graphql -f id="$id" -f query='
      mutation($id:ID!) { pinDiscussion(input:{discussionId:$id}) {
        discussion { number } } }' >/dev/null 2>&1 \
      || echo "  note: could not pin it -- pin it by hand in the web UI"
  fi
}

guide_body() {
  cat <<'EOF'
Every exam in this course is built partly out of questions you write.

## If you led a session

Within a week of leading, post **five** questions you would like to see on the
exam, in **your session's thread** in this category. **One question per comment,
five separate comments** -- GitHub counts upvotes per comment, so five questions
crammed into one comment can only ever share a single score.

Each comment: the question, then a short answer key.

> **Question.** A colleague fits a model with 40 predictors and 50 observations
> and reports an R-squared of 0.98. Why is that number close to meaningless here,
> and what would you ask to see instead?
>
> **Answer.** R-squared is non-decreasing in the number of predictors and with
> p near n the fit is essentially interpolating noise ... ask for test-set or
> cross-validated error, or an adjusted / penalized criterion.

A question that works on an exam here is one a prepared classmate can answer in
**5-10 minutes, closed-book and closed-notes**, drawn from the material of *your*
session: explain a concept, interpret given output, take a short derivation two
or three steps, or choose between methods and defend the choice. Questions
needing a computer, or a formula nobody could reasonably hold in their head, do
not survive that filter.

## Everyone else

**Upvote** the questions you want on the exam -- the arrow at the top-left of
each comment. Upvoting is open all semester and closes when the exam is
distributed. Vote for the questions worth asking, not for your friends.

You may also reply to a question to point out that it is ambiguous, has two
defensible answers, or is already covered elsewhere. That is useful; a reply is
not a place for a second question of your own.

## What I do with them

I read every question in the pool for the block before writing the exam, and
upvotes tell me what the class considers fair and central. The exam is composed
of the questions **I** choose -- some from the pool as posted, some reworked, some
mine. A high-scoring question is not a promise, and nothing here narrows what an
exam may cover: the coverage in the syllabus stands either way.

Writing five questions is the fastest way to find out whether you actually
understood the chapter you taught. That is the point of the exercise.

## Which exam a session feeds

| Block | Sessions | Exam |
|---|---|---|
| I | Weeks 1-6 | **Midterm 1** -- Thu 10/01 |
| II | Weeks 7-12 | **Midterm 2** -- Thu 11/12 |
| III | Weeks 13-16 | **Final** -- 12/14-12/18, slot TBA |

Thread titles carry the exam name, so searching this category for `Midterm 1`
gives you that block's pool.
EOF
}

session_body() {
  local leader=$1 block=$2 topic=$3
  cat <<EOF
**Session leader: $leader.** Post your **five** exam questions here once you have
led this session -- **one question per comment**, five separate comments, each
with a short answer key. Upvotes are counted per comment, which is why one
question per comment matters.

Feeds $(exam_detail "$block")

**Topic.** $topic

Everyone: **upvote** the questions you want to see on the exam. Post questions
only in the thread of a session you led -- see the pinned *How the exam question
pool works* thread for the format and what makes a question exam-worthy.
EOF
}

if [ "$guide_only" = true ]; then
  echo "Guide thread:"
  create_discussion "How the exam question pool works" "$(guide_body)" true
  exit 0
fi

echo "Session threads (block: $want_block):"
printf '%s\n' "$SESSIONS" | while IFS='|' read -r block week date topic leader; do
  [ -n "$block" ] || continue
  if [ "$want_block" != all ] && [ "$want_block" != "$block" ]; then
    continue
  fi
  title="[$(exam_name "$block")] Week $week, $date -- ${topic%% --*} -- $leader"
  create_discussion "$title" "$(session_body "$leader" "$block" "$topic")"
done
