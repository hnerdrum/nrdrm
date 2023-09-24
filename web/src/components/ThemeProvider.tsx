import pkg from "@material-tailwind/react";
const { ThemeProvider: MTThemeProvider } = pkg;

export function ThemeProvider({ children }) {
  return <MTThemeProvider>{children}</MTThemeProvider>;
}
