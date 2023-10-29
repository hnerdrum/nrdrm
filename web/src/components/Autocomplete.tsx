import { useRef, useState } from "react";

type Props<T extends { name: string }> = {
  items: T[];
  value: string | null;
  onInputChange(value: string): void;
  onItemClick(item: T): void;
};

export const Autocomplete = <T extends { name: string }>({
  items,
  value,
  onInputChange,
  onItemClick,
}: Props<T>) => {
  const ref = useRef(null);
  const [open, setOpen] = useState(false);

  return (
    <div className={`dropdown w-full ${open ? "dropdown-open" : ""}`} ref={ref}>
      <input
        type="text"
        className="w-full px-3 py-2 text-gray-200 border-neutral rounded shadow-md bg-neutral appearance-none focus:outline-none focus:shadow-outline"
        value={value}
        onChange={(e) => onInputChange(e.target.value)}
        placeholder="Add ingredients..."
        tabIndex={0}
      />
      <div className="w-full dropdown-content bg-neutral top-14 max-h-96 overflow-auto flex-col rounded-md">
        <ul
          className="menu menu-compact "
          style={{ width: ref.current?.clientWidth }}
        >
          {items.map((item, index) => {
            return (
              <li
                key={index}
                tabIndex={index + 1}
                onClick={() => {
                  onItemClick(item);
                  onInputChange(item.name);
                  setOpen(false);
                }}
                className="w-full border-b border-b-base-content/10"
              >
                <button>{item.name}</button>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
};
