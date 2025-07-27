import { Schema } from "effect";

const ImageStatusSchema = Schema.Literal(
  "ready",
  "unknown",
  "deleting",
  "error",
  "locked"
);

export const ScalewayImageSchema = Schema.Struct({
  id: Schema.UUID,
  name: Schema.String,
  status: ImageStatusSchema,
});

export const ScalewayImagesResponseSchema = Schema.Struct({
  images: Schema.Array(ScalewayImageSchema),
  total_count: Schema.Number,
});

export type ScalewayImage = typeof ScalewayImageSchema.Type;
export type ScalewayImagesResponse = typeof ScalewayImagesResponseSchema.Type;

export const ScalewayImageTagSchema = Schema.Struct({
  id: Schema.UUID,
  name: Schema.String,
  status: ImageStatusSchema,
  created_at: Schema.DateFromString,
});

export const ScalewayImageTagsResponseSchema = Schema.Struct({
  tags: Schema.Array(ScalewayImageTagSchema),
  total_count: Schema.Number,
});

export type ScalewayImageTag = typeof ScalewayImageTagSchema.Type;
export type ScalewayImageTagsResponse =
  typeof ScalewayImageTagsResponseSchema.Type;
