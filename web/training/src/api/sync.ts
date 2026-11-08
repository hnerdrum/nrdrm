import { plural } from '../format';

import { ApiError, request } from './client';

export type SyncOutcome = {
  sessions: { id: string; onDate: string }[];
  skipped: string[];
};

export function syncGarmin(): Promise<SyncOutcome> {
  return request<SyncOutcome>('/training/sync', { method: 'POST' });
}

export function describeSync(result: SyncOutcome): string {
  if (result.sessions.length === 0) {
    return 'Already up to date.';
  }
  const added = `${plural(result.sessions.length, 'session', 'sessions')} added.`;
  if (result.skipped.length === 0) {
    return added;
  }
  return `${added} Skipped ${result.skipped.join(', ')}.`;
}

export function describeSyncFailure(error: unknown): string {
  if (error instanceof ApiError && error.status === 502) {
    return "Garmin didn't respond.";
  }
  return "Couldn't sync. Try again.";
}
