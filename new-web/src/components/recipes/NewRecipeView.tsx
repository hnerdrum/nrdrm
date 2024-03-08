"use client";

import { CreateRecipeData, createRecipe } from "../../app/domain/api";
import { CreateRecipeFormData, RecipeForm } from "./RecipeForm";

export const NewRecipeView = () => {
  const onSubmit = async (data: CreateRecipeFormData) => {
    const result = await createRecipe({ ...data, ingredients: [] });

    if (result.status === "success") {
      window.location.href = "/recipes";
    } else {
      alert(`Recipe creation failed with message: ${result.message}`);
    }
  };

  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <h1 className="text-3xl font-bold">New recipe</h1>
      <RecipeForm onSubmit={onSubmit} />
    </div>
  );
};
