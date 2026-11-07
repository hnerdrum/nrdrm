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
  withPack: boolean;
};

export type ExerciseSet = {
  reps: number;
  weight: number;
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
