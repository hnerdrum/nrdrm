module ORM.Group
  ( groupByKey,
  )
where

import qualified Data.Map.Strict as Map

groupByKey :: (Ord k) => (a -> k) -> [a] -> [[a]]
groupByKey keyFn rows =
  Map.elems $
    Map.fromListWith (++) [(keyFn row, [row]) | row <- rows]
