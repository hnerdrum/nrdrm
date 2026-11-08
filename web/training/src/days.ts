import type { LoggedSession } from './api/sessions';

export type DayGroup = {
  date: string;
  sessions: LoggedSession[];
};

export function groupByDate(sessions: LoggedSession[]): DayGroup[] {
  const days: DayGroup[] = [];
  for (const session of sessions) {
    const last = days.at(-1);
    if (last?.date === session.onDate) {
      last.sessions.push(session);
    } else {
      days.push({ date: session.onDate, sessions: [session] });
    }
  }
  return days;
}
