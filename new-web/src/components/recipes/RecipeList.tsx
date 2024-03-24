import { useState } from "react";
import { formatIngredient } from "./utils";
import { useSWRConfig } from "swr";
import { Recipe } from "../../app/domain";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "../ui/accordion";
import { Badge } from "../ui/badge";

type Props = {
  recipes: Recipe[];
};

export const RecipeList = ({ recipes }: Props) => {
  return (
    <Accordion type="single" collapsible className="w-full">
      {recipes.map((recipe) => (
        <RecipeItem key={recipe.id} recipe={recipe} />
      ))}
    </Accordion>
  );
};

const RecipeItem = ({ recipe }: { recipe: Recipe }) => {
  return (
    <AccordionItem
      value={recipe.id}
      className="shadow border border-hsla(204, 100%, 10%, 0.18) rounded-md px-8 mb-4"
    >
      <AccordionTrigger
        withChevron={false}
        className="hover:no-underline text-lg"
      >
        {recipe.name}
      </AccordionTrigger>
      <AccordionContent>
        <div className="flex flex-col">
          {recipe.description}
          {recipe.ingredients.length && (
            <div className="flex flex-wrap gap-2 pt-4">
              {recipe.ingredients.map((ingredient) => (
                <Badge key={ingredient.id}>
                  {formatIngredient(ingredient)}
                </Badge>
              ))}
            </div>
          )}
        </div>
      </AccordionContent>
    </AccordionItem>
  );
};
