/**
 * 88Risers FM: the channels 88RisersTV plays when nothing is live. Each channel is a set of
 * licensed internet radio stations (found via radio-browser.info), tried in order: if one
 * is down the player moves to the next. All streams must be https.
 */
export interface Station {
  name: string;
  url: string;
}
export interface RadioChannel {
  id: string;
  freq: string;
  name: string;
  tag: string;
  stations: Station[];
}

export const RADIO: RadioChannel[] = [
  {
    id: "pull-day",
    freq: "88.1",
    name: "Pull Day",
    tag: "Hype bangers for the table",
    stations: [
      { name: "rm.fm Workout", url: "https://workout-high.rautemusik.fm/" },
      { name: "FIT Radio High Energy", url: "https://radio.webicdp.com/listen/fmvfitradiohighenergy/radio.mp3" },
      { name: "Hotmix Sport Workout", url: "https://streaming.hotmixradio.com/hotmix-sport-plus-en-mp3" },
      { name: "WorkoutTime", url: "https://stream.zeno.fm/60pg6mi67hytv" },
    ],
  },
  {
    id: "golden-hour",
    freq: "88.5",
    name: "Golden Hour",
    tag: "Summer Afro house",
    stations: [
      { name: "Afro House (0nlineradio)", url: "https://0nlineradio.radioho.st/technolovers-afro-house" },
      { name: "Sunshine Live Afro House", url: "https://sunsl.streamabc.net/sunsl-sslafrohouse-aacplus-64-6818223" },
      { name: "Ibiza.fm", url: "https://streaming.radiostreamlive.com/ibizafm" },
      { name: "Pescobar Radio", url: "https://listen.radioking.com/radio/701141/stream/766385" },
    ],
  },
  {
    id: "phonk",
    freq: "88.8",
    name: "Phonk Drift",
    tag: "Phonk, Memphis, cowbells",
    stations: [
      { name: "laut.fm Phonk", url: "https://stream.laut.fm/phonk" },
      { name: "Phonk Nation Radio", url: "https://radio.mxnticek.eu/listen/phonk/128.mp3" },
      { name: "badradio 24/7 Phonk", url: "https://s2.radio.co/s2b2b68744/listen" },
      { name: "NCS Phonk", url: "https://radio.cliamp.stream/ncs-phonk/stream" },
    ],
  },
];
