import { DotsHorizontal } from "./icons/DotsHorizontal";

export const IconNameValues = {
  dotsHorizontal: "dotsHorizontal",
} as const;

export type IconName = (typeof IconNameValues)[keyof typeof IconNameValues];

type Props = {
  name: IconName;
  color?: string;
  size?: string;
  strokeWidth?: number;
};

export const Icon = (props: Props) => {
  switch (props.name) {
    case "dotsHorizontal":
      return <DotsHorizontal {...props} />;
  }
};
