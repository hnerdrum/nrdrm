import { postRequest } from ".";
import { Ingredient } from "../domain";

export type CreateIngredientData = {
  name: string;
};

const baseUrl = `/recipes/ingredients`;

export const IngredientApi = {
  baseUrl,

  create: async (data: CreateIngredientData) =>
    postRequest<CreateIngredientData, Ingredient>(baseUrl, data),
};
