import { Effect, Schema } from 'effect';

export const reviewSkill = 'review-pr';

const maxDiffCharacters = 100_000;

const maxComments = 50;

const ReviewComment = Schema.Struct({
  path: Schema.NonEmptyString,
  side: Schema.Literal('LEFT', 'RIGHT'),
  line: Schema.Number.pipe(Schema.int()),
  body: Schema.NonEmptyString,
});

const ReviewBody = Schema.Struct({
  summary: Schema.NonEmptyString,
  comments: Schema.Array(ReviewComment),
});

export type ReviewComment = typeof ReviewComment.Type;

type Review = {
  readonly summary: string;
  readonly comments: readonly ReviewComment[];
};

export const diffTooLarge = (input: string) => input.length > maxDiffCharacters;

const fenced = /^```(?:json)?\s*([\s\S]*?)\s*```$/;

const reviewText = (text: string): string => {
  const trimmed = text.trim();
  const fence = fenced.exec(trimmed);
  const body = (fence?.[1] ?? trimmed).trim();
  if (body.startsWith('{') && body.endsWith('}')) {
    return body;
  }
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start === -1 || end < start) {
    throw new Error('review was not an object');
  }
  return body.slice(start, end + 1);
};

const targetKey = (path: string, side: 'LEFT' | 'RIGHT', line: number) =>
  `${path}\n${side}\n${line}`;

const headerPath = (line: string): string => {
  const rest = line.slice(4);
  const tab = rest.indexOf('\t');
  const raw = (tab === -1 ? rest : rest.slice(0, tab)).trim();
  const unquoted =
    raw.startsWith('"') && raw.endsWith('"') ? raw.slice(1, -1) : raw;
  if (unquoted === '/dev/null') {
    return unquoted;
  }
  if (unquoted.startsWith('a/') || unquoted.startsWith('b/')) {
    return unquoted.slice(2);
  }
  return unquoted;
};

const commentTargets = (diff: string): ReadonlySet<string> => {
  const targets = new Set<string>();
  let path: string | undefined;
  let oldPath: string | undefined;
  let inHunk = false;
  let left = 0;
  let right = 0;
  for (const raw of diff.split('\n')) {
    const line = raw.endsWith('\r') ? raw.slice(0, -1) : raw;
    if (line.startsWith('diff --git ')) {
      path = undefined;
      oldPath = undefined;
      inHunk = false;
      continue;
    }
    if (!inHunk && (line.startsWith('--- ') || line.startsWith('+++ '))) {
      const header = headerPath(line);
      if (line.startsWith('--- ')) {
        oldPath = header;
        continue;
      }
      path = header === '/dev/null' ? oldPath : header;
      if (path === '/dev/null') {
        path = undefined;
      }
      continue;
    }
    const hunk = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
    if (hunk !== null) {
      inHunk = true;
      left = Number(hunk[1]);
      right = Number(hunk[2]);
      continue;
    }
    if (!inHunk || path === undefined) {
      continue;
    }
    if (line.startsWith('\\')) {
      continue;
    }
    if (line.startsWith('+')) {
      targets.add(targetKey(path, 'RIGHT', right));
      right += 1;
      continue;
    }
    if (line.startsWith('-')) {
      const leftPath = oldPath === '/dev/null' ? path : (oldPath ?? path);
      targets.add(targetKey(leftPath, 'LEFT', left));
      left += 1;
      continue;
    }
    if (line.startsWith(' ')) {
      left += 1;
      right += 1;
    }
  }
  return targets;
};

const filterReview = (diff: string, review: Review): Review => {
  const targets = commentTargets(diff);
  return {
    summary: review.summary,
    comments: review.comments
      .filter((comment) =>
        targets.has(targetKey(comment.path, comment.side, comment.line)),
      )
      .slice(0, maxComments),
  };
};

export const readReview = (diff: string, text: string) =>
  Effect.try({
    try: () => JSON.parse(reviewText(text)) as unknown,
    catch: () => ({ kind: 'ReviewInvalid' as const }),
  }).pipe(
    Effect.flatMap((value) =>
      Schema.decodeUnknown(ReviewBody)(value).pipe(
        Effect.mapError(() => ({ kind: 'ReviewInvalid' as const })),
      ),
    ),
    Effect.map((review) => filterReview(diff, review)),
  );
