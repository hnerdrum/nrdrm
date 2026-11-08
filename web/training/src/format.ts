import type { SessionBody } from './domain';

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

const SPORT_LABEL = {
  run: 'Run',
  ride: 'Ride',
  ski: 'Ski',
  strength: 'Strength',
} as const;

export function sportLabel(sport: SessionBody['sport']): string {
  return SPORT_LABEL[sport];
}

export function sessionMain(body: SessionBody): {
  text: string;
  plain: boolean;
} {
  if (body.sport === 'strength') {
    return {
      text: plural(body.exercises.length, 'exercise', 'exercises'),
      plain: true,
    };
  }
  if (body.intervals && body.intervals.length > 0) {
    if (body.intervals.length === 1) {
      const interval = body.intervals[0];
      return {
        text: `${interval.repetitions} × ${formatRepeatDistance(interval.distance)}`,
        plain: false,
      };
    }
    return {
      text: plural(body.intervals.length, 'interval', 'intervals'),
      plain: true,
    };
  }
  return { text: formatKm(body.distance), plain: false };
}

export function sessionDuration(body: SessionBody): string | null {
  if (body.sport === 'strength') {
    return null;
  }
  return formatDuration(body.duration);
}
