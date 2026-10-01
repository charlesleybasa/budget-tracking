// Narrator lines in public/vo/narrator.wav: [start s, end s, subtitle]. The narrator is three
// Flow (Omni) voice takes joined 10 s apart (public/vo/raw/); timings come from a word-timed
// transcript (faster-whisper) so each line lands on its scene.
export const VO_FILE = "vo/narrator.wav";

export const VO = {
  world: [0.0, 4.85, "In a world… where sahod lasts… five days."],
  woman: [5.4, 7.1, "One woman."],
  wallet: [8.05, 9.3, "One wallet."],
  where: [9.95, 13.18, "Pesolita shows you exactly where every peso went…"],
  safe: [13.45, 15.82, "…and how much is safe to spend today."],
  log: [16.55, 19.23, "Log every gastos in four seconds."],
  day30: [19.95, 22.6, "Day 30. Chill lang."],
  peligro: [23.1, 25.83, "Petsa de peligro? Hindi na."],
  free: [26.35, 29.52, "Pesolita. Free on the App Store."],
} as const;
