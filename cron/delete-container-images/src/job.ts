import { Effect, Console, Schema, Cause } from "effect";
import { config } from "./config";
import {
  ScalewayImage,
  ScalewayImagesResponseSchema,
  ScalewayImageTagsResponseSchema,
  ScalewayImageTag,
} from "./schema";

const getImages = () =>
  Effect.tryPromise(() =>
    fetch(`${config.scaleway.containerRegistry.baseUrl}/images`, {
      headers: {
        "X-Auth-Token": config.scaleway.apiKey,
      },
    })
  ).pipe(
    Effect.flatMap((response) => {
      if (!response.ok) {
        return Effect.fail(
          new Error(`HTTP request failed with status: ${response.status}`)
        );
      }
      return Effect.tryPromise(() => response.json());
    }),
    Effect.flatMap((data) =>
      Schema.decodeUnknown(ScalewayImagesResponseSchema)(data)
    ),
    Effect.map((data) => data.images)
  );

const filterImages = (images: readonly ScalewayImage[]) =>
  Effect.sync(() => {
    const isValidImage = (image: ScalewayImage) => image.status === "ready";

    const validImages = images.filter(isValidImage);
    const invalidImages = images.filter((image) => !isValidImage(image));

    return { validImages, invalidImages };
  }).pipe(
    Effect.flatMap(({ validImages, invalidImages }) =>
      Effect.forEach(invalidImages, (image) =>
        Effect.log(`${image.name} is in invalid state: ${image.status}`)
      ).pipe(Effect.map(() => validImages))
    )
  );

const getImageTags = (image: ScalewayImage) =>
  Effect.tryPromise(() =>
    fetch(
      `${config.scaleway.containerRegistry.baseUrl}/images/${image.id}/tags`,
      {
        headers: {
          "X-Auth-Token": config.scaleway.apiKey,
        },
      }
    )
  ).pipe(
    Effect.flatMap((response) => {
      if (!response.ok) {
        return Effect.fail(
          new Error(`HTTP request failed with status: ${response.status}`)
        );
      }
      return Effect.tryPromise(() => response.json());
    }),
    Effect.flatMap((data) =>
      Schema.decodeUnknown(ScalewayImageTagsResponseSchema)(data)
    ),
    Effect.map((tags) => ({ image, tags: tags.tags }))
  );

const filterTagsForDeletion = (data: {
  image: ScalewayImage;
  tags: readonly ScalewayImageTag[];
}) =>
  Effect.sync(() => partitionTags(data)).pipe(
    Effect.tap(({ readyTags, recentTags, oldTags }) =>
      Effect.log(
        `${data.image.name}: Found ${readyTags.length} ready tags, ${recentTags.length} recent (last 24h), ${oldTags.length} old`
      )
    ),
    Effect.tap(({ tagsToDelete, recentTags, oldTags }) => {
      const message =
        recentTags.length >= config.scaleway.containerRegistry.tagsToKeep
          ? `${data.image.name}: More than ${config.scaleway.containerRegistry.tagsToKeep} recent tags (${recentTags.length}), deleting all ${oldTags.length} old tags`
          : `${data.image.name}: Less than ${
              config.scaleway.containerRegistry.tagsToKeep
            } recent tags (${recentTags.length}), keeping ${
              oldTags.length - tagsToDelete.length
            } old tags, deleting ${tagsToDelete.length} old tags`;
      return Effect.log(message);
    }),
    Effect.map(({ tagsToDelete }) => tagsToDelete)
  );

const partitionTags = (data: {
  image: ScalewayImage;
  tags: readonly ScalewayImageTag[];
}) => {
  const now = new Date();
  const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const readyTags = data.tags.filter((tag) => tag.status === "ready");
  const recentTags = readyTags.filter(
    (tag) => tag.created_at > twentyFourHoursAgo
  );
  const oldTags = readyTags.filter(
    (tag) => tag.created_at <= twentyFourHoursAgo
  );

  const maxOldTagsToKeep = Math.max(
    0,
    config.scaleway.containerRegistry.tagsToKeep - recentTags.length
  );

  const tagsToDelete = oldTags
    .sort(
      (a: ScalewayImageTag, b: ScalewayImageTag) =>
        b.created_at.getTime() - a.created_at.getTime()
    )
    .slice(maxOldTagsToKeep);

  return { tagsToDelete, readyTags, recentTags, oldTags };
};

const program = getImages().pipe(
  Effect.flatMap(filterImages),
  Effect.flatMap((images) => Effect.forEach(images, getImageTags)),
  Effect.flatMap((data) => Effect.forEach(data, filterTagsForDeletion)),
  Effect.catchAllCause((cause) => {
    if (Cause.isFailType(cause)) {
      return Console.error("Job failed with error:", cause);
    }
    return Console.error("Job failed with defect:", cause);
  })
);

Effect.runPromise(program).catch((error) => {
  console.error("Job failed with unhandled error:", error);
  process.exit(1);
});
