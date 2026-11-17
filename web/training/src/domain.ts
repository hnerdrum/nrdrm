export type Interval = {
  repetitions: number;
  distance?: number;
  duration?: number;
  recovery?: number;
};

export type ExerciseSet = {
  reps?: number;
  weight?: number;
  duration?: number;
};

export type Exercise = {
  name: string;
  sets: ExerciseSet[];
};

/** A steady stretch: a warmup, cooldown, easy or tempo part, or the rower
 * before lifting. Metres and/or seconds. */
export type Steady = {
  distance?: number;
  duration?: number;
  name?: string;
};

/** One part of a session, in order. A run, ride or ski takes steady and
 * repeats blocks; strength takes steady and exercise blocks. */
export type Block =
  | ({ kind: 'steady' } & Steady)
  | ({ kind: 'repeats' } & Interval)
  | ({ kind: 'exercise' } & Exercise);

export type Run = {
  sport: 'run';
  distance: number;
  duration: number;
  blocks?: Block[];
};

export type Ride = {
  sport: 'ride';
  distance: number;
  duration: number;
  blocks?: Block[];
};

export type Ski = {
  sport: 'ski';
  distance: number;
  duration: number;
  blocks?: Block[];
};

export type Strength = {
  sport: 'strength';
  blocks?: Block[];
};

export type SessionBody = Run | Ride | Ski | Strength;

/** The metres and seconds the blocks account for, as the server counts
 * them: steady adds both, repeats their work and the rests between, an
 * exercise nothing. */
export function blockTotals(blocks: Block[]): {
  distance: number;
  duration: number;
} {
  let distance = 0;
  let duration = 0;
  for (const block of blocks) {
    if (block.kind === 'steady') {
      distance += block.distance ?? 0;
      duration += block.duration ?? 0;
    } else if (block.kind === 'repeats') {
      if (block.distance) {
        distance += block.repetitions * block.distance;
      }
      if (block.duration) {
        duration +=
          block.repetitions * block.duration +
          Math.max(block.repetitions - 1, 0) * (block.recovery ?? 0);
      }
    }
  }
  return { distance, duration };
}

export function exercisesOf(body: SessionBody): Exercise[] {
  return (body.blocks ?? []).flatMap((block) =>
    block.kind === 'exercise' ? [{ name: block.name, sets: block.sets }] : [],
  );
}

export type WeekTotals = {
  runSeconds: number;
  rideSeconds: number;
  skiSeconds: number;
  skiMetres: number;
  strengthSessions: number;
};

export function weekTotals(sessions: { body: SessionBody }[]): WeekTotals {
  const totals: WeekTotals = {
    runSeconds: 0,
    rideSeconds: 0,
    skiSeconds: 0,
    skiMetres: 0,
    strengthSessions: 0,
  };

  for (const session of sessions) {
    const body = session.body;
    switch (body.sport) {
      case 'run':
        totals.runSeconds += body.duration;
        break;
      case 'ride':
        totals.rideSeconds += body.duration;
        break;
      case 'ski':
        totals.skiSeconds += body.duration;
        totals.skiMetres += body.distance;
        break;
      case 'strength':
        totals.strengthSessions += 1;
        break;
    }
  }

  return totals;
}
