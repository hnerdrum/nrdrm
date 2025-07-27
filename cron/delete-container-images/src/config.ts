export const config = {
  scaleway: {
    apiKey: process.env.SCALEWAY_API_KEY as string,
    containerRegistry: {
      baseUrl: process.env.SCALEWAY_CONTAINER_REGISTRY_BASE_URL as string,
      tagsToKeep: 10,
    },
  },
};
