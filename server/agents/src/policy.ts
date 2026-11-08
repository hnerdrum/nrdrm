export type SensitiveData = 'email' | 'phone' | 'national-id';

const boundary = String.raw`[\w./:@+-]`;
const email = /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i;
const nationalId = new RegExp(
  String.raw`(?<!${boundary})\d{11}(?!${boundary})|\b\d{6} \d{5}\b`,
);
const internationalPhone = /(?:\+|\b00)[\s.-]?\d(?:[\s.-]?\d){7,14}\b/;
const localPhone = new RegExp(
  String.raw`(?<!${boundary})[2-9]\d{7}(?!${boundary})`,
);
const spacedPhone =
  /\b\d{3}[\s.-]\d{2}[\s.-]\d{3}\b|\b\d{2}[\s.-]\d{2}[\s.-]\d{2}[\s.-]\d{2}\b/;

export const sensitiveData = (input: string): SensitiveData | undefined => {
  if (email.test(input)) {
    return 'email';
  }
  if (nationalId.test(input)) {
    return 'national-id';
  }
  if (
    internationalPhone.test(input) ||
    localPhone.test(input) ||
    spacedPhone.test(input)
  ) {
    return 'phone';
  }
  return undefined;
};
