import { config } from "../../../config";
import { Ingredient, Recipe, RecipeIngredient } from "../../domain";

export const recipesApiUrl = `/api/v1/recipes`;

export type PostRequestResult<T> = PostRequestSuccess<T> | PostRequestFailure;

type PostRequestSuccess<T> = { status: "success"; data: T };

type PostRequestFailure = { status: "failure"; message: string };

export const postRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>
>(
  path: string,
  body: Data
): Promise<PostRequestResult<Response>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      return {
        status: "failure",
        message: response.statusText,
      };
    }

    const message = await response.json();

    return {
      status: "success",
      data: message as Response,
    };
  } catch (e) {
    return {
      status: "failure",
      message: (e as Error).message,
    };
  }
};

export type CreateRecipeData = {
  name: string;
  description: string;
  ingredients: RecipeIngredient[];
};

export type CreateIngredientData = {
  name: string;
};

export const createRecipe = async (
  recipe: CreateRecipeData
): Promise<PostRequestResult<Recipe>> =>
  postRequest<CreateRecipeData, Recipe>(recipesApiUrl, recipe);

export type DeleteRequestResult = DeleteRequestSuccess | DeleteRequestFailure;

type DeleteRequestSuccess = { status: "deleted" };

type DeleteRequestFailure = { status: "failure"; message: string };

export const deleteRequest = async (
  path: string
): Promise<DeleteRequestResult> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: "DELETE",
    });

    if (!response.ok) {
      return {
        status: "failure",
        message: response.statusText,
      };
    }

    return {
      status: "deleted",
    };
  } catch (e) {
    return {
      status: "failure",
      message: (e as Error).message,
    };
  }
};

export const deleteRecipe = async (
  recipeId: string
): Promise<DeleteRequestResult> =>
  deleteRequest(`${recipesApiUrl}/${recipeId}`);

export const createIngredient = async (
  ingredient: CreateIngredientData
): Promise<PostRequestResult<Ingredient>> =>
  postRequest(`/api/v1/ingredients`, ingredient);
