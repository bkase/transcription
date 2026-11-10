import type { Answer, Sources, Storage } from "./app.contract.d.ts";

const directory = "app:/data/takes";
const index = `${directory}/index.json`;
export const grants = `device.microphone purpose.microphone\nfs.read ${directory}\nfs.write ${directory}`;

type Session = {
  id: string;
  title: string;
  path: string;
  duration: number;
  speakers: string[];
};

async function load(storage: Storage): Promise<Session[]> {
  try {
    return JSON.parse(new TextDecoder().decode(await storage.fs.readFile(index)));
  } catch (error) {
    if ((error as { code?: string }).code === "ENOENT") return [];
    throw error;
  }
}

const sources: Sources = {
  library: async (_args, _store, storage) => {
    const sessions = await load(storage).catch(error => {
      // Exact validates replacement plans without opening the live archive.
      if (error?.code === "unsupported") return [];
      throw error;
    });
    return { sessions, next: sessions.reduce((highest, take) => Math.max(highest, Number(take.id)), 0) + 1 };
  },
  keepTake: async ([id, path, duration, names], _store, storage) => {
    const sessions = await load(storage);
    const speakers = names.map((name, index) => name.trim() || `Speaker ${index + 1}`);
    const take = { id, title: "Untitled Recording", path, duration, speakers };
    const bytes = new TextEncoder().encode(JSON.stringify([take, ...sessions.filter(take => take.id !== id)]));
    await storage.fs.atomicWriteFile(index, bytes);
    return { ok: true };
  },
  removeTake: async ([path], _store, storage) => {
    await storage.fs.rm(path);
    return { ok: true };
  },
};

export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
