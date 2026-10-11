export type SensitiveData = "email" | "phone" | "national-id";

const email = /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i;
const nationalId = /\b\d{11}\b|\b\d{6} \d{5}\b/;
const internationalPhone = /(?:\+|\b00)[\s.-]?\d(?:[\s.-]?\d){7,14}\b/;
const localPhone = /\b\d{8}\b/;
const spacedPhone =
  /\b\d{3}[\s.-]\d{2}[\s.-]\d{3}\b|\b\d{2}[\s.-]\d{2}[\s.-]\d{2}[\s.-]\d{2}\b/;

export const sensitiveData = (input: string): SensitiveData | undefined => {
  if (email.test(input)) {
    return "email";
  }
  if (nationalId.test(input)) {
    return "national-id";
  }
  if (
    internationalPhone.test(input) ||
    localPhone.test(input) ||
    spacedPhone.test(input)
  ) {
    return "phone";
  }
  return undefined;
};
