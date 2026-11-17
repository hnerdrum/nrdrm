import {
  blockTotals,
  type Block,
  type Exercise,
  type ExerciseSet,
  type Interval,
  type SessionBody,
  type Steady,
  type Strength,
} from './domain';

export type DistanceSport = 'run' | 'ride' | 'ski';

export type SetMeasure = 'reps' | 'time';

export type DraftInterval = {
  key: string;
  repetitions: string;
  metres: string;
  minutes: string;
  seconds: string;
  recovery: string;
};

export type DraftSteady = {
  key: string;
  name: string;
  kilometres: string;
  minutes: string;
  seconds: string;
};

export type DraftSet = {
  key: string;
  reps: string;
  weight: string;
  minutes: string;
  seconds: string;
};

export type DraftExercise = {
  key: string;
  name: string;
  measure: SetMeasure;
  sets: DraftSet[];
};

export type DraftBlock =
  | ({ kind: 'steady' } & DraftSteady)
  | ({ kind: 'repeats' } & DraftInterval)
  | ({ kind: 'exercise' } & DraftExercise);

export type BlockKind = DraftBlock['kind'];

/** The block kinds a sport takes, in the order the form offers them. */
export function blockKinds(sport: SessionBody['sport']): BlockKind[] {
  return sport === 'strength' ? ['exercise', 'steady'] : ['steady', 'repeats'];
}

/** Names the form offers for a steady block. */
export const STEADY_NAMES = ['warmup', 'cooldown'] as const;

function draftKey(): string {
  return crypto.randomUUID();
}

export function emptySet(): DraftSet {
  return { key: draftKey(), reps: '', weight: '', minutes: '', seconds: '' };
}

export function emptyExercise(): DraftExercise {
  return { key: draftKey(), name: '', measure: 'reps', sets: [emptySet()] };
}

export function emptyInterval(): DraftInterval {
  return {
    key: draftKey(),
    repetitions: '1',
    metres: '',
    minutes: '',
    seconds: '',
    recovery: '',
  };
}

export function emptySteady(): DraftSteady {
  return {
    key: draftKey(),
    name: '',
    kilometres: '',
    minutes: '',
    seconds: '',
  };
}

export function emptyBlock(kind: BlockKind): DraftBlock {
  switch (kind) {
    case 'steady':
      return { kind, ...emptySteady() };
    case 'repeats':
      return { kind, ...emptyInterval() };
    case 'exercise':
      return { kind, ...emptyExercise() };
  }
}

function minutesAndSeconds(total: number): {
  minutes: string;
  seconds: string;
} {
  const minutes = Math.floor(total / 60);
  return {
    minutes: minutes > 0 ? String(minutes) : '',
    seconds: total > 0 ? String(total % 60) : '',
  };
}

function intervalDraft(interval: Interval): DraftInterval {
  return {
    key: draftKey(),
    repetitions: String(interval.repetitions),
    metres: interval.distance ? String(interval.distance) : '',
    ...minutesAndSeconds(interval.duration ?? 0),
    recovery: interval.recovery ? String(interval.recovery) : '',
  };
}

function steadyDraft(steady: Steady): DraftSteady {
  return {
    key: draftKey(),
    name: steady.name ?? '',
    kilometres: steady.distance ? String(steady.distance / 1000) : '',
    ...minutesAndSeconds(steady.duration ?? 0),
  };
}

function exerciseDraft(exercise: Exercise): DraftExercise {
  const measure: SetMeasure = exercise.sets.some((set) => set.duration != null)
    ? 'time'
    : 'reps';
  return {
    key: draftKey(),
    name: exercise.name,
    measure,
    sets:
      exercise.sets.length > 0
        ? exercise.sets.map((set) => draftSet(set, measure))
        : [emptySet()],
  };
}

export function blocksFrom(blocks: Block[]): DraftBlock[] {
  return blocks.map((block): DraftBlock => {
    switch (block.kind) {
      case 'steady':
        return { kind: 'steady', ...steadyDraft(block) };
      case 'repeats':
        return { kind: 'repeats', ...intervalDraft(block) };
      case 'exercise':
        return { kind: 'exercise', ...exerciseDraft(block) };
    }
  });
}

function draftSet(set: ExerciseSet, measure: SetMeasure): DraftSet {
  if (measure === 'time') {
    const total = set.duration ?? 0;
    const minutes = Math.floor(total / 60);
    return {
      key: draftKey(),
      reps: '',
      weight: '',
      minutes: minutes > 0 ? String(minutes) : '',
      seconds: String(total % 60),
    };
  }
  return {
    key: draftKey(),
    reps: set.reps == null ? '' : String(set.reps),
    weight: set.weight ? String(set.weight) : '',
    minutes: '',
    seconds: '',
  };
}

function parseDecimal(value: string): number | null {
  const trimmed = value.trim();
  if (!/^\d+(?:[.,]\d+)?$/.test(trimmed) && !/^\d+[.,]$/.test(trimmed)) {
    return null;
  }
  const parsed = Number(trimmed.replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : null;
}

function nonNegativeInt(value: string): number | null {
  const trimmed = value.trim();
  if (trimmed === '') {
    return 0;
  }
  if (!/^\d+$/.test(trimmed)) {
    return null;
  }
  return Number(trimmed);
}

function optionalMetres(value: string): number | null | undefined {
  const trimmed = value.trim();
  if (trimmed === '') {
    return undefined;
  }
  return positiveInt(trimmed);
}

function optionalDuration(
  minutes: string,
  seconds: string,
): number | null | undefined {
  if (minutes.trim() === '' && seconds.trim() === '') {
    return undefined;
  }
  const parsedMinutes = nonNegativeInt(minutes);
  const parsedSeconds = nonNegativeInt(seconds);
  if (parsedMinutes === null || parsedSeconds === null) {
    return null;
  }
  const duration = parsedMinutes * 60 + parsedSeconds;
  return duration >= 1 ? duration : null;
}

function positiveInt(value: string): number | null {
  const trimmed = value.trim();
  if (!/^\d+$/.test(trimmed)) {
    return null;
  }
  const parsed = Number(trimmed);
  return parsed >= 1 ? parsed : null;
}

function measured(
  kilometresText: string,
  hoursText: string,
  minutesText: string,
): { kilometres: number; minutes: number; metres: number } | null {
  const kilometres = parseDecimal(kilometresText);
  const hours = nonNegativeInt(hoursText);
  const minutes = nonNegativeInt(minutesText);
  if (
    kilometres === null ||
    kilometres <= 0 ||
    hours === null ||
    minutes === null
  ) {
    return null;
  }
  const totalMinutes = hours * 60 + minutes;
  if (totalMinutes <= 0) {
    return null;
  }
  const metres = Math.round(kilometres * 1000);
  if (metres <= 0) {
    return null;
  }
  return { kilometres, minutes: totalMinutes, metres };
}

function steadyBlock(draft: DraftSteady): Block | null {
  const name = draft.name.trim();
  const kilometresText = draft.kilometres.trim();
  let distance: number | undefined;
  if (kilometresText !== '') {
    const kilometres = parseDecimal(kilometresText);
    if (kilometres === null) {
      return null;
    }
    distance = Math.round(kilometres * 1000);
  }
  const duration = optionalDuration(draft.minutes, draft.seconds);
  if (duration === null) {
    return null;
  }
  if (!distance && duration === undefined) {
    return null;
  }
  const block: Block = { kind: 'steady' };
  if (distance) {
    block.distance = distance;
  }
  if (duration !== undefined) {
    block.duration = duration;
  }
  if (name) {
    block.name = name;
  }
  return block;
}

function repeatsBlock(draft: DraftInterval): Block | null {
  const repetitions = positiveInt(draft.repetitions);
  const metres = optionalMetres(draft.metres);
  const repeat = optionalDuration(draft.minutes, draft.seconds);
  const recovery = nonNegativeInt(draft.recovery);
  if (
    repetitions === null ||
    metres === null ||
    repeat === null ||
    recovery === null
  ) {
    return null;
  }
  if (metres === undefined && repeat === undefined) {
    return null;
  }
  const block: Block = { kind: 'repeats', repetitions };
  if (metres !== undefined) {
    block.distance = metres;
  }
  if (repeat !== undefined) {
    block.duration = repeat;
  }
  if (recovery > 0) {
    block.recovery = recovery;
  }
  return block;
}

function exerciseBlock(draft: DraftExercise): Block | null {
  const name = draft.name.trim();
  if (!name || draft.sets.length === 0) {
    return null;
  }
  const sets: ExerciseSet[] = [];
  for (const set of draft.sets) {
    if (draft.measure === 'time') {
      const minutes = nonNegativeInt(set.minutes);
      const seconds = nonNegativeInt(set.seconds);
      if (minutes === null || seconds === null) {
        return null;
      }
      const duration = minutes * 60 + seconds;
      if (duration < 1) {
        return null;
      }
      sets.push({ duration });
      continue;
    }
    const reps = positiveInt(set.reps);
    const weightText = set.weight.trim();
    const weight = weightText === '' ? 0 : parseDecimal(set.weight);
    if (reps === null || weight === null || weight < 0) {
      return null;
    }
    sets.push(weight === 0 ? { reps } : { reps, weight });
  }
  return { kind: 'exercise', name, sets };
}

const BLOCK_PROBLEM: Record<BlockKind, string> = {
  steady: 'Give each steady part a distance or a time.',
  repeats: 'Enter repeats, and metres or a time, for every interval.',
  exercise: 'Name each exercise. Enter reps or a time for every set.',
};

/** The blocks the drafts show, or what to fix in the first one that isn't
 * whole. */
export function buildBlocks(drafts: DraftBlock[]): Block[] | string {
  const built: Block[] = [];
  for (const draft of drafts) {
    const block =
      draft.kind === 'steady'
        ? steadyBlock(draft)
        : draft.kind === 'repeats'
          ? repeatsBlock(draft)
          : exerciseBlock(draft);
    if (!block) {
      return BLOCK_PROBLEM[draft.kind];
    }
    built.push(block);
  }
  return built;
}

/** What the blocks add up to, for the readouts, or null while one isn't
 * whole. */
export function draftTotals(
  drafts: DraftBlock[],
): { distance: number; duration: number } | null {
  const built = buildBlocks(drafts);
  return typeof built === 'string' ? null : blockTotals(built);
}

export function derivedEffort(
  sport: DistanceSport,
  kilometres: string,
  hours: string,
  minutes: string,
): { label: 'Pace' | 'Speed'; value: string } | null {
  const effort = measured(kilometres, hours, minutes);
  if (!effort) {
    return null;
  }
  if (sport === 'ride') {
    const speed = effort.kilometres / (effort.minutes / 60);
    return { label: 'Speed', value: `${speed.toFixed(1)} km/h` };
  }
  const seconds = Math.round((effort.minutes * 60) / effort.kilometres);
  const paceMinutes = Math.floor(seconds / 60);
  const paceSeconds = seconds % 60;
  return {
    label: 'Pace',
    value: `${paceMinutes}:${String(paceSeconds).padStart(2, '0')} /km`,
  };
}

export function intervalReadout(
  sport: DistanceSport,
  interval: DraftInterval,
): string | null {
  const metres = positiveInt(interval.metres);
  const minutes = nonNegativeInt(interval.minutes);
  const seconds = nonNegativeInt(interval.seconds);
  if (metres === null || minutes === null || seconds === null) {
    return null;
  }
  const duration = minutes * 60 + seconds;
  if (duration < 1) {
    return null;
  }
  if (sport === 'ride') {
    const speed = (metres * 3.6) / duration;
    return `${speed.toFixed(1)} km/h`;
  }
  const perKm = Math.round((duration * 1000) / metres);
  const paceMinutes = Math.floor(perKm / 60);
  const paceSeconds = perKm % 60;
  return `${paceMinutes}:${String(paceSeconds).padStart(2, '0')} /km`;
}

/** The run, ride and ski fields. They are shared, so switching between
 * those sports keeps what was typed. A total left blank is what the blocks
 * add up to, so it follows them as they change; a typed one stays. */
export type DistanceDraft = {
  kilometres: string;
  hours: string;
  minutes: string;
  blocks: DraftBlock[];
};

export function emptyDistanceDraft(): DistanceDraft {
  return { kilometres: '', hours: '', minutes: '', blocks: [] };
}

/** The form fields that show a body: the totals and blocks of a run, ride
 * or ski, or the blocks of a strength session. */
export type BodyDraft =
  | { sport: DistanceSport; distance: DistanceDraft }
  | { sport: 'strength'; blocks: DraftBlock[] };

export function draftFrom(body: SessionBody): BodyDraft {
  const blocks = body.blocks ?? [];
  if (body.sport === 'strength') {
    return { sport: 'strength', blocks: blocksFrom(blocks) };
  }
  // A total that is just what the blocks add up to stays blank, so it keeps
  // following them. Any other total, such as the watch's, is shown.
  const sums = blockTotals(blocks);
  const followDistance = blocks.length > 0 && body.distance === sums.distance;
  const followDuration = blocks.length > 0 && body.duration === sums.duration;
  const totalMinutes = Math.round(body.duration / 60);
  return {
    sport: body.sport,
    distance: {
      kilometres: followDistance ? '' : String(body.distance / 1000),
      hours: followDuration ? '' : String(Math.floor(totalMinutes / 60)),
      minutes: followDuration ? '' : String(totalMinutes % 60),
      blocks: blocksFrom(blocks),
    },
  };
}

function distanceBody(
  sport: DistanceSport,
  draft: DistanceDraft,
): SessionBody | string {
  const blocks = buildBlocks(draft.blocks);
  if (typeof blocks === 'string') {
    return blocks;
  }
  const kilometresBlank = draft.kilometres.trim() === '';
  const timeBlank = draft.hours.trim() === '' && draft.minutes.trim() === '';
  if (blocks.length === 0) {
    const effort = measured(draft.kilometres, draft.hours, draft.minutes);
    if (!effort) {
      return 'Enter a distance and a time.';
    }
    return { sport, distance: effort.metres, duration: effort.minutes * 60 };
  }

  const sums = blockTotals(blocks);
  let distance = sums.distance;
  if (!kilometresBlank) {
    const kilometres = parseDecimal(draft.kilometres);
    if (kilometres === null) {
      return 'Enter the distance in kilometres, or leave it blank.';
    }
    distance = Math.round(kilometres * 1000);
  }
  let duration = sums.duration;
  if (!timeBlank) {
    const hours = nonNegativeInt(draft.hours);
    const minutes = nonNegativeInt(draft.minutes);
    if (hours === null || minutes === null) {
      return 'Enter the time in hours and minutes, or leave it blank.';
    }
    duration = (hours * 60 + minutes) * 60;
  }
  if (distance < 1 && duration < 1) {
    return 'Enter a distance or a time, here or in the blocks.';
  }
  if (distance > 0xffffffff || duration > 0xffffffff) {
    return 'That session is too long to store.';
  }
  if (distance < sums.distance || duration < sums.duration) {
    return 'The blocks add up to more than the distance and time. Leave them blank to use the blocks.';
  }
  return { sport, distance, duration, blocks };
}

function strengthBody(drafts: DraftBlock[]): Strength | string {
  if (!drafts.some((draft) => draft.kind === 'exercise')) {
    return 'Add an exercise.';
  }
  const blocks = buildBlocks(drafts);
  if (typeof blocks === 'string') {
    return blocks;
  }
  return { sport: 'strength', blocks };
}

/** The body the form shows for `sport`, or what to fix before it can be
 * saved. */
export function buildBody(
  sport: SessionBody['sport'],
  distance: DistanceDraft,
  strength: DraftBlock[],
): SessionBody | string {
  if (sport === 'strength') {
    return strengthBody(strength);
  }
  return distanceBody(sport, distance);
}
