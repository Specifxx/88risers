import { advanceMatch, createMatch, hasStreakPressure, isActive, MAX_CHECKS, startMatch, takePull } from './rules.js';

const $ = id => document.getElementById(id);
const embedded = new URLSearchParams(location.search).has('embedded');
document.body.classList.toggle('embedded', embedded);
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let match = createMatch();
let containerVisible = !embedded;
let paused = false;
let frameId = null;
let last = performance.now();
let visualPosition = 0;
let renderedPhase = '';
const progress = document.querySelector('.progress');
const main = document.querySelector('main');
const card = document.querySelector('.card');
const arena = document.querySelector('.match-view');
const banner = $('banner');
let bannerTimer;
const pauseOverlay = $('pause-overlay');
pauseOverlay.setAttribute('role', 'dialog');
pauseOverlay.setAttribute('aria-modal', 'true');
pauseOverlay.setAttribute('aria-label', 'Match paused');

// Visual-only randomness (letter tilt, confetti) never consumes the match's random source.
let seed = (Date.now() ^ 0x9e3779b9) >>> 0;
function visualRandom() {
  seed = (seed + 0x6d2b79f5) >>> 0;
  let t = seed;
  t = Math.imul(t ^ t >>> 15, t | 1);
  t ^= t + Math.imul(t ^ t >>> 7, t | 61);
  return ((t ^ t >>> 14) >>> 0) / 4294967296;
}
const pick = list => list[Math.floor(visualRandom() * list.length)];
function drawTicks() {
  const ticks = $('ticks');
  for (let i = 0; i < 50; i++) {
    const angle = i * Math.PI / 25 - Math.PI / 2, major = i % 5 === 0;
    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    const [inner, outer] = major ? [115, 125] : [118, 123];
    line.setAttribute('x1', 140 + inner * Math.cos(angle)); line.setAttribute('y1', 140 + inner * Math.sin(angle));
    line.setAttribute('x2', 140 + outer * Math.cos(angle)); line.setAttribute('y2', 140 + outer * Math.sin(angle));
    if (major) line.classList.add('major');
    ticks.append(line);
  }
}
// Ransom-note banner: each letter is a separate scrap with its own type and tilt.
function showBanner(text, { hold = false, kind = '' } = {}) {
  clearTimeout(bannerTimer);
  banner.replaceChildren(...[...text].map((character, index) => {
    const glyph = document.createElement('span');
    glyph.style.setProperty('--i', index);
    if (character === ' ') { glyph.className = 'glyph gap'; return glyph; }
    glyph.textContent = character;
    glyph.className = `glyph ${index % 3 === 1 ? 'tone' : pick(['paper', 'paper', 'ink'])} f-${pick(['display', 'display', 'cond', 'serif', 'type'])}`;
    glyph.style.setProperty('--r', `${(visualRandom() * 18 - 9).toFixed(1)}deg`);
    glyph.style.setProperty('--y', `${(visualRandom() * 14 - 7).toFixed(1)}%`);
    return glyph;
  }));
  banner.style.setProperty('--n', Math.max(3, text.length));
  banner.dataset.kind = kind;
  banner.classList.remove('show');
  void banner.offsetWidth; // Restart the pop animation for repeated words.
  banner.classList.add('show');
  if (!hold) bannerTimer = setTimeout(() => banner.classList.remove('show'), 680);
}
function hideBanner() {
  clearTimeout(bannerTimer);
  banner.classList.remove('show');
}
function restartClass(element, prefix, kind) {
  element.classList.remove(`${prefix}-perfect`, `${prefix}-hit`, `${prefix}-miss`);
  void element.offsetWidth;
  element.classList.add(`${prefix}-${kind}`);
}
function impact(kind) {
  if (reducedMotion.matches) return;
  // Shake the arena only; the HUD and controls stay put and readable.
  restartClass(arena, 'shake', kind);
  restartClass($('flash'), 'flash', kind);
}
function confetti() {
  const layer = $('confetti');
  layer.replaceChildren();
  if (reducedMotion.matches) return;
  for (let i = 0; i < 28; i++) {
    const piece = document.createElement('i');
    piece.className = pick(['paper', 'paper', 'tone', 'ink']);
    piece.style.left = `${(visualRandom() * 100).toFixed(1)}%`;
    piece.style.setProperty('--w', `${Math.round(10 + visualRandom() * 16)}px`);
    piece.style.setProperty('--d', `${(1.4 + visualRandom() * 1.2).toFixed(2)}s`);
    piece.style.setProperty('--delay', `${(visualRandom() * .5).toFixed(2)}s`);
    piece.style.setProperty('--dx', `${Math.round(visualRandom() * 120 - 60)}px`);
    piece.style.setProperty('--spin', `${Math.round(visualRandom() * 900 - 450)}deg`);
    layer.append(piece);
  }
}
function bestKey() { return `88-risers-skill-best-${match.level}`; }
function readBest() {
  try {
    const score = Number(localStorage.getItem(bestKey()));
    return Number.isFinite(score) && score >= 0 ? score : 0;
  } catch { return 0; }
}
function showBest() {
  $('best').textContent = readBest();
}
function arcPath(start, end) {
  const point = value => {
    const angle = value * Math.PI / 50 - Math.PI / 2;
    return [140 + 105 * Math.cos(angle), 140 + 105 * Math.sin(angle)];
  };
  const a = point(start), b = point(end);
  return `M${a[0]} ${a[1]}A105 105 0 ${end - start > 50 ? 1 : 0} 1 ${b[0]} ${b[1]}`;
}
function drawArms(dt = 0) {
  visualPosition += (match.position - visualPosition) * (reducedMotion.matches ? 1 : 1 - Math.exp(-dt / 140));
  const lean = visualPosition / 100;
  const breathe = isActive(match) && !reducedMotion.matches && !paused ? Math.sin(match.elapsed / 150) : 0;
  const x = 380 + lean * 205 + breathe, y = 105 + Math.abs(lean) * 170;
  for (const side of ['L', 'R']) {
    const elbow = side === 'L' ? 280 : 480;
    const dx = x + (side === 'L' ? -10 : 10) - elbow, dy = y + 25 - 306;
    $('forearm' + side).setAttribute('transform', `translate(${elbow} 306) rotate(${Math.atan2(dx, -dy) * 180 / Math.PI}) scale(1 ${Math.hypot(dx, dy) / 190})`);
  }
  $('hands').setAttribute('transform', `translate(${x} ${y}) rotate(${lean * 62})`);
}
function render() {
  $('marker').setAttribute('transform', `rotate(${match.marker * 3.6} 140 140)`);
  $('action').disabled = !canRun() || ['countdown', 'result'].includes(match.stage);
  const phaseKey = `${match.stage}:${match.check}:${Math.ceil((1500 - match.checkTime) / 500) * (match.stage === 'countdown')}`;
  if (phaseKey === renderedPhase) return;
  renderedPhase = phaseKey;
  card.dataset.stage = match.stage;
  card.classList.toggle('danger', isActive(match) && match.position <= -60);
  $('meter').classList.toggle('reverse', match.stage === 'check' && match.direction === -1);
  $('meter').dataset.result = match.stage === 'result' ? match.attempt : '';
  $('position').style.left = (match.position + 100) / 2 + '%';
  progress.setAttribute('aria-valuenow', match.position);
  progress.setAttribute('aria-valuetext', match.position === 0 ? 'Even match' : `${Math.abs(match.position)} percent advantage to ${match.position > 0 ? 'you' : 'opponent'}`);
  $('score').textContent = match.score;
  $('streak').textContent = match.streak;
  $('difficulty').disabled = isActive(match);
  $('pause').disabled = !isActive(match);
  $('meter').classList.toggle('resolved', ['result', 'done'].includes(match.stage));
  $('feedback').dataset.tone = ['miss', 'timeout'].includes(match.attempt) ? 'miss' : 'hit';
  $('target').setAttribute('d', arcPath(match.target - match.width / 2, match.target + match.width / 2));
  $('perfect').setAttribute('d', arcPath(match.target - match.width * .12, match.target + match.width * .12));
  $('perfect-border').setAttribute('d', $('perfect').getAttribute('d'));
  if (match.stage === 'idle') {
    $('round').textContent = match.level === 'kelvinator' ? 'Face the Kelvinator?' : 'Ready to pull?';
    $('dial-direction').textContent = 'Ready';
    $('action').textContent = 'Start match';
    $('feedback').textContent = '';
    hideBanner();
  } else if (match.stage === 'countdown') {
    const count = Math.max(1, Math.ceil((1500 - match.checkTime) / 500));
    $('round').textContent = 'Get ready';
    $('dial-direction').textContent = count;
    $('action').textContent = 'Ready…';
    $('feedback').textContent = '';
    showBanner(String(count));
  } else if (match.stage === 'check') {
    const streakPressure = hasStreakPressure(match.level) && match.streak > 0;
    $('round').textContent = `Check ${match.check}/${MAX_CHECKS}`;
    $('dial-direction').textContent = match.direction === 1 ? 'Clockwise' : 'Reverse';
    $('action').textContent = 'PULL';
    $('feedback').textContent = streakPressure ? 'Faster · smaller target' : '';
    hideBanner();
  } else if (match.stage === 'result') {
    const hit = ['hit', 'perfect'].includes(match.attempt);
    $('dial-direction').textContent = match.attempt === 'perfect' ? 'Perfect!' : hit ? 'Hit!' : 'Miss';
    $('action').textContent = 'Next check…';
    $('feedback').textContent = match.attempt === 'timeout' ? 'Too late' : match.opponent ? 'Opponent counters' : 'Opponent misses';
    showBanner(match.attempt === 'perfect' ? 'Perfect' : hit ? 'Hit' : match.attempt === 'timeout' ? 'Too late' : 'Miss', { kind:match.attempt });
    impact(match.attempt === 'perfect' ? 'perfect' : hit ? 'hit' : 'miss');
  } else {
    const won = match.outcome === 'win', draw = match.outcome === 'draw';
    $('round').textContent = draw ? 'Draw' : won ? 'You win!' : 'Opponent wins';
    $('dial-direction').textContent = draw ? 'Draw' : won ? 'You win!' : 'Lost';
    $('action').textContent = 'Rematch';
    $('feedback').textContent = won && match.bonus ? `+${match.bonus} speed bonus` : '';
    const kelvinator = match.level === 'kelvinator';
    showBanner(draw ? 'Draw' : won ? (kelvinator ? 'Unstoppable' : 'You win') : (kelvinator ? 'Kelvinated' : 'Pinned'), { hold:true, kind:match.outcome });
    if (won) confetti();
    else if (!draw) impact('miss');
    if (won && match.score > readBest()) {
      try { localStorage.setItem(bestKey(), match.score); } catch { /* Play remains available when storage is blocked. */ }
      $('feedback').textContent = match.bonus ? `New best · +${match.bonus} bonus` : 'New best!';
    }
    showBest();
  }
}
function stopFrame() {
  if (frameId !== null) cancelAnimationFrame(frameId);
  frameId = null;
}
function canRun() { return containerVisible && !document.hidden && !paused; }
function scheduleFrame() {
  if (frameId === null && canRun() && (isActive(match) || Math.abs(visualPosition - match.position) > .1)) {
    frameId = requestAnimationFrame(frame);
  }
}
function syncClock() {
  const now = performance.now();
  if (canRun()) advanceMatch(match, now - last);
  last = now;
}
function frame() {
  frameId = null;
  const previous = last;
  syncClock();
  render();
  drawArms(last - previous);
  scheduleFrame();
}
function setPaused(value) {
  if (value && !paused && canRun()) syncClock();
  paused = value && isActive(match);
  pauseOverlay.hidden = !paused;
  for (const element of document.querySelector('main').children) {
    if (element !== pauseOverlay) element.inert = paused;
  }
  last = performance.now();
  stopFrame();
  render();
  if (containerVisible && !document.hidden) {
    if (paused) $('resume').focus();
    else if (isActive(match)) $('action').focus();
  }
  scheduleFrame();
}
function reset() {
  stopFrame();
  match = createMatch($('difficulty').value);
  main.dataset.level = match.level;
  $('confetti').replaceChildren();
  visualPosition = 0;
  renderedPhase = '';
  setPaused(false);
  render();
  drawArms();
  showBest();
}
function act() {
  if (!canRun()) return;
  const wasActive = isActive(match);
  syncClock(); // Judge against the actual input time, including time since the last frame.
  if (!wasActive) {
    startMatch(match);
    $('confetti').replaceChildren();
    visualPosition = 0;
    drawArms();
  } else takePull(match);
  render();
  scheduleFrame();
}
$('action').addEventListener('click', act);
$('reset').addEventListener('click', reset);
$('difficulty').addEventListener('change', reset);
$('pause').addEventListener('click', () => setPaused(true));
$('resume').addEventListener('click', () => setPaused(false));
document.addEventListener('keydown', event => {
  if (paused && event.key === 'Tab') { event.preventDefault(); $('resume').focus(); return; }
  if (event.key === 'Escape' && embedded) {
    event.preventDefault();
    window.parent.postMessage({ type:'88-arcade-close' }, location.origin);
    return;
  }
  if (paused && event.key === 'Escape') { event.preventDefault(); setPaused(false); return; }
  if (event.code !== 'Space' || event.altKey || event.ctrlKey || event.metaKey) return;
  const focused = document.activeElement;
  if (focused?.matches('select,input,textarea,a,[contenteditable="true"]') ||
    (focused?.tagName === 'BUTTON' && ![$('action'), $('resume')].includes(focused))) return;
  event.preventDefault();
  if (event.repeat) return;
  if (paused) setPaused(false);
  else act();
});
document.addEventListener('visibilitychange', () => {
  // Require an explicit resume so returning to a tab never costs a timing check.
  if (document.hidden) setPaused(true);
  last = performance.now();
  scheduleFrame();
});
window.addEventListener('message', event => {
  if (!embedded || event.origin !== location.origin || event.source !== window.parent || event.data?.type !== '88-arcade-visibility') return;
  if (event.data.visible !== true) setPaused(true);
  containerVisible = event.data.visible === true;
  last = performance.now();
  stopFrame();
  if (containerVisible && paused) $('resume').focus();
  render();
  scheduleFrame();
});
drawTicks();
reset();
if (embedded) window.parent.postMessage({ type:'88-arcade-ready' }, location.origin);
