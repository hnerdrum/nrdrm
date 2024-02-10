import { mutate } from "swr";
import { config } from "../../../config";
import { Ingredient, Recipe, RecipeIngredient } from "../../domain";

export const recipesApiUrl = `/api/v1/recipes`;

export type CreateRecipeData = {
  name: string;
  description: string;
  ingredients: RecipeIngredient[];
};

export type CreateIngredientData = {
  name: string;
};

type PostRequestResult<T> = PostRequestSuccess<T> | PostRequestFailure;

type PostRequestSuccess<T> = { status: "success"; data: T };

type PostRequestFailure = { status: "failure"; message: string };

export const createRecipe = async (
  recipe: CreateRecipeData
): Promise<PostRequestResult<Recipe>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}${recipesApiUrl}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(recipe),
    });

    const message = await response.json();

    if (!response.ok) {
      return {
        status: "failure",
        message: message.message,
      };
    }

    return {
      status: "success",
      data: message as Recipe,
    };
  } catch (e) {
    return {
      status: "failure",
      message: (e as Error).message,
    };
  }
};

type DeleteRequestResult<T> = DeleteRequestSuccess<T> | DeleteRequestFailure;

type DeleteRequestSuccess<T> = { status: "deleted" };

type DeleteRequestFailure = { status: "failure"; message: string };

export const deleteRecipe = async (
  recipeId: string
): Promise<DeleteRequestResult<Recipe>> => {
  try {
    const response = await fetch(
      `${config.baseServerUrl}${recipesApiUrl}/${recipeId}`,
      {
        method: "DELETE",
      }
    );

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

export const createIngredient = async (
  ingredient: CreateIngredientData
): Promise<PostRequestResult<Ingredient>> => {
  try {
    const response = await fetch(`${config.baseServerUrl}/api/v1/ingredients`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(ingredient),
    });

    const message = await response.json();

    if (!response.ok) {
      return {
        status: "failure",
        message: message.message,
      };
    }

    return {
      status: "success",
      data: message as Ingredient,
    };
  } catch (e) {
    return {
      status: "failure",
      message: (e as Error).message,
    };
  }
};
