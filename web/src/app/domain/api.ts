import { Ingredient, Recipe, RecipeIngredient } from ".";
import { config } from "../../../config";

export const recipesApiUrl = `/api/v1`;

export const ingredientsApiUrl = `/api/v1/ingredients`;

export type RequestResult<T> = RequestSuccess<T> | RequestFailure;

type RequestSuccess<T> = { status: "success"; data?: T };
type RequestFailure = { status: "failure"; message: string };

export const postRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>
>(
  path: string,
  body: Data
): Promise<RequestResult<Response>> => makeRequest(path, body, "POST");

export const putRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>
>(
  path: string,
  body: Data
): Promise<RequestResult<Response>> => makeRequest(path, body, "PUT");

export const makeRequest = async <
  Data extends Record<never, never>,
  Response extends Record<string, any>
>(
  path: string,
  body: Data,
  method: "POST" | "PUT"
): Promise<RequestResult<Response>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: method,
      headers: {
        "Content-Type": "application/json",
      },
      credentials: "include",
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

export const deleteRequest = async (
  path: string
): Promise<RequestResult<never>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${path}`, {
      method: "DELETE",
      credentials: "include",
    });

    if (!response.ok) {
      return {
        status: "failure",
        message: response.statusText,
      };
    }

    return {
      status: "success",
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
): Promise<RequestResult<Recipe>> =>
  postRequest<CreateRecipeData, Recipe>(recipesApiUrl, recipe);

export const updateRecipe = async ({
  id,
  recipe,
}: {
  id: string;
  recipe: CreateRecipeData;
}): Promise<RequestResult<Recipe>> =>
  putRequest(`${recipesApiUrl}/${id}`, recipe);

export const deleteRecipe = async (recipeId: string) =>
  deleteRequest(`${recipesApiUrl}/${recipeId}`);

export const createIngredient = async (
  ingredient: CreateIngredientData
): Promise<RequestResult<Ingredient>> =>
  postRequest(ingredientsApiUrl, ingredient);
