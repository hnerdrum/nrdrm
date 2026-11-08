import { request } from './client';

export type Session = {
  email: string;
};

type MeResponse = {
  auth: { email: string } | null;
};

export const identityQueryKey = ['identity'] as const;

export async function currentSession(): Promise<Session | null> {
  const body = await request<MeResponse>('/identity/me');
  if (!body.auth?.email) {
    return null;
  }
  return { email: body.auth.email };
}

export async function login(email: string, password: string): Promise<void> {
  await request('/identity/login', {
    method: 'POST',
    body: { email, password },
  });
}

export async function logout(): Promise<void> {
  await request('/identity/logout', { method: 'POST' });
}
