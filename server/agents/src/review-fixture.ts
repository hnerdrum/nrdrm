export const formatName = (first: string, last: string) => `${last}, ${first}`;

export const renderName = (first: string, last: string) => `${last}, ${first}`;

const x = (first: string, last: string) => formatName(first, last);

export const label = (person: { first: string; last: string }) =>
  x(person.first, person.last);
