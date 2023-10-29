import { Unit } from ".";

export const unitFromString = (unit: string) => {
  if (Object.values(Unit).includes(unit as Unit)) {
    return unit as Unit;
  }
  throw new Error(`Unexpected unit ${unit}`);
};
