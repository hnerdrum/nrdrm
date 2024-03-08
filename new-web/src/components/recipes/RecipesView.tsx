"use client";

import { useRecipes } from "../../app/hooks/useRecipes";
import { Button } from "../ui/button";
import { Error } from "../ui/error";
import { RequestWrap } from "../ui/request-wrap";
import { NoRecipes } from "./NoRecipes";

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
            <h1 className="text-3xl font-bold">Recipes</h1>
            <Button>
              <a href="/recipes/new">Add recipe</a>
            </Button>
          </div>
          {!recipes.length && <NoRecipes />}
        </div>
      )}
    </RequestWrap>
  );
};
