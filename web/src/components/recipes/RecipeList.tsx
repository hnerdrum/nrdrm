import { useState } from "react";
import { Recipe } from "../../domain";
import { Icon } from "../icon/Icon";
import { formatIngredient } from "./utils";
import { deleteRecipe, recipesApiUrl } from "./api";
import { useSWRConfig } from "swr";
import { useAuth } from "../../providers/AuthProvider";

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
  const { isLoggedIn } = useAuth();

  const toggleOpen = () => {
    setOpen((open) => !open);
  };

  return (
    <div className="cursor-pointer rounded-lg border border-base-300 bg-base-200">
      <div className="flex justify-between items-center px-4 text-xl text-gray-200 font-medium p-4">
        <div className="w-full" onClick={toggleOpen}>
          <span>{recipe.name}</span>
        </div>
        {isLoggedIn && <RecipeMenu recipe={recipe} />}
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

const RecipeMenu = ({ recipe }: { recipe: Recipe }) => {
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
          <DeleteRecipeDialog recipe={recipe} />
        </li>
      </ul>
    </div>
  );
};

const DeleteRecipeDialog = ({ recipe }: { recipe: Recipe }) => {
  const [open, setOpen] = useState(false);
  const { mutate } = useSWRConfig();

  const onDeleteRecipe = async () => {
    const result = await deleteRecipe(recipe.id);
    if (result.status !== "deleted") {
      alert(`Recipe deletion failed with message: ${result.message}`);
      return;
    }
    mutate(recipesApiUrl);
  };

  return (
    <>
      <button onClick={() => setOpen(true)}>Delete recipe</button>
      <Modal open={open} onClose={() => setOpen(false)}>
        <div className="w-96">
          <div className="p-2">
            <h3 className="text-lg text-gray-200">Delete {recipe.name}</h3>
          </div>
          <div className="p-2">
            <p className="text-sm text-gray-200">
              Are you sure you want to delete this recipe?
            </p>
          </div>
          <div className="flex justify-between gap-2 m-2">
            <button className="btn" onClick={() => setOpen(false)}>
              Cancel
            </button>
            <button className="btn" onClick={onDeleteRecipe}>
              Delete
            </button>
          </div>
        </div>
      </Modal>
    </>
  );
};

const Modal = ({
  open,
  onClose,
  children,
}: {
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
}) => {
  return (
    <div
      onClick={onClose}
      className={`
        fixed inset-0 flex justify-center items-center transition-colors
        ${open ? "visible bg-black/20" : "invisible"}
      `}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className={`
          bg-base-200 rounded-l p-4 pb-2 transition-all
          ${open ? "scale-100 opacity-100" : "scale-125 opacity-0"}
        `}
      >
        {children}
      </div>
    </div>
  );
};
