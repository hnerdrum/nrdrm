import type { SessionBody } from './domain';

export type LoggedSession = {
  id: string;
  onDate: string;
  body: SessionBody;
};

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

export async function listSessions(
  from: string,
  to: string,
): Promise<LoggedSession[] | 'unauthorized'> {
  const response = await fetch(
    `/training/sessions?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
    { credentials: 'include' },
  );
  if (response.status === 401) {
    return 'unauthorized';
  }
  if (!response.ok) {
    throw new Error('load failed');
  }
  return response.json() as Promise<LoggedSession[]>;
}
