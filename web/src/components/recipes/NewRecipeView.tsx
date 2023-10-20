export const NewRecipeView = () => {
  return (
    <div className="flex flex-col gap-4 w-1/3 mx-auto mt-8">
      <h1 className="text-3xl font-bold text-gray-200">New recipe</h1>
      <div className="w-full  mx-auto">
        <form className="bg-gray-900 shadow-lg rounded px-8 pt-6 pb-8 mb-4">
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
            />
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
            ></textarea>
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
            <button className="btn btn-primary w-full" type="button">
              Add recipe
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
