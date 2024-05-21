import { deleteRequest, postRequest, putRequest } from ".";
import { Recipe, RecipeIngredient } from "../domain";

export type CreateRecipeData = {
  name: string;
  description: string;
  ingredients: RecipeIngredient[];
};

const baseUrl = `/recipes`;

export const RecipeApi = {
  baseUrl,

  create: async (data: CreateRecipeData) =>
    postRequest<CreateRecipeData, Recipe>(baseUrl, data),

  update: async ({ id, data }: { id: string; data: CreateRecipeData }) =>
    putRequest(`${baseUrl}/${id}`, data),

  delete: async (id: string) => deleteRequest(`${baseUrl}/${id}`),
};
