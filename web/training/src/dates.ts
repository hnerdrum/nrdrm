const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

export type RangeParts = {
  main: string;
  year: string;
};

function parseDate(iso: string): Date {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function formatIso(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function todayIso(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
}

export function addDays(iso: string, days: number): string {
  const date = parseDate(iso);
  date.setUTCDate(date.getUTCDate() + days);
  return formatIso(date);
}

export function mondayOf(iso: string): string {
  const date = parseDate(iso);
  const daysFromMonday = (date.getUTCDay() + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysFromMonday);
  return formatIso(date);
}

export function rangeParts(monday: string): RangeParts {
  const start = parseDate(monday);
  const end = parseDate(addDays(monday, 6));
  const startDay = start.getUTCDate();
  const endDay = end.getUTCDate();
  const startMonth = MONTHS[start.getUTCMonth()];
  const endMonth = MONTHS[end.getUTCMonth()];
  const startYear = start.getUTCFullYear();
  const endYear = end.getUTCFullYear();

  if (startYear !== endYear) {
    return {
      main: `${startDay} ${startMonth} ${startYear} – ${endDay} ${endMonth}`,
      year: String(endYear),
    };
  }
  if (startMonth !== endMonth) {
    return {
      main: `${startDay} ${startMonth} – ${endDay} ${endMonth}`,
      year: String(endYear),
    };
  }
  return {
    main: `${startDay}–${endDay} ${endMonth}`,
    year: String(endYear),
  };
}

export function formatRange(monday: string): string {
  const range = rangeParts(monday);
  return `${range.main} ${range.year}`;
}

export function weekOffset(fromMonday: string, toMonday: string): number {
  const from = parseDate(fromMonday).getTime();
  const to = parseDate(toMonday).getTime();
  return Math.round((to - from) / (7 * 86_400_000));
}

export function formatDay(iso: string): string {
  const date = parseDate(iso);
  return `${WEEKDAYS[date.getUTCDay()]} ${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]}`;
}

export function isoWeek(iso: string): number {
  const date = parseDate(iso);
  const thursdayOffset = 4 - (date.getUTCDay() || 7);
  date.setUTCDate(date.getUTCDate() + thursdayOffset);
  const yearStart = Date.UTC(date.getUTCFullYear(), 0, 1);
  return Math.ceil(((date.getTime() - yearStart) / 86_400_000 + 1) / 7);
}
