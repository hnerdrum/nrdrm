export type Session = {
  email: string;
};

type MeResponse = {
  auth: { email: string } | null;
};

export type LoginResult = 'ok' | 'rejected' | 'unavailable';

export async function currentSession(): Promise<Session | null> {
  try {
    const response = await fetch('/identity/me', { credentials: 'include' });
    if (!response.ok) {
      return null;
    }
    const body = (await response.json()) as MeResponse;
    if (!body.auth?.email) {
      return null;
    }
    return { email: body.auth.email };
  } catch {
    return null;
  }
}

export async function login(
  email: string,
  password: string,
): Promise<LoginResult> {
  try {
    const response = await fetch('/identity/login', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    if (response.ok) {
      return 'ok';
    }
    if (response.status === 401) {
      return 'rejected';
    }
    return 'unavailable';
  } catch {
    return 'unavailable';
  }
}

export async function logout(): Promise<boolean> {
  try {
    const response = await fetch('/identity/logout', {
      method: 'POST',
      credentials: 'include',
    });
    return response.ok;
  } catch {
    return false;
  }
}
