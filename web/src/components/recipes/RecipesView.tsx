import { useRecipes } from "../../hooks/useRecipes";
import { useAuth } from "../../providers/AuthProvider";
import { Error } from "../Error";
import { Loading } from "../Loading";
import { NoRecipes } from "./NoRecipes";
import { RecipeList } from "./RecipeList";

export const RecipesView = () => {
  const { recipes, isLoading, error } = useRecipes();

  if (isLoading) {
    return <Loading />;
  }

  if (error) {
    <Error text="Could not show recipes." />;
  }

  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <div className="flex items-center justify-between mt-8">
        <h1 className="text-3xl font-bold text-gray-200">Recipes</h1>
        <a className="btn btn-primary" href="/recipes/new">
          Add recipe
        </a>
      </div>
      {!recipes.length && <NoRecipes />}
      {!!recipes.length && <RecipeList recipes={recipes} />}
    </div>
  );
};
