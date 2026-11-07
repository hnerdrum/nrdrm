import { Effect, Console, Cause } from 'effect';

import { getImages, getImageTags } from './api/scaleway';
import type { ScalewayImage } from './schema';
import {
  filterValidImages,
  filterTagsForDeletion,
  deleteImageTagWithLogging,
} from './utils';

const program = getImages().pipe(
  Effect.flatMap(filterValidImages),
  Effect.flatMap((images: readonly ScalewayImage[]) =>
    Effect.forEach(images, (image) =>
      getImageTags(image.id).pipe(Effect.map((tags) => ({ image, tags }))),
    ),
  ),
  Effect.flatMap((data) => Effect.forEach(data, filterTagsForDeletion)),
  Effect.flatMap((data) =>
    Effect.forEach(data, (data) =>
      Effect.forEach(data.tagsToDelete, (tag) =>
        deleteImageTagWithLogging({ image: data.image, tag }),
      ),
    ),
  ),
  Effect.catchAllCause((cause) => {
    if (Cause.isFailType(cause)) {
      return Console.error('Job failed with error:', cause);
    }
    return Console.error('Job failed with defect:', cause);
  }),
);

Effect.runPromise(program).catch((error) => {
  console.error('Job failed with unhandled error:', error);
  process.exit(1);
});
