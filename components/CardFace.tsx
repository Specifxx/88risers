interface Props {
  name: string;
  id: number | string;
  title?: string | null;
  photo?: string | null;
  card?: string | null;
  mystery?: boolean;
  priority?: boolean;
}

/** The art inside a slab: the printed champion card if there is one, otherwise a generated face. */
export function CardFace({ name, id, title, photo, card, mystery, priority }: Props) {
  if (card) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={card} alt={`${name}'s 88 Risers champion card`} loading={priority ? "eager" : "lazy"} />;
  }
  const num = typeof id === "number" ? String(id).padStart(3, "0") : id;
  return (
    <div className="face">
      {photo ? (
        <>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="face-photo" src={photo} alt="" loading={priority ? "eager" : "lazy"} />
          <div className="face-shade" />
        </>
      ) : (
        <>
          <div className="face-ghost">88</div>
          {mystery ? <div className="face-q">?</div> : null}
        </>
      )}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="face-crest" src="/crest.jpg" alt="" />
      <div className="face-num">
        {mystery ? "NEXT" : "MEMBER"}
        <b className="gold-text">{num}</b>
      </div>
      <div className="face-body">
        <p className="face-name gold-text">{name}</p>
        <div className="face-title">{title || (mystery ? "Future champion" : "88 Risers puller")}</div>
        <div className="face-club">88 Risers · Arm Wrestling Club</div>
      </div>
    </div>
  );
}
