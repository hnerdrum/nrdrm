import { useState } from "react";
import { Recipe } from "../../domain";
import { Icon } from "../icon/Icon";
import { formatIngredient } from "./utils";

type Props = {
  recipes: Recipe[];
};

export const RecipeList = ({ recipes }: Props) => {
  return (
    <>
      {recipes.map((recipe) => (
        <RecipeItem key={recipe.id} recipe={recipe} />
      ))}
    </>
  );
};

const RecipeItem = ({ recipe }: { recipe: Recipe }) => {
  const [open, setOpen] = useState(false);

  const toggleOpen = () => {
    setOpen((open) => !open);
  };

  return (
    <div className="cursor-pointer rounded-lg border border-base-300 bg-base-200">
      <div className="flex justify-between items-center px-4 text-xl text-gray-200 font-medium">
        <div className="w-full" onClick={toggleOpen}>
          <span>{recipe.name}</span>
        </div>
        <RecipeMenu />
      </div>
      {open && (
        <div className="p-4 pt-0">
          <p className="mb-4 text-gray-300 whitespace-pre-line">
            {recipe.description}
          </p>
          <div className="flex flex-wrap gap-2">
            {recipe.ingredients.map((ingredient) => (
              <div key={ingredient.id} className="badge badge-primary">
                {formatIngredient(ingredient)}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

const RecipeMenu = () => {
  return (
    <div className="dropdown">
      <div tabIndex={0} role="button" className="btn m-1">
        <Icon name="dotsHorizontal" />
      </div>
      <ul
        tabIndex={0}
        className="dropdown-content bg-base-200 rounded-lg menu w-40 p-2"
      >
        <li>
          <button>Delete recipe</button>
        </li>
      </ul>
    </div>
  );
};
