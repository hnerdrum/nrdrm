import { useForm } from "react-hook-form";
import { CreateRecipeData, createIngredient, createRecipe } from "./api";
import { useIngredients } from "../../hooks/useIngredients";
import { useState } from "react";
import { Autocomplete } from "../Autocomplete";
import { useSearchFilter } from "../../hooks/useSearchFilter";
import { Ingredient, RecipeIngredient, Unit } from "../../domain";
import { unitFromString } from "../../domain/utils";
import { formatIngredient } from "./utils";

type CreateRecipeFormData = {
  name: string;
  description: string;
};

export const NewRecipeView = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<CreateRecipeFormData>();

  const [recipeIngredients, setRecipeIngredients] = useState<
    RecipeIngredient[]
  >([]);
  const [selectedIngredient, setSelectedIngredient] =
    useState<Ingredient | null>(null);
  const [selectedAmount, setSelectedAmount] = useState<number | "">("");
  const [selectedUnit, setSelectedUnit] = useState<Unit | "">("");
  const [showIngredientError, setShowIngredientError] = useState(null);

  const { ingredients } = useIngredients();

  const {
    searchInput,
    filteredItems: filteredIngredients,
    setSearchInput,
  } = useSearchFilter(ingredients, ["name"]);

  const onSubmit = async (data: CreateRecipeFormData) => {
    const result = await createRecipe({
      ...data,
      ingredients: recipeIngredients,
    });
    if (result.status === "success") {
      window.location.href = "/recipes";
    } else {
      alert(`Recipe creation failed with message: ${result.message}`);
    }
  };

  const onCreateNewIngredient = async (data: { name: string }) => {
    const result = await createIngredient(data);
    if (result.status === "success") {
      setSelectedIngredient(result.data);
    } else {
      alert(`Ingredient creation failed with message: ${result.message}`);
    }
  };

  const handleAmountInputChange = (value: string) => {
    if (value === "") {
      return;
    }
    setSelectedAmount(parseFloat(value));
  };

  const handleAddIngredient = () => {
    setShowIngredientError(false);

    if (!selectedIngredient || !selectedAmount || !selectedUnit) {
      setShowIngredientError(true);
      return;
    }

    setRecipeIngredients((recipeIngredients) => [
      ...recipeIngredients.filter((ri) => ri.id !== selectedIngredient.id),
      {
        id: selectedIngredient.id,
        name: selectedIngredient.name,
        amount: selectedAmount,
        unit: selectedUnit,
      },
    ]);

    resetIngredientForm();
  };

  const resetIngredientForm = () => {
    setSelectedIngredient((_) => null);
    setSearchInput((_) => "");
    setSelectedAmount((_) => "");
    setSelectedUnit((_) => "");
  };

  const handleRemoveIngredient = (ingredient: RecipeIngredient) => {
    setRecipeIngredients(
      recipeIngredients.filter((ri) => ri.id !== ingredient.id)
    );
  };

  return (
    <div className="flex flex-col gap-4 w-full lg:w-1/2 lg:px-0 px-8 mx-auto mt-8">
      <h1 className="text-3xl font-bold text-gray-200">New recipe</h1>
      <div className="w-full mx-auto">
        <form
          className="bg-gray-900 shadow-lg rounded px-8 pt-6 pb-8 mb-4"
          onSubmit={handleSubmit(onSubmit)}
        >
          <div className="mb-4">
            <label
              className="block text-gray-200 text-sm font-bold mb-2"
              htmlFor="recipeName"
            >
              Recipe name
            </label>
            <input
              className="w-full px-2 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
              id="recipeName"
              type="text"
              {...register("name", { required: "Recipe name is required" })}
            />
            {errors.name && (
              <p className="text-red-400 text-sm mt-2">{errors.name.message}</p>
            )}
          </div>
          <div className="mb-4">
            <label
              className="block text-gray-200 text-sm font-bold mb-2"
              htmlFor="recipeDescription"
            >
              Recipe description
            </label>
            <textarea
              className="w-full px-2 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
              id="recipeDescription"
              rows={6}
              {...register("description", {
                required: "Recipe description is required",
              })}
            />
            {errors.description && (
              <p className="text-red-400 text-sm mt-2">
                {errors.description.message}
              </p>
            )}
          </div>
          <div className="mb-4">
            <label
              className="block text-gray-200 text-sm font-bold mb-2"
              htmlFor="ingredients"
            >
              Ingredients
            </label>
            <div className="flex">
              <div className="w-1/2">
                <Autocomplete
                  value={searchInput}
                  placeholder="Search for ingredients..."
                  onItemClick={setSelectedIngredient}
                  onInputChange={setSearchInput}
                  onItemCreate={onCreateNewIngredient}
                  items={filteredIngredients}
                />
              </div>
              <input
                className="w-1/4 mx-2 px-3 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
                placeholder="Specify amount"
                type="number"
                value={selectedAmount}
                onChange={(e) => handleAmountInputChange(e.target.value)}
              />
              <select
                className="select w-1/4 max-w-xs px-2 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral"
                value={selectedUnit}
                onChange={(e) =>
                  setSelectedUnit(unitFromString(e.target.value))
                }
              >
                <option disabled value=""></option>
                <option value="G">g</option>
                <option value="Ml">ml</option>
                <option value="Tbsp">tbsp</option>
                <option value="Tsp">tsp</option>
                <option value="Qty">qty</option>
              </select>
              <button
                type="button"
                className="btn btn-primary ml-2"
                onClick={(e) => {
                  handleAddIngredient();
                }}
              >
                Add
              </button>
            </div>
            {showIngredientError && (
              <p className="text-red-400 text-sm mt-2">
                You must specify ingredient name, amount and unit to add it to
                the recipe
              </p>
            )}
            <div className="flex flex-wrap gap-2 p-4">
              {recipeIngredients.map((ingredient) => (
                <div
                  key={ingredient.id}
                  className="badge badge-primary cursor-pointer"
                  onClick={() => handleRemoveIngredient(ingredient)}
                >
                  {formatIngredient(ingredient)}
                </div>
              ))}
            </div>
          </div>
          <button type="submit" className="btn btn-primary">
            Add recipe
          </button>
        </form>
      </div>
    </div>
  );
};
