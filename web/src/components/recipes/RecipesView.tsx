import { useState } from "react";
import {
  Accordion,
  AccordionHeader,
  AccordionBody,
} from "@material-tailwind/react";
import { useRecipes } from "../../hooks/useRecipes";

export const RecipesView = () => {
  const { recipes, isLoading, error } = useRecipes();

  if (isLoading || error) {
    return null;
  }

  return (
    <div className="flex flex-col gap-4 w-1/4 mx-auto">
      <h1 className="text-4xl font-bold text-gray-400">Recipes</h1>
      {recipes.map((recipe) => (
        <Accordion
          open
          className="mb-2 rounded-lg border border-blue-gray-100 px-4"
        >
          <AccordionHeader className="border-b-0 text-gray-400 hover:!text-gray-400">
            {recipe.name}
          </AccordionHeader>
          <AccordionBody className="pt-0 text-gray-400 font-normal">
            {recipe.description}
          </AccordionBody>
        </Accordion>
      ))}
    </div>
  );
};
