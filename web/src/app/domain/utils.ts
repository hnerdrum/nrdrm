import { Unit } from ".";

export const unitFromString = (unit: string): Unit => {
  if (Object.values(Unit).includes(unit as Unit)) {
    return unit as Unit;
  }
  throw new Error(`Unexpected unit ${unit}`);
};
