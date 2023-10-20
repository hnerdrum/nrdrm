import { useForm } from "react-hook-form";

type RecipeFormData = {
  name: string;
  description: string;
  ingredients: string[];
};

export const NewRecipeView = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RecipeFormData>({
    defaultValues: { ingredients: [] },
  });

  const onSubmit = (data: RecipeFormData) => console.log(data);

  return (
    <div className="flex flex-col gap-4 w-1/3 mx-auto mt-8">
      <h1 className="text-3xl font-bold text-gray-200">New recipe</h1>
      <div className="w-full  mx-auto">
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
              className="w-full px-3 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
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
              className="w-full px-3 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
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
          </div>
          <div className="mb-6">
            <button type="submit" className="btn btn-primary w-full">
              Add recipe
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
