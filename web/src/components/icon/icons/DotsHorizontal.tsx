export const DotsHorizontal = ({
  color = "currentColor",
  size = "2em",
  strokeWidth = 3,
  className = "",
  ariaHidden = true,
}) => {
  return (
    <svg
      aria-hidden={ariaHidden}
      className={className}
      width={size}
      height={size}
      fill="none"
      viewBox="0 0 24 24"
      stroke={color}
      strokeWidth={strokeWidth}
    >
      <path
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth={strokeWidth}
        d="M6 12h0m6 0h0m6 0h0"
      />
    </svg>
  );
};
