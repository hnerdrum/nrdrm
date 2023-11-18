import { RecipeIngredient } from "../../domain";

export type CreateRecipeData = {
  name: string;
  description: string;
  ingredients: RecipeIngredient[];
};

type CreateRecipeResult = CreateRecipeSuccess | CreateRecipeFailure;

type CreateRecipeSuccess = { status: "success" };

type CreateRecipeFailure = { status: "failure"; message: string };

export const createRecipe = async (
  recipe: CreateRecipeData
): Promise<CreateRecipeResult> => {
  try {
    const response = await fetch("http://localhost:8000/api/v1/recipes", {
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
    };
  } catch (e) {
    return {
      status: "failure",
      message: (e as Error).message,
    };
  }
};
