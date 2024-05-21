"use client";

import { useRouter } from "next/navigation";
import { RecipeForm } from "../components/recipes/RecipeForm";
import { CreateRecipeData, RecipeApi } from "../api/recipe";

export const NewRecipeView = () => {
  const router = useRouter();

  const onSubmit = async (data: CreateRecipeData) => {
    const result = await RecipeApi.create(data);

    if (result.status === "success") {
      router.push(`/`);
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
