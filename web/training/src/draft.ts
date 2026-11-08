import type { Ride, Run, RunInterval, Ski, Strength } from './domain';

export type DistanceSport = 'run' | 'ride' | 'ski';

export type SetMeasure = 'reps' | 'time';

export type RunKind = 'distance' | 'intervals';

export type DraftInterval = {
  key: string;
  repetitions: string;
  metres: string;
  minutes: string;
  seconds: string;
  recovery: string;
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

export function intervalsFrom(intervals: RunInterval[]): DraftInterval[] {
  return intervals.map((interval) => {
    const minutes = Math.floor(interval.duration / 60);
    return {
      key: draftKey(),
      repetitions: String(interval.repetitions),
      metres: String(interval.distance),
      minutes: minutes > 0 ? String(minutes) : '',
      seconds: String(interval.duration % 60),
      recovery: interval.recovery ? String(interval.recovery) : '',
    };
  });
}

export function exercisesFrom(body: Strength): DraftExercise[] {
  return body.exercises.map((exercise) => {
    const measure: SetMeasure = exercise.sets.some(
      (set) => set.duration != null,
    )
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
  });
}

function draftSet(
  set: Strength['exercises'][number]['sets'][number],
  measure: SetMeasure,
): DraftSet {
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

export function distanceDraft(body: Run | Ride | Ski): {
  kilometres: string;
  hours: string;
  minutes: string;
} {
  const totalMinutes = Math.round(body.duration / 60);
  return {
    kilometres: String(body.distance / 1000),
    hours: String(Math.floor(totalMinutes / 60)),
    minutes: String(totalMinutes % 60),
  };
}

export function distanceBody(
  sport: DistanceSport,
  kilometres: string,
  hours: string,
  minutes: string,
): Run | Ride | Ski | null {
  const effort = measured(kilometres, hours, minutes);
  if (!effort) {
    return null;
  }
  return {
    sport,
    distance: effort.metres,
    duration: effort.minutes * 60,
  };
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

export function intervalPace(interval: DraftInterval): string | null {
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
  const perKm = Math.round((duration * 1000) / metres);
  const paceMinutes = Math.floor(perKm / 60);
  const paceSeconds = perKm % 60;
  return `${paceMinutes}:${String(paceSeconds).padStart(2, '0')} /km`;
}

export function intervalBody(intervals: DraftInterval[]): Run | null {
  if (intervals.length === 0) {
    return null;
  }
  const built: RunInterval[] = [];
  for (const interval of intervals) {
    const repetitions = positiveInt(interval.repetitions);
    const metres = positiveInt(interval.metres);
    const minutes = nonNegativeInt(interval.minutes);
    const seconds = nonNegativeInt(interval.seconds);
    const recovery = nonNegativeInt(interval.recovery);
    if (
      repetitions === null ||
      metres === null ||
      minutes === null ||
      seconds === null ||
      recovery === null
    ) {
      return null;
    }
    const duration = minutes * 60 + seconds;
    if (duration < 1) {
      return null;
    }
    built.push(
      recovery > 0
        ? { repetitions, distance: metres, duration, recovery }
        : { repetitions, distance: metres, duration },
    );
  }
  let distance = 0;
  let duration = 0;
  for (const interval of built) {
    distance += interval.repetitions * interval.distance;
    const recovery = interval.recovery ?? 0;
    duration +=
      interval.repetitions * interval.duration +
      Math.max(interval.repetitions - 1, 0) * recovery;
  }
  if (
    !Number.isSafeInteger(distance) ||
    !Number.isSafeInteger(duration) ||
    distance < 1 ||
    distance > 0xffffffff ||
    duration > 0xffffffff
  ) {
    return null;
  }
  return { sport: 'run', distance, duration, intervals: built };
}

export function strengthBody(exercises: DraftExercise[]): Strength | null {
  if (exercises.length === 0) {
    return null;
  }
  const built: Strength['exercises'] = [];
  for (const exercise of exercises) {
    const name = exercise.name.trim();
    if (!name || exercise.sets.length === 0) {
      return null;
    }
    const sets: Strength['exercises'][number]['sets'] = [];
    for (const set of exercise.sets) {
      if (exercise.measure === 'time') {
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
    built.push({ name, sets });
  }
  return { sport: 'strength', exercises: built };
}
