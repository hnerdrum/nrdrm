export type Run = {
  sport: 'run';
  distance: number;
  duration: number;
};

export type Ride = {
  sport: 'ride';
  distance: number;
  duration: number;
};

export type Ski = {
  sport: 'ski';
  distance: number;
  duration: number;
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

export type Strength = {
  sport: 'strength';
  exercises: Exercise[];
};

export type SessionBody = Run | Ride | Ski | Strength;

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
