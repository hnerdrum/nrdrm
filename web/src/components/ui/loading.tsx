type Props = {
  size?: "xs" | "s" | "m" | "l";
};

const sizeClasses = {
  xs: "loading-xs",
  s: "loading-sm",
  m: "loading-md",
  l: "loading-lg",
};

export const Loading = ({ size = "l" }: Props) => {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <span className={`loading loading-spinner ${sizeClasses[size]}`}></span>
    </div>
  );
};
