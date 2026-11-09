use std::{
    cell::Cell,
    fs, io,
    path::{Path, PathBuf},
    sync::LazyLock,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use rune::{Easing, Live, Player, PlayerState, Recorder, RecorderState, TextEdit, Tx, Waker};
use serde::{Deserialize, Serialize};

use crate::design::VAPOR;

// Recording dot storyboard. Repeat both legs while the recording header is visible.
// 0 ms       98% scale
// 2,000 ms  102% scale, Vapor breathe curve
// 4,000 ms   98% scale, same curve reversed
const DOT_REST: f32 = 1.0;
const DOT_TRAVEL: f32 = 0.02;
const ANIMATION_FRAME: Duration = Duration::from_millis(16);
static BREATHE: LazyLock<Easing> = LazyLock::new(|| VAPOR.motion.easing("breathe"));
const PLAYBACK_TICK: Duration = Duration::from_millis(100);

pub struct State {
    pub page: Page,
    pub sessions: Vec<Session>,
    pub search: TextEdit,
    pub error: Option<String>,
    pub dot_scale: Live<f32>,
    pub reduced_motion: Cell<bool>,
    folder: PathBuf,
    scratch: bool,
    pub(crate) waker: Option<Waker>,
}

pub enum Page {
    Timeline,
    Recording(Box<Draft>),
    Detail(Playback),
}

pub struct Draft {
    folder: PathBuf,
    recorder: Recorder,
    take: Option<rune::Recording>,
    start_clock: f64,
    pub status: RecorderState,
    pub elapsed: u64,
    pub expanded: bool,
    pub count: Option<usize>,
    pub names: [String; 4],
    pub modal: Option<RecordingModal>,
    pub name_edit: TextEdit,
}

#[derive(Clone, Copy)]
pub enum RecordingModal {
    Discard,
    Name(usize),
}

pub struct Playback {
    pub session: Session,
    player: Player,
    pub playing: bool,
    pub progress: f32,
    pub elapsed: u64,
}

#[derive(Clone, Deserialize, Serialize)]
pub struct Session {
    pub id: String,
    pub title: String,
    pub duration: f64,
    pub speakers: Vec<String>,
    pub audio: String,
}

impl State {
    pub fn new() -> Self {
        let scratch = rune::is_headless() && std::env::var_os("VAPOR_RUNE_DATA_DIR").is_none();
        let (folder, error) = storage_folder(scratch)
            .map(|folder| (folder, None))
            .unwrap_or_else(|error| (PathBuf::new(), Some(error.to_string())));
        let mut sessions = Vec::new();
        if let Ok(entries) = fs::read_dir(&folder) {
            for entry in entries.flatten() {
                if let Some(session) = read_session(&entry.path()) {
                    sessions.push(session);
                }
            }
            sessions.sort_by(|a, b| b.id.cmp(&a.id));
        }
        Self {
            page: Page::Timeline,
            sessions,
            search: TextEdit::default(),
            error,
            dot_scale: Live::new(DOT_REST),
            reduced_motion: Cell::new(false),
            folder,
            scratch,
            waker: None,
        }
    }

    pub fn start(&mut self, tx: &mut Tx) {
        if self.folder.as_os_str().is_empty() {
            return;
        }
        let result = (|| {
            fs::create_dir_all(&self.folder)?;
            let stamp = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default();
            // Headless IDs and ordering are repeatable, including when the directory is reused.
            let stamp = if rune::is_headless() {
                0
            } else {
                stamp.as_nanos()
            };
            for suffix in 0.. {
                let path = self
                    .folder
                    .join(format!("recording-{stamp:020}-{suffix:06}"));
                match fs::create_dir(&path) {
                    Ok(()) => return Ok(path),
                    Err(error) if error.kind() == io::ErrorKind::AlreadyExists => continue,
                    Err(error) => return Err(error),
                }
            }
            unreachable!()
        })();
        let folder = match result {
            Ok(folder) => folder,
            Err(error) => {
                self.error = Some(format!("Couldn’t start recording. {error}"));
                return;
            }
        };
        let recorder = Recorder::to_file(folder.join("audio.m4a"));
        if let Some(waker) = &self.waker {
            recorder.set_waker(waker.clone());
        }
        recorder.start();
        let status = recorder.state();
        self.error = None;
        self.page = Page::Recording(Box::new(Draft {
            folder,
            recorder,
            take: None,
            start_clock: tx.clock(),
            status,
            elapsed: 0,
            expanded: false,
            count: None,
            names: Default::default(),
            modal: None,
            name_edit: TextEdit::default(),
        }));
        tx.blur();
        tx.wake_after(ANIMATION_FRAME);
    }

    pub fn back(&mut self) {
        match &mut self.page {
            Page::Recording(draft)
                if draft.can_save() || draft.status == RecorderState::Starting =>
            {
                draft.modal = Some(RecordingModal::Discard);
                return;
            }
            Page::Recording(_) => return self.discard(),
            Page::Detail(playback) => playback.player.pause(),
            Page::Timeline => return,
        }
        self.page = Page::Timeline;
        self.error = None;
    }

    pub fn discard(&mut self) {
        if let Page::Recording(draft) = &self.page {
            draft.recorder.cancel();
            if let Err(error) = fs::remove_dir_all(&draft.folder)
                && error.kind() != io::ErrorKind::NotFound
            {
                self.error = Some(format!("Couldn’t discard recording. {error}"));
                return;
            }
            self.page = Page::Timeline;
            self.error = None;
        }
    }

    pub fn save(&mut self) {
        let Page::Recording(draft) = &mut self.page else {
            return;
        };
        let Some(count) = draft.count.filter(|_| draft.can_save()) else {
            return;
        };
        match draft.save(count) {
            Ok(session) => {
                self.sessions.insert(0, session);
                self.search = TextEdit::default();
                self.page = Page::Timeline;
                self.error = None;
            }
            Err(error) => self.error = Some(error),
        }
    }

    pub fn open(&mut self, id: &str) {
        let Some(session) = self
            .sessions
            .iter()
            .find(|session| session.id == id)
            .cloned()
        else {
            return;
        };
        let player = Player::audio(self.folder.join(&session.id).join(&session.audio));
        if let Some(waker) = &self.waker {
            player.set_waker(waker.clone());
        }
        player.preload();
        self.error = None;
        self.page = Page::Detail(Playback {
            session,
            player,
            playing: false,
            progress: 0.0,
            elapsed: 0,
        });
    }

    pub fn close(&mut self) {
        match &mut self.page {
            Page::Recording(draft) if draft.take.is_none() && draft.can_save() => {
                match draft.recorder.stop() {
                    Ok(take) => draft.take = Some(take),
                    Err(error) => self.error = Some(error),
                }
            }
            Page::Recording(draft) if draft.status == RecorderState::Starting => self.discard(),
            Page::Detail(playback) => playback.player.pause(),
            _ => {}
        }
    }

    pub fn poll(&mut self, tx: &mut Tx) -> bool {
        let mut changed = false;
        match &mut self.page {
            Page::Recording(draft) => {
                let status = draft.recorder.state();
                let elapsed = draft.recorder.elapsed().floor() as u64;
                changed = status != draft.status || elapsed != draft.elapsed;
                draft.status = status;
                draft.elapsed = elapsed;
                if self.reduced_motion.get() {
                    self.dot_scale.set(DOT_REST);
                    if draft.status == RecorderState::Recording {
                        tx.wake_after(Duration::from_secs(1));
                    }
                } else {
                    let leg = VAPOR.motion.seconds("breathe");
                    let phase = ((tx.clock() - draft.start_clock) / leg).rem_euclid(2.0);
                    let progress = BREATHE.eval((1.0 - (1.0 - phase).abs()) as f32);
                    self.dot_scale
                        .set(DOT_REST + DOT_TRAVEL * (2.0 * progress - 1.0));
                    tx.wake_after(ANIMATION_FRAME);
                }
            }
            Page::Detail(playback) => {
                let playing = playback.player.is_playing();
                let time = playback.player.time();
                let elapsed = time.floor() as u64;
                let progress = (time / playback.session.duration.max(0.01)).clamp(0.0, 1.0) as f32;
                changed = playing != playback.playing
                    || elapsed != playback.elapsed
                    || progress != playback.progress;
                playback.playing = playing;
                playback.elapsed = elapsed;
                playback.progress = progress;
                if let PlayerState::Failed(message) = playback.player.state() {
                    let error = Some(format!("Couldn’t play recording. {message}"));
                    changed |= self.error != error;
                    self.error = error;
                }
                if playing {
                    tx.wake_after(PLAYBACK_TICK);
                }
            }
            Page::Timeline => {}
        }
        changed
    }
}

impl Drop for State {
    fn drop(&mut self) {
        if let Page::Recording(draft) = &self.page {
            // Leave the recorded file in its draft directory if the window closes mid-take.
            let _ = draft.recorder.stop();
        }
        if self.scratch && !self.folder.as_os_str().is_empty() {
            let _ = fs::remove_dir_all(&self.folder);
        }
    }
}

impl Draft {
    pub fn can_save(&self) -> bool {
        self.take.is_some()
            || matches!(
                self.status,
                RecorderState::Recording | RecorderState::Paused | RecorderState::Interrupted(_)
            )
    }

    pub fn toggle_pause(&self) {
        if self.status == RecorderState::Paused {
            self.recorder.resume();
        } else if self.status == RecorderState::Recording {
            self.recorder.pause();
        }
    }

    pub fn save_name(&mut self) {
        if let Some(RecordingModal::Name(index)) = self.modal.take() {
            self.names[index] = self.name_edit.text.trim().to_owned();
        }
    }

    fn save(&mut self, count: usize) -> Result<Session, String> {
        if self.take.is_none() {
            self.take = Some(self.recorder.stop()?);
        }
        let take = self.take.as_ref().expect("recording was stopped");
        let session = Session {
            id: file_name(&self.folder)?,
            title: "Untitled Recording".into(),
            duration: take.duration,
            speakers: self.names[..count]
                .iter()
                .enumerate()
                .map(|(index, name)| {
                    if name.is_empty() {
                        format!("Speaker {}", index + 1)
                    } else {
                        name.clone()
                    }
                })
                .collect(),
            audio: file_name(&take.path)?,
        };
        let result = (|| {
            fs::write(
                self.folder.join("session.json.tmp"),
                serde_json::to_vec_pretty(&session)?,
            )?;
            fs::rename(
                self.folder.join("session.json.tmp"),
                self.folder.join("session.json"),
            )
        })();
        result.map_err(|error| format!("Couldn’t save recording. {error}"))?;
        Ok(session)
    }
}

impl Playback {
    pub fn toggle(&self, tx: &mut Tx) {
        if self.player.is_playing() {
            self.player.pause();
        } else {
            if self.progress >= 1.0 {
                self.player.seek(0.0);
            }
            self.player.play();
        }
        tx.wake_after(PLAYBACK_TICK);
    }
}

fn storage_folder(scratch: bool) -> io::Result<PathBuf> {
    if let Some(path) = std::env::var_os("VAPOR_RUNE_DATA_DIR") {
        let path = PathBuf::from(path);
        fs::create_dir_all(&path)?;
        return Ok(path);
    }
    if scratch {
        let time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("vapor-rune-{}-{time}", std::process::id()));
        fs::create_dir(&path)?;
        return Ok(path);
    }
    let home = std::env::var_os("HOME").ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "Vapor couldn’t find your home folder.",
        )
    })?;
    Ok(PathBuf::from(home).join("Library/Application Support/Vapor Rune"))
}

fn file_name(path: &Path) -> Result<String, String> {
    path.file_name()
        .and_then(|name| name.to_str())
        .map(str::to_owned)
        .ok_or_else(|| "Invalid recording filename".into())
}

fn read_session(folder: &Path) -> Option<Session> {
    let bytes = fs::read(folder.join("session.json")).ok()?;
    let session: Session = serde_json::from_slice(&bytes).ok()?;
    if session.id != file_name(folder).ok()?
        || !matches!(session.audio.as_str(), "audio.m4a" | "audio.wav")
        || !folder.join(&session.audio).is_file()
    {
        return None;
    }
    Some(session)
}
