import { Recipe } from "../../domain";
import { formatIngredient } from "./utils";

type Props = {
  recipes: Recipe[];
};

export const RecipeList = ({ recipes }: Props) => {
  return (
    <>
      {recipes.map((recipe) => (
        <div
          key={recipe.id}
          className="collapse collapse-arrow border border-base-300 bg-base-200"
        >
          <input type="checkbox" />
          <div className="collapse-title text-xl text-gray-200 font-medium">
            {recipe.name}
          </div>
          <div className="collapse-content">
            <p className="mb-4 text-gray-300 whitespace-pre-line">
              {recipe.description}
            </p>
            <div className="flex gap-2">
              {recipe.ingredients.map((ingredient) => (
                <div className="badge badge-primary">
                  {formatIngredient(ingredient)}
                </div>
              ))}
            </div>
          </div>
        </div>
      ))}
    </>
  );
};
