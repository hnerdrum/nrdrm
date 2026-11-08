import { Effect, Schema } from 'effect';

import { config } from '../config';
import {
  ScalewayImagesResponseSchema,
  ScalewayImageTagsResponseSchema,
} from '../schema';

const makeRequest = (url: string, options?: RequestInit) =>
  Effect.tryPromise(() =>
    fetch(url, {
      headers: {
        'X-Auth-Token': config.scaleway.apiKey,
        ...options?.headers,
      },
      ...options,
    }),
  ).pipe(
    Effect.flatMap((response) => {
      if (!response.ok) {
        return Effect.fail(
          new Error(`HTTP request failed with status: ${response.status}`),
        );
      }
      return Effect.succeed(response);
    }),
  );

export const getImages = () =>
  makeRequest(`${config.scaleway.containerRegistry.baseUrl}/images`).pipe(
    Effect.flatMap((response) => Effect.tryPromise(() => response.json())),
    Effect.flatMap((data) =>
      Schema.decodeUnknown(ScalewayImagesResponseSchema)(data),
    ),
    Effect.map((data) => data.images),
  );

export const getImageTags = (imageId: string) =>
  makeRequest(
    `${config.scaleway.containerRegistry.baseUrl}/images/${imageId}/tags`,
  ).pipe(
    Effect.flatMap((response) => Effect.tryPromise(() => response.json())),
    Effect.flatMap((data) =>
      Schema.decodeUnknown(ScalewayImageTagsResponseSchema)(data),
    ),
    Effect.map((data) => data.tags),
  );

export const deleteImageTag = (tagId: string) =>
  makeRequest(`${config.scaleway.containerRegistry.baseUrl}/tags/${tagId}`, {
    method: 'DELETE',
  });
