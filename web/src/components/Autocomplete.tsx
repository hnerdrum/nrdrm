import { useRef, useState } from "react";

type Props<T extends { name: string }> = {
  items: T[];
  value: string | null;
  onInputChange(value: string): void;
  onItemClick(item: T): void;
  onItemCreate(item: { name: string }): void;
};

export const Autocomplete = <T extends { name: string }>({
  items,
  value,
  onInputChange,
  onItemClick,
  onItemCreate,
}: Props<T>) => {
  const ref = useRef(null);

  const handleItemClick = (
    e: React.MouseEvent<HTMLLIElement, MouseEvent>,
    item: T
  ) => {
    e.preventDefault();
    onItemClick(item);
    onInputChange(item.name);
    (document.activeElement as HTMLElement).blur();
  };

  const handleNewItem = (
    e: React.MouseEvent<HTMLLIElement, MouseEvent>,
    item: T
  ) => {
    e.preventDefault();
    onItemCreate(item);
    onInputChange(item.name);
    (document.activeElement as HTMLElement).blur();
  };

  return (
    <div className={`dropdown w-full`} ref={ref}>
      <input
        type="text"
        className="w-full px-3 py-3 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
        value={value}
        onChange={(e) => {
          onInputChange(e.target.value);
        }}
        tabIndex={0}
      />
      <div className="w-full dropdown-content bg-neutral top-14 max-h-96 overflow-auto flex-col rounded-md">
        <ul
          className="menu menu-compact "
          style={{ width: ref.current?.clientWidth }}
        >
          <DropdownItemList
            value={value}
            items={items}
            handleItemClick={handleItemClick}
            handleNewItem={handleNewItem}
          />
        </ul>
      </div>
    </div>
  );
};

const DropdownItemList = <T extends { name: string }>({
  value,
  items,
  handleItemClick,
  handleNewItem,
}: {
  value: string | null;
  items: T[];
  handleItemClick(
    e: React.MouseEvent<HTMLLIElement, MouseEvent>,
    item: T
  ): void;
  handleNewItem(
    e: React.MouseEvent<HTMLLIElement, MouseEvent>,
    item: { name: string }
  ): void;
}) => {
  const isMissingItems = !items || !items.length;
  if (isMissingItems && !!value) {
    return (
      <li
        className="w-full border-b border-b-base-content/10"
        onClick={(e) => handleNewItem(e, { name: value })}
      >
        <button>Create ingredient "{value}"</button>
      </li>
    );
  }

  return (
    <>
      {items.map((item, index) => {
        return (
          <li
            key={index}
            tabIndex={index + 1}
            onClick={(e) => handleItemClick(e, item)}
            className="w-full border-b border-b-base-content/10"
          >
            <button>{item.name}</button>
          </li>
        );
      })}
    </>
  );
};
