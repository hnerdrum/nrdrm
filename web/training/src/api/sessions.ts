import type { SessionBody } from '../domain';

import { request } from './client';

export type LoggedSession = {
  id: string;
  onDate: string;
  body: SessionBody;
};

export const sessionsQueryKey = ['sessions'] as const;

export function listSessions(
  from: string,
  to: string,
): Promise<LoggedSession[]> {
  const params = new URLSearchParams({ from, to });
  return request(`/training/sessions?${params}`);
}

export function latestSession(
  sport: SessionBody['sport'],
  through: string,
): Promise<LoggedSession | null> {
  const params = new URLSearchParams({ sport, through });
  return request(`/training/sessions/latest?${params}`);
}

export async function createSession(
  onDate: string,
  body: SessionBody,
): Promise<void> {
  await request('/training/sessions', {
    method: 'POST',
    body: { onDate, body },
  });
}

export async function updateSession(
  id: string,
  onDate: string,
  body: SessionBody,
): Promise<void> {
  await request(`/training/sessions/${id}`, {
    method: 'PUT',
    body: { onDate, body },
  });
}

export async function deleteSession(id: string): Promise<void> {
  await request(`/training/sessions/${id}`, { method: 'DELETE' });
}
