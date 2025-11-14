# Phase 2: Table Aliases & Column Selection - Complete!

## What We Built

Phase 2 adds:

- ✅ **Table aliases** to avoid column name conflicts
- ✅ **Column selection** to specify which columns to SELECT
- ✅ **WHERE clauses** for JOINed queries
- ✅ **Type-safe column references**

## Usage Examples

### Example 1: Basic JOIN with Aliases

```haskell
import qualified ORM.Join as Join
import ORM.Schema.Recipe
import ORM.Schema.RecipeIngredient

results <- Join.runJoin pool $
  Join.leftJoin @RecipeTable @RecipeIngredientTable
    `Join.as` ("r", "ri")
    `Join.on` (recipeId, riRecipeId)

-- Generates SQL:
-- SELECT * FROM recipe r LEFT JOIN recipe_ingredient ri
-- ON r.id = ri.recipe_id
```

### Example 2: With Column Selection

```haskell
results <- Join.runJoin pool $
  Join.leftJoin @RecipeTable @RecipeIngredientTable
    `Join.as` ("r", "ri")
    `Join.selectColumns` ["r.id", "r.name", "ri.amount", "ri.unit"]
    `Join.on` (recipeId, riRecipeId)

-- Generates SQL:
-- SELECT r.id, r.name, ri.amount, ri.unit
-- FROM recipe r LEFT JOIN recipe_ingredient ri
-- ON r.id = ri.recipe_id
```

### Example 3: With WHERE Clause

```haskell
results <- Join.runJoin pool $
  Join.leftJoin @RecipeTable @RecipeIngredientTable
    `Join.as` ("r", "ri")
    `Join.on` (recipeId, riRecipeId)
    `Join.whereJoin` "r.name LIKE ?" [toField "%pasta%"]

-- Generates SQL:
-- SELECT * FROM recipe r LEFT JOIN recipe_ingredient ri
-- ON r.id = ri.recipe_id WHERE r.name LIKE ?
```

### Example 4: Type-Safe Column Helper

```haskell
import ORM.Join (col)

results <- Join.runJoin pool $
  Join.leftJoin @RecipeTable @RecipeIngredientTable
    `Join.as` ("r", "ri")
    `Join.selectColumns`
      [ col "r" recipeId
      , col "r" recipeName
      , col "ri" riAmount
      ]
    `Join.on` (recipeId, riRecipeId)

-- Generates SQL:
-- SELECT r.id, r.name, ri.amount
-- FROM recipe r LEFT JOIN recipe_ingredient ri
-- ON r.id = ri.recipe_id
```

## Key Features

### 1. Table Aliases Prevent Conflicts

Both `recipe` and `recipe_ingredient` have columns that could conflict. Aliases solve this:

```sql
-- Without aliases (confusing):
SELECT * FROM recipe LEFT JOIN recipe_ingredient ON id = recipe_id
-- Which 'id'? Which table?

-- With aliases (clear):
SELECT * FROM recipe r LEFT JOIN recipe_ingredient ri ON r.id = ri.recipe_id
-- Clear: r.id is from recipe, ri.recipe_id is from recipe_ingredient
```

### 2. Column Selection Controls Output

```haskell
-- SELECT * - gets all columns from both tables
selectColumns Nothing

-- SELECT specific columns
selectColumns (Just ["r.id", "r.name", "ri.amount"])
```

### 3. Type Safety on JOIN Conditions

```haskell
`on` (recipeId, riRecipeId)
-- Both :: Field _ UUID ✓

`on` (recipeName, riRecipeId)
-- Text != UUID ✗ Compile error!
```

## What's Still Missing

Phase 2 handles 2-table JOINs well, but we still need:

- ❌ **Chaining multiple JOINs** (recipe → recipe_ingredient → ingredient)
- ❌ **Automatic grouping** (flat rows → nested Recipe objects)
- ❌ **Relationship tracking** (define once, use everywhere)

These come in Phases 3-5!

## Next: Phase 3 - Chained JOINs

Phase 3 will let you do:

```haskell
results <- Join.runJoin pool $
  Join.startFrom @RecipeTable
    `Join.leftJoin` @RecipeIngredientTable (recipeId, riRecipeId)
    `Join.leftJoin` @IngredientTable (riIngredientId, ingredientId)
    `Join.as` ["r", "ri", "i"]
```

This will require more advanced type-level programming to track the chain of tables!
