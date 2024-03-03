import { useRecipes } from "../hooks/useRecipes";
import { Error } from "../components/Error";
import { RequestWrap } from "../components/RequestWrap";
import { NoRecipes } from "../components/recipes/NoRecipes";
import { RecipeList } from "../components/recipes/RecipeList";

export const RecipesView = () => {
  const { recipes, isLoading, error } = useRecipes();

  return (
    <RequestWrap
      isLoading={isLoading}
      isError={!!error}
      errorComponent={<Error text="Could not show recipes." />}
    >
      {recipes && (
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
      )}
    </RequestWrap>
  );
};
