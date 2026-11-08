import { config } from '../../config';

export type RequestResult<T> = RequestSuccess<T> | RequestFailure;

type RequestSuccess<T> = { status: 'success'; data?: T };
type RequestFailure = { status: 'failure'; message: string };

export const postRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>,
>(
  path: string,
  body: Data,
): Promise<RequestResult<Response>> => makeRequest(path, body, 'POST');

export const putRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>,
>(
  path: string,
  body: Data,
): Promise<RequestResult<Response>> => makeRequest(path, body, 'PUT');

export const makeRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>,
>(
  path: string,
  body: Data,
  method: 'POST' | 'PUT',
): Promise<RequestResult<Response>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      return {
        status: 'failure',
        message: response.statusText,
      };
    }

    const message = await response.json();

    return {
      status: 'success',
      data: message as Response,
    };
  } catch (e) {
    return {
      status: 'failure',
      message: (e as Error).message,
    };
  }
};

export const deleteRequest = async (
  path: string,
): Promise<RequestResult<never>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
    });

    if (!response.ok) {
      return {
        status: 'failure',
        message: response.statusText,
      };
    }

    return {
      status: 'success',
    };
  } catch (e) {
    return {
      status: 'failure',
      message: (e as Error).message,
    };
  }
};
