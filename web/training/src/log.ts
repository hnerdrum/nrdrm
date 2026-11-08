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

export async function createSession(
  onDate: string,
  body: SessionBody,
): Promise<'ok' | 'unauthorized' | 'rejected'> {
  try {
    const response = await fetch('/training/sessions', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ onDate, body }),
    });
    if (response.status === 401) {
      return 'unauthorized';
    }
    if (!response.ok) {
      return 'rejected';
    }
    return 'ok';
  } catch {
    return 'rejected';
  }
}

export async function latestSession(
  sport: SessionBody['sport'],
  through: string,
): Promise<LoggedSession | null | 'unauthorized'> {
  const params = new URLSearchParams({ sport, through });
  const response = await fetch(`/training/sessions/latest?${params}`, {
    credentials: 'include',
  });
  if (response.status === 401) {
    return 'unauthorized';
  }
  if (!response.ok) {
    throw new Error('load failed');
  }
  return response.json() as Promise<LoggedSession | null>;
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
