import { exercisesOf, type Block, type SessionBody } from './domain';

export function plural(count: number, one: string, many: string): string {
  return `${count} ${count === 1 ? one : many}`;
}

export function durationParts(seconds: number): {
  hours: number;
  minutes: number;
} {
  const totalMinutes = Math.floor(seconds / 60);
  return {
    hours: Math.floor(totalMinutes / 60),
    minutes: totalMinutes % 60,
  };
}

export function durationDigitCount(seconds: number): number {
  const { hours, minutes } = durationParts(seconds);
  if (hours > 0) {
    return String(hours).length + 2;
  }
  return String(minutes).length;
}

export function formatDuration(seconds: number): string {
  const { hours, minutes } = durationParts(seconds);
  if (hours > 0) {
    return `${hours}h ${String(minutes).padStart(2, '0')}m`;
  }
  return `${minutes}m`;
}

export function formatKm(metres: number): string {
  return `${(metres / 1000).toFixed(1)} km`;
}

function formatRepeatDistance(metres: number): string {
  if (metres >= 1000) {
    return formatKm(metres);
  }
  return `${metres} m`;
}

function formatRepeat(interval: {
  distance?: number;
  duration?: number;
}): string {
  if (interval.distance) {
    return formatRepeatDistance(interval.distance);
  }
  const seconds = interval.duration ?? 0;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

const SPORT_LABEL = {
  run: 'Run',
  ride: 'Ride',
  ski: 'Ski',
  strength: 'Strength',
} as const;

export function sportLabel(sport: SessionBody['sport']): string {
  return SPORT_LABEL[sport];
}

/** The main figure of a session for its row: the exercise count, the
 * repeats when there is one set of them, the number of interval blocks, or
 * the distance. Steady blocks such as a warmup don't change it. */
export function sessionMain(body: SessionBody): {
  text: string;
  plain: boolean;
} {
  if (body.sport === 'strength') {
    return {
      text: plural(exercisesOf(body).length, 'exercise', 'exercises'),
      plain: true,
    };
  }
  const repeats = (body.blocks ?? []).filter(
    (block) => block.kind === 'repeats',
  );
  if (repeats.length === 1) {
    const interval = repeats[0];
    return {
      text: `${interval.repetitions} × ${formatRepeat(interval)}`,
      plain: false,
    };
  }
  if (repeats.length > 1) {
    return {
      text: plural(repeats.length, 'interval', 'intervals'),
      plain: true,
    };
  }
  return { text: formatKm(body.distance), plain: false };
}

function formatSteady(block: Block & { kind: 'steady' }): string {
  const parts: string[] = [];
  if (block.distance) {
    parts.push(formatKm(block.distance));
  }
  if (block.duration) {
    parts.push(formatDuration(block.duration));
  }
  return [block.name ?? 'steady', ...parts].join(' ');
}

/** One block as a few words, such as "warmup 15m" or "5 × 1.0 km". */
export function formatBlock(block: Block): string {
  switch (block.kind) {
    case 'steady':
      return formatSteady(block);
    case 'repeats':
      return `${block.repetitions} × ${formatRepeat(block)}`;
    case 'exercise':
      return block.name;
  }
}

export function sessionDuration(body: SessionBody): string | null {
  if (body.sport === 'strength' || body.duration === 0) {
    return null;
  }
  return formatDuration(body.duration);
}

/** One line that says what a preset holds: its blocks in order, or its
 * distance, and the time of a run, ride or ski. */
export function presetSummary(body: SessionBody): string {
  const blocks = (body.blocks ?? []).map(formatBlock);
  if (body.sport === 'strength') {
    return blocks.join(', ');
  }
  const main = blocks.length > 0 ? blocks.join(', ') : sessionMain(body).text;
  const duration = sessionDuration(body);
  return duration ? `${main} · ${duration}` : main;
}
