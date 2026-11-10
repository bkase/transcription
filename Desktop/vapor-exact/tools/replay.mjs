import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";

const app = resolve(import.meta.dir, "..");
const sdk = resolve(app, process.env.EXACT2 ?? "../../../exact-vapor");
process.env.EXACT_APP_DIR = app;
process.env.EXACT_SHOW_SIMULATOR = "0";
const { open } = await import(resolve(sdk, "scripts/agent.mjs"));
const host = process.argv[2] ?? "macos";
const url = process.argv[3];
const source = resolve(app, "app.contract");
const data = resolve(app, "app.ts");
const original = url ? await readFile(source, "utf8") : null;
const originalData = url ? await readFile(data, "utf8") : null;
let processChild;
const drive = await open({
  app, host, url, onProcess: child => { processChild = child; }, storage: `vapor-replay-${randomUUID()}`, size: host === "ios" ? undefined : [390, 844],
  env: { EXACT_AGENT_EPHEMERAL_PORT: "1", EXACT_AGENT_STORAGE_FRESH: "1" },
});

try {
  const read = async () => (await drive.state()).resources;
  const expectText = async (id, text) => {
    const deadline = performance.now() + 45000;
    while (performance.now() < deadline) {
      const node = (await drive.tree()).nodes.find(node => node.props?.testId === id);
      if (JSON.stringify(node)?.includes(text)) return;
      await Bun.sleep(75);
    }
    assert.fail(JSON.stringify(await drive.logs({ all: true })));
  };
  const tap = async id => {
    await drive.tap(id);
    await drive.clock("settle");
  };
  if (url) await Bun.sleep(1000);
  await drive.prefer({ "permission.microphone": "granted" });
  await drive.clock("settle");
  assert.equal((await read()).library.sessions.length, 0);
  if (!original) {
    await tap("startRecordingButton");
    await drive.clock("+1000");
    await tap("backButton");
    await tap("cancelModal");
    assert.equal((await read()).recorder.state, "recording");
    await tap("backButton");
    await tap("discardRecording");
    assert.equal((await read()).library.sessions.length, 0);
  }
  await tap("startRecordingButton");
  const initial = (await read()).recorder.duration;
  await drive.clock("+3000");
  assert.equal((await read()).recorder.duration - initial, 3000);
  await tap("pauseButton");
  const paused = (await read()).recorder.duration;
  await drive.clock("+2000");
  assert.equal((await read()).recorder.duration, paused);
  if (original) {
    const changed = original
      .replace('isPaused ? "Paused" : isLive', 'isPaused ? "Paused after edit" : isLive')
      .replace('text "Timeline" font-size=28', 'text "Timeline after edit" font-size=28')
      .replace('keepTake(takeId, media.path, media.duration, names.slice(0, count))', 'keepTake(takeId, media.path, media.duration, ["Hot Speaker"].concat(names.slice(1, count)))');
    const changedData = originalData.replace('"Untitled Recording"', '"Updated Recording"');
    assert.notEqual(changed, original);
    assert.notEqual(changedData, originalData);
    const pid = processChild?.pid;
    await writeFile(source, original + "\ncomponent\n");
    await Bun.sleep(900);
    assert.equal((await read()).recorder.duration, paused);
    const started = performance.now();
    await Promise.all([writeFile(source, changed), writeFile(data, changedData)]);
    await expectText("recordingMessage", "Paused after edit");
    assert.equal((await read()).recorder.duration, paused);
    assert.equal(processChild?.pid, pid);
    console.log(`${host}: paused take survived reload in PID ${pid} after ${Math.round(performance.now() - started)} ms`);
  }
  await tap("resumeButton");
  const resumedRecorder = (await read()).recorder;
  assert.equal(resumedRecorder.state, "recording", JSON.stringify(await drive.logs({ all: true })));
  const resumed = resumedRecorder.duration;
  await drive.clock("+2000");
  assert.equal((await read()).recorder.duration - resumed, 2000);
  await tap("pauseButton");
  const duration = (await read()).recorder.duration;
  await tap("speakerSetupToggle");
  await tap("speakerCount2");
  await tap("speakerRow0");
  await drive.type("speakerName", "Alex");
  await tap("saveName");
  await tap("stopAndSaveButton");
  const [take] = (await read()).library.sessions;
  assert.equal(take.duration, duration);
  assert.equal(take.title, original ? "Updated Recording" : "Untitled Recording");
  const speaker = original ? "Hot Speaker" : "Alex";
  assert.deepEqual(take.speakers, [speaker, "Speaker 2"]);
  await drive.type("search", speaker);
  await tap(`session-${take.id}`);
  await tap("playbackButton");
  const media = (await drive.state()).media;
  assert.ok(media.some(player => player.state?.paused === false));
  if (original) {
    await tap("backButton");
    await expectText("timelineTitle", "Timeline after edit");
    await Promise.all([writeFile(source, original), writeFile(data, originalData)]);
    await expectText("timelineTitle", '"Timeline"');
  }
  console.log(`${host}: ${original ? "resumed and" : "discarded a draft and"} kept a ${(duration / 1000).toFixed(3)} s recording, searched by speaker, and played it`);
} finally {
  if (original) await Promise.all([writeFile(source, original), writeFile(data, originalData)]);
  await drive.close();
}
