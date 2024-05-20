"use client";

import { CreateRecipeData, updateRecipe } from "../app/domain/api";
import { RequestWrap } from "../components/ui/request-wrap";
import { Error } from "../components/ui/error";
import { Error404 } from "../components/ui/404";
import { useRecipe } from "../app/hooks/useRecipe";
import { useAuth } from "../providers/AuthProvider";
import { RecipeForm } from "../components/recipes/RecipeForm";
import { useRouter } from "next/navigation";

export const UpdateRecipeView = ({ recipeId }: { recipeId: string }) => {
  const router = useRouter();
  const { isLoggedIn, isLoading: isAuthLoading } = useAuth();
  const { recipe, isLoading, error } = useRecipe({ recipeId });

  const onSubmit = async (data: CreateRecipeData) => {
    const result = await updateRecipe({ id: recipeId, recipe: data });

    if (result.status === "success") {
      router.push(`/recipes`);
    } else {
      alert(`Recipe update failed with message: ${result.message}`);
    }
  };

  return (
    <RequestWrap
      isLoading={isAuthLoading || isLoading}
      isError={!!error}
      errorComponent={<Error text="Could not show recipe." />}
    >
      {!isLoggedIn && <Error404 />}
      {isLoggedIn && (
        <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
          <h1 className="text-3xl font-bold">Update recipe</h1>
          <RecipeForm recipe={recipe} onSubmit={onSubmit} />
        </div>
      )}
    </RequestWrap>
  );
};
