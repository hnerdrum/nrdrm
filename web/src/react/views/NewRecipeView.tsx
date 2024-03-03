import { RecipeIngredient } from "../../domain";
import {
  CreateRecipeFormData,
  RecipeForm,
} from "../components/recipes/RecipeForm";
import { createRecipe } from "../../domain/api";

export const NewRecipeView = () => {
  const onSubmit = async (
    data: CreateRecipeFormData & { ingredients: RecipeIngredient[] }
  ) => {
    const result = await createRecipe(data);

    if (result.status === "success") {
      window.location.href = "/recipes";
    } else {
      alert(`Recipe creation failed with message: ${result.message}`);
    }
  };

  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <h1 className="text-3xl font-bold text-gray-200">New recipe</h1>
      <RecipeForm onSubmit={onSubmit} />
    </div>
  );
};
