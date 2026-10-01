import React from "react";
import { Composition, Still } from "remotion";
import "./theme";
import { Cut15, Hero } from "./Film";
import { CUT_LEN, FPS, H, HERO_LEN, W } from "./timeline";

export const Root: React.FC = () => (
  <>
    {/* Hero, three hook variants (the first 4.5 s differ), and the 15 s cut-down. */}
    <Composition id="Hero-H1" component={Hero} durationInFrames={HERO_LEN} fps={FPS} width={W} height={H} defaultProps={{ hook: 1 as const }} />
    <Composition id="Hero-H2" component={Hero} durationInFrames={HERO_LEN} fps={FPS} width={W} height={H} defaultProps={{ hook: 2 as const }} />
    <Composition id="Hero-H3" component={Hero} durationInFrames={HERO_LEN} fps={FPS} width={W} height={H} defaultProps={{ hook: 3 as const }} />
    <Composition id="Cut15" component={Cut15} durationInFrames={CUT_LEN} fps={FPS} width={W} height={H} />
    {/* TikTok / Reels cover images: frame 0 of each hook. */}
    <Still id="Cover-H1" component={Hero} width={W} height={H} defaultProps={{ hook: 1 as const }} />
    <Still id="Cover-H2" component={Hero} width={W} height={H} defaultProps={{ hook: 2 as const }} />
    <Still id="Cover-H3" component={Hero} width={W} height={H} defaultProps={{ hook: 3 as const }} />
  </>
);
