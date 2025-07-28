import { Effect } from "effect";
import { config } from "./config";
import { ScalewayImage, ScalewayImageTag } from "./schema";
import { deleteImageTag } from "./api/scaleway";

type ImageWithTags = {
  image: ScalewayImage;
  tags: readonly ScalewayImageTag[];
};

type TagPartition = {
  tagsToDelete: ScalewayImageTag[];
  readyTags: ScalewayImageTag[];
  recentTags: ScalewayImageTag[];
  oldTags: ScalewayImageTag[];
};

type FilteredImage = {
  image: ScalewayImage;
  tagsToDelete: ScalewayImageTag[];
};

export const filterValidImages = (images: readonly ScalewayImage[]) =>
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

export const partitionTags = (data: ImageWithTags): TagPartition => {
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

export const filterTagsForDeletion = (data: ImageWithTags) =>
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
    Effect.map(
      ({ tagsToDelete }): FilteredImage => ({
        image: data.image,
        tagsToDelete,
      })
    )
  );

export const deleteImageTagWithLogging = ({
  image,
  tag,
}: {
  image: ScalewayImage;
  tag: ScalewayImageTag;
}) =>
  Effect.log(`${image.name}: Deleting tag ${tag.name}`).pipe(
    Effect.flatMap(() => deleteImageTag(tag.id)),
    Effect.tap(() =>
      Effect.log(`${image.name}: Successfully deleted tag ${tag.name}`)
    ),
    Effect.catchAll((error) =>
      Effect.logError(
        `${image.name}: Failed to delete tag ${tag.name}: ${error.message}`
      )
    )
  );
