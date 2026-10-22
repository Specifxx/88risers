export const levels = {
  rookie: { width:24, duration:1900, accuracy:.42 },
  club: { width:19, duration:1550, accuracy:.60, streakWidth:.78, streakDuration:.88, minWidth:4, minDuration:700 },
  elite: { width:15, duration:1250, accuracy:.74, streakWidth:.70, streakDuration:.84, minWidth:3, minDuration:550 },
  // The boss tier: the tightest arcs, fastest sweeps and fiercest counters, and
  // sweeps can reverse from the very first check.
  kelvinator: { width:12, duration:1050, accuracy:.84, streakWidth:.64, streakDuration:.8, minWidth:3, minDuration:500,
    reverseFrom:1, reverseChance:.5 },
};
export const hasStreakPressure = level => levels[level].streakWidth !== undefined;
export const MAX_CHECKS = 24;
export const isActive = match => !['idle', 'done'].includes(match.stage);

export function createMatch(level = 'rookie', random = Math.random) {
  if (!levels[level]) throw new Error('Unknown opponent');
  return { level, random, stage:'idle', position:0, score:0, streak:0, marker:0,
    target:50, width:levels[level].width, duration:levels[level].duration,
    elapsed:0, checkTime:0, check:0, direction:1, attempt:null, opponent:0, outcome:null, bonus:0 };
}
export function startMatch(match) {
  if (isActive(match)) return;
  Object.assign(match, createMatch(match.level, match.random), { stage:'countdown' });
}
function beginCheck(match) {
  const config = levels[match.level];
  const fatigue = Math.min(match.elapsed / 60000, 1);
  match.stage = 'check';
  match.checkTime = 0;
  match.check++;
  match.attempt = null;
  // Successful streaks tighten the next check on harder opponents. A miss or
  // timeout resets the streak; the existing time-based fatigue still applies.
  match.width = Math.max(config.minWidth ?? 8, (config.width - fatigue * 8) * (config.streakWidth ?? 1) ** match.streak);
  match.duration = Math.max(config.minDuration ?? 0, config.duration * (1 - fatigue * .3) * (config.streakDuration ?? 1) ** match.streak);
  match.direction = match.check >= (config.reverseFrom ?? 4) && match.random() < (config.reverseChance ?? .45) ? -1 : 1;
  match.marker = match.direction === 1 ? 0 : 100;
  match.target = match.width / 2 + 8 + match.random() * (84 - match.width);
  match.opponent = match.random() < config.accuracy ? (match.random() < .22 ? 25 : 17) : 0;
}
function resolveCheck(match) {
  const hit = ['hit', 'perfect'].includes(match.attempt);
  if (hit) {
    match.streak++;
    match.score += (match.attempt === 'perfect' ? 150 : 80) + Math.min(match.streak - 1, 10) * 10;
  } else match.streak = 0;
  const gain = match.attempt === 'perfect' ? 34 : hit ? 24 : -12;
  match.position = Math.max(-100, Math.min(100, match.position + gain - match.opponent));
  match.stage = 'result';
  match.checkTime = 0;
  if (Math.abs(match.position) >= 100 || match.check >= MAX_CHECKS) {
    match.stage = 'done';
    match.outcome = match.position > 0 ? 'win' : match.position < 0 ? 'loss' : 'draw';
    if (match.outcome === 'win') {
      match.bonus = Math.max(0, MAX_CHECKS - match.check) * 25;
      match.score += match.bonus;
    }
  }
}
export function takePull(match) {
  if (match.stage !== 'check' || match.attempt !== null) return false;
  const distance = Math.abs(match.marker - match.target);
  match.attempt = distance <= match.width * .12 ? 'perfect' : distance <= match.width / 2 ? 'hit' : 'miss';
  resolveCheck(match);
  return true;
}
export function advanceMatch(match, delta) {
  if (!Number.isFinite(delta) || delta <= 0) return;
  // Carry elapsed time across phases so sweep speed is independent of frame rate.
  while (delta > 0 && isActive(match)) {
    const phaseDuration = match.stage === 'countdown' ? 1500 : match.stage === 'result' ? 800 : match.duration;
    const step = Math.min(delta, phaseDuration - match.checkTime);
    match.checkTime += step;
    match.elapsed += step;
    delta -= step;
    if (match.stage === 'check') {
      const phase = match.checkTime / match.duration;
      match.marker = match.direction === 1 ? phase * 100 : 100 - phase * 100;
    }
    if (match.checkTime >= phaseDuration) {
      if (match.stage === 'check') {
        match.attempt = 'timeout';
        resolveCheck(match);
      } else beginCheck(match);
    }
  }
}
