import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Smart Ref Camera",
  description:
    "The 88 Risers Smart Ref: an AI referee assistant that runs on your phone. It tracks elbows and shoulders, flags fouls and gives instant slow-mo replays.",
};

const STEPS: { n: string; title: string; text: string }[] = [
  {
    n: "01",
    title: "Set up",
    text: "Stand your phone on a tripod at one end of the table, lined up with the centre line at chest height, in landscape. Both elbow pads and both pullers' shoulders need to be in shot.",
  },
  {
    n: "02",
    title: "Calibrate",
    text: "Tap two points on the centre line, then two corners around each elbow pad. Your phone remembers it, so you only redo it when the phone moves.",
  },
  {
    n: "03",
    title: "Pull",
    text: "Hit Ready, then Go. The camera tracks both pullers. An elbow off the pad or a shoulder over the line makes the phone beep and vibrate.",
  },
  {
    n: "04",
    title: "Review",
    text: "The ref confirms or dismisses every call. Each one comes with a slow-mo replay you can scrub frame by frame and save as a clip for socials.",
  },
];

export default function CameraPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Camera
          </p>
          <h1 className="display">
            Smart Ref <span className="gold-text">Camera.</span>
          </h1>
          <p className="lede">
            An AI referee assistant that runs on your phone. It tracks both pullers&apos; elbows and shoulders, flags fouls as they happen and gives the
            ref an instant slow-mo replay. Nothing to install: everything runs on the phone.
          </p>
          <div className="cam-cta">
            {/* plain links: /camera/live is a standalone full-screen page, not a React route */}
            <a className="btn btn-primary" href="/camera/live">
              Open the camera
            </a>
            <a className="btn" href="/camera/live#demo">
              Watch the demo
            </a>
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap">
          <p className="eyebrow">How it works</p>
          <ol className="cam-steps">
            {STEPS.map((s) => (
              <li key={s.n} className="panel">
                <span className="cam-num">{s.n}</span>
                <h2>{s.title}</h2>
                <p>{s.text}</p>
              </li>
            ))}
          </ol>

          <div className="panel cam-notes">
            <p className="eyebrow">Good to know</p>
            <ul>
              <li>The ref always has the final say. The camera suggests calls; it never decides them.</li>
              <li>One phone covers one side of the table. Good light and a steady tripod matter more than which phone you use.</li>
              <li>
                The first run downloads the AI model, so it needs internet. Allow camera access when your phone asks. Video never leaves your
                phone.
              </li>
              <li>
                Using the 88 Risers app from your home screen? Camera is in the menu. New to it? <Link href="/app">Get the app</Link>.
              </li>
            </ul>
          </div>
        </div>
      </section>
    </>
  );
}
