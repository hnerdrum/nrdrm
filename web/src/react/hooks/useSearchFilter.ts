import { matchSorter } from "match-sorter";
import { useMemo, useState } from "react";

export function useSearchFilter<T>(items?: T[], searchKeys?: string[]) {
  const [searchInput, setSearchInput] = useState("");

  const filteredItems = useMemo(() => {
    if (!items) {
      return [];
    }

    if (!searchInput.trim()) {
      return items;
    }

    const terms = searchInput.split(" ");

    return terms.reduceRight(
      (results, term) =>
        matchSorter(results, term, {
          keys: searchKeys,
          threshold: matchSorter.rankings.CONTAINS,
        }),
      items
    );
  }, [items, searchInput, searchKeys]);

  return {
    filteredItems,
    searchInput,
    setSearchInput,
  };
}
