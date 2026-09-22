/* Private-room transport. Seat credentials stay in this tab, never in invite URLs. */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const storageKey = 'breakfast-balls-online-v1';
  const golfers = ['Ernie Eggs', 'Thotty Scheffler', 'Rory Whacklroy', 'Ballin Morikowa', 'Jon Rahmlette', 'Bready Couples', 'Justin Thyme', 'Bubba Waffles'];
  const modes = ['Stroke play', 'Skins', 'Pin Challenge'];
  let credentials = null;
  let room = null;
  let bridge = null;
  let bridgeReadyResolve;
  const bridgeReady = new Promise((resolve) => { bridgeReadyResolve = resolve; });
  let enginePromise = null;
  let appliedRevision = -1;
  let connected = false;
  let stopped = true;
  let busy = false;
  let inRequest = false;
  let starting = false;
  let actionQueue = [];
  let timer = null;
  let failures = 0;
  let transientMessage = '';
  let generation = 0;

  function message(value = '', error = false) {
    $('online-message').textContent = value;
    $('online-message').dataset.error = String(error);
  }

  function saveCredentials(paused = false) {
    try {
      if (credentials) sessionStorage.setItem(storageKey, JSON.stringify({ ...credentials, paused }));
      else sessionStorage.removeItem(storageKey);
    } catch { message('Your browser could not save this seat. Keep this tab open to stay in the room.', true); }
  }

  function command(value) {
    if (bridge) bridge(JSON.stringify(value));
  }

  function canAct() {
    return !!(credentials && connected && !stopped && !actionQueue.length && !starting && room?.status !== 'finished' && room?.snapshot && credentials.seat === room.snapshot.player_index);
  }

  function render() {
    const joined = !!(credentials && room && !stopped);
    const playing = joined && room.status !== 'lobby';
    $('online-setup').hidden = joined;
    $('online-lobby').hidden = !joined;
    $('online-resume-room').hidden = !(credentials && stopped);
    $('online-reset').hidden = !(credentials && stopped);
    $('online-bar').hidden = !playing;
    document.documentElement.dataset.online = String(playing);
    if (window.BreakfastLaunch?.state === 'playing') {
      $('footer-hint').textContent = playing
        ? 'Play your own shots · Keep this tab open during your shot · Shift + Tab for page controls'
        : 'Click the game to play · H for help · Esc to pause · Shift + Tab for page controls';
      $('canvas-instructions').textContent = playing
        ? 'On your turn, use the arrow keys to aim, Q and E to change clubs, and hold Space then release to swing. Enter continues after your shot. The scorecard appears when all golfers finish a hole. Shift plus Tab leaves the game and moves to the page controls.'
        : 'Use the arrow keys to aim, Q and E to change clubs, and hold Space then release to swing. Tab opens the scorecard. Escape pauses. Shift plus Tab leaves the game and moves to the page controls.';
    }
    $('online-create').disabled = busy;
    $('online-join').disabled = busy;
    if (!joined) return;
    $('online-room-code').textContent = room.code;
    $('online-bar-code').textContent = room.code;
    const config = room.config;
    $('online-round-summary').textContent = `${modes[config.mode]} · ${config.mode === 2 ? 3 : config.holes} holes · ${config.tees ? 'Club' : 'Championship'} tees${config.holes === 9 && config.mode !== 2 ? (config.nine ? ' · Back nine' : ' · Front nine') : ''}`;
    $('online-roster').replaceChildren(...room.seats.map((seat, index) => {
      const item = document.createElement('li');
      const number = document.createElement('span');
      number.className = 'seat-number'; number.textContent = String(index + 1);
      const info = document.createElement('span'); info.className = 'seat-info';
      const name = document.createElement('strong'); name.textContent = seat.name;
      const golfer = document.createElement('small'); golfer.textContent = golfers[seat.golfer];
      info.append(name, golfer);
      const role = document.createElement('span'); role.className = 'seat-role';
      role.textContent = [index === credentials.seat ? 'You' : '', index === 0 ? 'Host' : ''].filter(Boolean).join(' · ');
      item.append(number, info, role); return item;
    }));
    $('online-start').hidden = playing || credentials.seat !== 0;
    $('online-start').disabled = room.seats.length < 2 || starting || !connected || actionQueue.length > 0;
    $('online-return').hidden = !playing;
    $('online-lobby-hint').textContent = playing ? 'Refresh this tab to reconnect to your seat. Share this room only with people you want to play with.' : credentials.seat === 0 ? (room.seats.length < 2 ? 'Share the invite. You can tee off once another golfer joins.' : `${room.seats.length} golfers ready. Start when everyone is here.`) : 'You are in. The host will start the round when everyone is here.';
    const activeName = room.seats[room.snapshot?.player_index]?.name || 'your group';
    let status = transientMessage || (starting ? 'Opening the course…' : !connected ? 'Reconnecting… your seat is saved' : actionQueue.length ? 'Syncing your shot…' : room.status === 'finished' ? 'Round complete' : canAct() ? 'Your turn' : `Watching ${activeName}`);
    if (!connected && failures > 4) status = 'Connection interrupted · retrying';
    $('online-bar-status').textContent = status;
    const shotAge = room.shotStartedAt ? Date.now() - (typeof room.shotStartedAt === 'number' ? room.shotStartedAt : Date.parse(room.shotStartedAt)) : 0;
    $('online-recover').hidden = !(playing && connected && room.shotStartedAt && shotAge >= 60000);
    $('online-recover').disabled = actionQueue.length > 0;
    $('online-recovery-note').hidden = !(playing && room.shotStartedAt);
  }

  function inviteURL() {
    const url = new URL(location.href);
    url.search = ''; url.hash = ''; url.searchParams.set('room', credentials.code);
    return url.toString();
  }

  async function copyInvite() {
    try {
      await navigator.clipboard.writeText(inviteURL());
      $('announcement').textContent = 'Room invite copied.';
      message('Invite copied. Send it to your friends.');
      transientMessage = 'Invite copied'; render();
      setTimeout(() => { transientMessage = ''; render(); }, 2200);
    } catch {
      message(`Copy this invite link: ${inviteURL()}`);
    }
  }

  function schedule(delay) {
    clearTimeout(timer);
    if (!stopped && !(room?.status === 'finished' && !actionQueue.length)) timer = setTimeout(tick, delay);
  }

  function pollDelay() {
    if (failures) return Math.min(10000, 1000 * 2 ** Math.min(failures - 1, 4));
    if (document.hidden) return 5000;
    return room?.shotStartedAt || room?.status === 'lobby' ? 1000 : 1800;
  }

  async function request(body) {
    const response = await fetch('/api/room', {
      method: 'POST', credentials: 'omit', cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(12000),
    });
    let data;
    try { data = await response.json(); } catch { throw new Error('The clubhouse is not responding. Trying again…'); }
    if (!response.ok) {
      const error = new Error(data.message || 'The room request could not be completed.');
      error.status = response.status; error.room = data.room; error.code = data.error;
      throw error;
    }
    if (!data.room || !Number.isInteger(data.room.revision)) throw new Error('The clubhouse returned an incomplete update. Trying again…');
    return data;
  }

  async function ensureEngine() {
    if (!enginePromise) enginePromise = (async () => {
      if ($('online-dialog').open) $('online-dialog').close();
      await window.BreakfastLaunch.start();
      if (window.BreakfastLaunch.state === 'error') throw new Error('The game could not open. Reload this tab to reconnect.');
      let timeout;
      try {
        await Promise.race([bridgeReady, new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('The game is taking too long to connect. Reload this tab to reconnect.')), 90000); })]);
      } finally { clearTimeout(timeout); }
    })();
    return enginePromise;
  }

  async function acceptRoom(next, selfAction = false) {
    room = next;
    if (failures) message('');
    connected = true; failures = 0;
    if (room.notice) message(room.notice);
    render();
    if (room.status === 'lobby' || !room.snapshot) return;
    await ensureEngine();
    if (stopped) return;
    // A load may take a while. Apply the freshest canonical room available.
    if (room.revision <= appliedRevision) {
      if (!actionQueue.length) command({ type: 'ack', revision: room.revision, canAct: canAct() });
      return;
    }
    appliedRevision = room.revision;
    if (selfAction) command({ type: 'ack', revision: room.revision, canAct: canAct() });
    else command({ type: 'apply', seat: credentials.seat, revision: room.revision, snapshot: room.snapshot, canAct: canAct(), seats: room.seats, config: room.config });
    render();
  }

  async function tick() {
    if (stopped || inRequest || !credentials) return;
    inRequest = true;
    const cycle = generation;
    const action = actionQueue[0];
    if (action && action.revision === undefined) action.revision = room.revision;
    try {
      const response = await request({ code: credentials.code, token: credentials.token, ...(action || { op: 'poll' }) });
      if (cycle !== generation) return;
      if (action) actionQueue.shift();
      if (action?.op === 'start' || response.room.status !== 'lobby') starting = false;
      await acceptRoom(response.room, !!action && action.op !== 'recover' && response.room.revision === action.revision + 1);
    } catch (error) {
      if (cycle !== generation) return;
      if (error.status && error.status < 500 && error.status !== 429) {
        actionQueue = []; starting = false;
        if (action?.op === 'start') {
          // A friend can join while the host downloads the game. If that
          // changes the lobby revision, let the host start with its new roster.
          command({ type: 'leave' });
          if (!$('online-dialog').open) $('online-dialog').showModal();
        }
        if (error.status === 401 || error.status === 404 || error.status === 410 || error.code === 'wrong_origin') {
          stopped = true; connected = false; command({ type: 'lock' });
          saveCredentials(true);
          message(`${error.message} You can try resuming, or create or join another room.`, true);
          $('online-dialog').showModal();
          render();
        } else {
          message(error.message, true);
          appliedRevision = -1;
          if (error.room) {
            await acceptRoom(error.room);
          } else {
            connected = false; command({ type: 'lock' });
          }
        }
      } else {
        connected = false; failures += 1;
        command({ type: 'lock' });
        message(action ? 'Connection interrupted. Reconnecting and checking whether your action arrived…' : 'Connection interrupted. Your seat is saved; reconnecting…', true);
        render();
      }
    } finally {
      inRequest = false;
      if (cycle === generation) schedule(actionQueue.length && !failures ? 0 : pollDelay());
    }
  }

  function enqueue(op, snapshot) {
    if (stopped || !credentials || !room) return;
    const action = { op, actionId: crypto.randomUUID() };
    if (snapshot) action.snapshot = snapshot;
    actionQueue.push(action);
    command({ type: 'lock' }); render(); schedule(0);
  }

  window.BreakfastOnline = Object.freeze({
    ready(callback) {
      if (typeof callback !== 'function') return;
      bridge = callback; bridgeReadyResolve();
    },
    emit(json) {
      let value;
      try { value = typeof json === 'string' ? JSON.parse(json) : json; } catch { return; }
      if (!value || !['start', 'shot', 'settle', 'advance', 'breakfast', 'next'].includes(value.action)) return;
      enqueue(value.action, value.snapshot);
    },
  });

  async function enterRoom(op) {
    if (busy) return;
    if (!$('online-name').reportValidity()) return;
    const code = $('online-code').value.trim().toUpperCase();
    if (op === 'join' && !/^[A-Z0-9]{6}$/.test(code)) { message('Enter the six-character code from your invite.', true); $('online-code').focus(); return; }
    busy = true; message(op === 'create' ? 'Reserving your tee time…' : 'Joining your foursome…'); render();
    try {
      const config = { mode: Number($('online-mode').value), holes: Number($('online-holes').value), tees: Number($('online-tees').value), nine: Number($('online-nine').value) };
      if (config.mode === 2) config.holes = 3;
      const data = await request({ op, code: op === 'join' ? code : undefined, name: $('online-name').value.trim().toUpperCase(), golfer: Number($('online-golfer').value), config: op === 'create' ? config : undefined, actionId: crypto.randomUUID() });
      credentials = { code: data.code || data.room.code, token: data.token, seat: data.seat };
      if (!credentials.token || !Number.isInteger(credentials.seat)) throw new Error('Your seat could not be confirmed. Try again.');
      generation += 1; stopped = false; connected = true; failures = 0; appliedRevision = -1;
      saveCredentials(); message('');
      await acceptRoom(data.room);
      schedule(0);
    } catch (error) { message(error.message || 'Unable to join the room. Try again.', true); }
    finally { busy = false; render(); }
  }

  async function startRound() {
    if (starting || room?.status !== 'lobby' || credentials?.seat !== 0 || room.seats.length < 2) return;
    starting = true; render();
    try {
      await ensureEngine();
      if (stopped) return;
      command({ type: 'start', seat: credentials.seat, seats: room.seats, config: room.config });
      // The game creates the initial canonical snapshot and emits "start".
    } catch (error) {
      starting = false; message(error.message, true); $('online-dialog').showModal(); render();
    }
  }

  function leaveRoom() {
    stopped = true; generation += 1; clearTimeout(timer);
    actionQueue = []; command({ type: 'leave' }); saveCredentials(true);
    const url = new URL(location.href); url.searchParams.delete('room');
    location.replace(url.toString());
  }

  function openDialog() {
    if (!$('online-dialog').open) $('online-dialog').showModal();
    render();
    if (!room && $('online-code').value) $('online-name').focus();
  }

  function updateOptions() {
    const pin = $('online-mode').value === '2';
    $('online-holes').disabled = pin;
    if (pin) $('online-holes').value = '3';
    $('online-nine-label').hidden = pin || $('online-holes').value !== '9';
  }

  $('play-online').addEventListener('click', openDialog);
  $('online-close').addEventListener('click', () => $('online-dialog').close());
  $('online-dialog').addEventListener('close', () => {
    if (window.BreakfastLaunch?.state === 'playing') $('canvas').focus({ preventScroll: true });
    else $('play-online').focus({ preventScroll: true });
  });
  $('online-form').addEventListener('submit', (event) => { event.preventDefault(); enterRoom('create'); });
  $('online-join').addEventListener('click', () => enterRoom('join'));
  $('online-name').addEventListener('input', () => { $('online-name').value = $('online-name').value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5); });
  $('online-code').addEventListener('input', () => { $('online-code').value = $('online-code').value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6); });
  $('online-code').addEventListener('keydown', (event) => { if (event.key === 'Enter') { event.preventDefault(); enterRoom('join'); } });
  $('online-mode').addEventListener('change', updateOptions);
  $('online-holes').addEventListener('change', updateOptions);
  $('online-start').addEventListener('click', startRound);
  $('online-copy').addEventListener('click', copyInvite);
  $('online-bar-invite').addEventListener('click', copyInvite);
  $('online-room-details').addEventListener('click', openDialog);
  $('online-return').addEventListener('click', () => $('online-dialog').close());
  $('online-leave').addEventListener('click', leaveRoom);
  $('online-lobby-leave').addEventListener('click', leaveRoom);
  $('online-reset').addEventListener('click', leaveRoom);
  $('online-recover').addEventListener('click', () => enqueue('recover'));
  $('online-resume-room').addEventListener('click', () => {
    stopped = false; connected = false; failures = 0; message('Reconnecting to your room…'); saveCredentials(); render(); schedule(0);
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden && !stopped) schedule(0); });
  window.addEventListener('online', () => { if (!stopped) { failures = 0; schedule(0); } });
  window.addEventListener('offline', () => { connected = false; command({ type: 'lock' }); render(); });

  const inviteCode = new URL(location.href).searchParams.get('room')?.toUpperCase();
  if (inviteCode && /^[A-Z0-9]{6}$/.test(inviteCode)) $('online-code').value = inviteCode;
  try {
    const saved = JSON.parse(sessionStorage.getItem(storageKey) || 'null');
    if (saved && /^[A-Z0-9]{6}$/.test(saved.code) && typeof saved.token === 'string' && Number.isInteger(saved.seat) && (!inviteCode || inviteCode === saved.code)) {
      credentials = { code: saved.code, token: saved.token, seat: saved.seat };
      stopped = !!saved.paused;
      if (!stopped) {
        message('Reconnecting to your room…');
        // The shell defines its engine launcher later in this document.
        setTimeout(() => { openDialog(); schedule(0); }, 0);
      }
    }
  } catch { /* A fresh room remains available when browser storage is disabled. */ }
  if (inviteCode && stopped) setTimeout(openDialog, 0);
  render();
})();
