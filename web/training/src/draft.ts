import type { Ride, Run, Ski, Strength } from './domain';

export type DistanceSport = 'run' | 'ride' | 'ski';

export type DraftSet = {
  key: string;
  reps: string;
  weight: string;
};

export type DraftExercise = {
  key: string;
  name: string;
  sets: DraftSet[];
};

function draftKey(): string {
  return crypto.randomUUID();
}

export function emptySet(): DraftSet {
  return { key: draftKey(), reps: '', weight: '' };
}

export function emptyExercise(): DraftExercise {
  return { key: draftKey(), name: '', sets: [emptySet()] };
}

export function exercisesFrom(body: Strength): DraftExercise[] {
  return body.exercises.map((exercise) => ({
    key: draftKey(),
    name: exercise.name,
    sets:
      exercise.sets.length > 0
        ? exercise.sets.map((set) => ({
            key: draftKey(),
            reps: String(set.reps),
            weight: String(set.weight),
          }))
        : [emptySet()],
  }));
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
      const reps = positiveInt(set.reps);
      const weight = parseDecimal(set.weight);
      if (reps === null || weight === null || weight < 0) {
        return null;
      }
      sets.push({ reps, weight });
    }
    built.push({ name, sets });
  }
  return { sport: 'strength', exercises: built };
}
