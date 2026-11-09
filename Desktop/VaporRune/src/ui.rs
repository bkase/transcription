use rune::{
    Color, Cx, El, RecorderState, ScrollSpec, Spring, SpringPair, Transition, col, el, row,
    text_input,
};

use crate::{
    design::{VAPOR, button, circle, color, font, label, rule},
    state::{Draft, Page, Playback, RecordingModal, Session, State},
    symbols::{Symbol, Weight, symbol},
};

// The recording sheet rises into the window. The speaker card changes height
// over 250 ms. Cards and the player use the Vapor scale/blur/fade entrance.
const SHEET_DURATION: f32 = 0.4;
const SPEAKER_CARD_DURATION: f32 = 0.25;
const CARD_STAGGER: f32 = 0.05;
const NAV_TOP: f32 = 56.0;

const BACK: Symbol = Symbol::new("chevron.left", 20, Weight::Light);
const CHEVRON: Symbol = Symbol::new("chevron.right", 12, Weight::Regular);
const CHEVRON_UP: Symbol = Symbol::new("chevron.up", 14, Weight::Regular);
const CHEVRON_DOWN: Symbol = Symbol::new("chevron.down", 14, Weight::Regular);
const PLAY: Symbol = Symbol::new("play.fill", 14, Weight::Regular);
const PAUSE: Symbol = Symbol::new("pause", 14, Weight::Regular);
const PLAY_PLAYER: Symbol = Symbol::new("play.fill", 14, Weight::Medium);
const PAUSE_PLAYER: Symbol = Symbol::new("pause", 14, Weight::Medium);
const PEOPLE: Symbol = Symbol::new("person.2", 16, Weight::Regular);
const MIC: Symbol = Symbol::new("mic", 48, Weight::Light);
const SEARCH: Symbol = Symbol::new("magnifyingglass", 16, Weight::Light);

pub fn view(s: &State, cx: &mut Cx<State>) -> El {
    s.reduced_motion.set(cx.is_reduced_motion());
    let page = match &s.page {
        Page::Timeline => timeline(s),
        Page::Recording(draft) if draft.modal.is_some() => recording(s, draft).inert(),
        Page::Recording(draft) => recording(s, draft),
        Page::Detail(playback) => detail(s, playback),
    };
    let mut root = el()
        .w_full()
        .h_full()
        .fill(color("mist"))
        .clip_rounded(0.0)
        .child(page.pin(Some(0.0), Some(0.0), Some(0.0), Some(0.0)));
    if let Page::Recording(draft) = &s.page
        && let Some(modal) = draft.modal
    {
        root = root.child(recording_modal(draft, modal));
    }
    root
}

fn timeline(s: &State) -> El {
    let sp = &VAPOR.spacing;
    let query = s.search.text.trim().to_lowercase();
    let mut sessions = col().w_full().gap(sp.sm).px(sp.lg).pt(sp.lg).pb(120.0);
    let mut index = 0;
    for session in &s.sessions {
        if !query.is_empty()
            && !session.title.to_lowercase().contains(&query)
            && !session
                .speakers
                .iter()
                .any(|name| name.to_lowercase().contains(&query))
        {
            continue;
        }
        if index == 0 {
            let heading = if query.is_empty() {
                "RECORDINGS"
            } else {
                "RESULTS"
            };
            sessions = sessions.child(label(heading, 12.0, 500.0, 2.0, "textTertiary"));
        }
        sessions = sessions.child(session_card(session, index));
        index += 1;
    }
    if index == 0 {
        let empty = if query.is_empty() {
            col()
                .w_full()
                .center()
                .gap(sp.md)
                .child(el().size(60.0, 60.0).center().child(symbol(MIC, "sky")))
                .child(label("Ready to record", 20.0, 300.0, 0.0, "textPrimary"))
                .child(
                    col()
                        .center()
                        .gap(4.0)
                        .child(label(
                            "Tap the button below to start",
                            14.0,
                            300.0,
                            0.0,
                            "textTertiary",
                        ))
                        .child(label(
                            "your first recording.",
                            14.0,
                            300.0,
                            0.0,
                            "textTertiary",
                        )),
                )
        } else {
            row().w_full().center().pt(sp.xl).child(label(
                "No results found",
                16.0,
                300.0,
                0.0,
                "textSecondary",
            ))
        };
        sessions = sessions.child(empty);
    }

    let header = col()
        .w_full()
        .pt(NAV_TOP)
        .px(sp.lg)
        .pb(sp.md)
        .gap(sp.xs)
        .child(label("ARCHIVE", 11.0, 300.0, 2.0, "textTertiary"))
        .child(label("Timeline", 28.0, 200.0, -0.5, "textPrimary"));
    let search = row()
        .w_full()
        .h(40.0)
        .items_center()
        .px(sp.md)
        .gap(sp.sm)
        .radius(12.0)
        .fill(color("cloud").alpha(0.7))
        .border(1.0, color("haze"))
        .child(symbol(SEARCH, "textTertiary"))
        .child(
            text_input(&s.search, font(14.0, 300.0, 0.0))
                .key("search")
                .label("Search recordings")
                .grow(1.0)
                .placeholder("Search recordings...", color("textTertiary"))
                .color(color("textPrimary"))
                .on_edit(|s: &mut State| &mut s.search),
        );
    let record = button(
        "startRecordingButton",
        "Start Recording",
        circle(72.0, color("cloud"))
            .center()
            .border(1.0, color("fog"))
            .shadow(4.0, 32.0, Color::BLACK.alpha(0.06))
            .child(circle(12.0, color("recording").alpha(0.6))),
    )
    .on_press_tx(State::start);

    col()
        .key("timeline")
        .transition(sheet(false))
        .child(header)
        .child(el().w_full().px(sp.lg).child(search))
        .child(error_banner(s))
        .child(
            col()
                .w_full()
                .min_h(0.0)
                .grow(1.0)
                .scroll(ScrollSpec {
                    stick_bottom: false,
                })
                .child(sessions),
        )
        .child(
            row()
                .w_full()
                .center()
                .pin(Some(0.0), None, Some(0.0), Some(sp.lg))
                .child(record),
        )
}

fn session_card(session: &Session, index: usize) -> El {
    let id = session.id.clone();
    let card = col()
        .w_full()
        .gap(VAPOR.spacing.sm)
        .py(20.0)
        .px(VAPOR.spacing.md)
        .radius(VAPOR.radii.md)
        .hover(color("cloud"))
        .child(
            row()
                .w_full()
                .justify_between()
                .gap(VAPOR.spacing.sm)
                .child(label(&session.title, 18.0, 300.0, -0.2, "textPrimary"))
                .child(label(
                    clock(session.duration as u64, false),
                    10.0,
                    400.0,
                    0.5,
                    "textTertiary",
                )),
        )
        .child(
            label(
                session.speakers.join(", "),
                14.0,
                300.0,
                0.0,
                "textSecondary",
            )
            .wrap(),
        );
    button(format!("session-{id}"), &session.title, card)
        .transition(appear())
        .enter_delay(CARD_STAGGER * index as f32)
        .on_press(move |s: &mut State| s.open(&id))
}

fn nav(include_avatar: bool) -> El {
    let sp = &VAPOR.spacing;
    let back = row()
        .items_center()
        .gap(sp.xs)
        .py(sp.sm)
        .pr(sp.sm)
        .child(el().w(12.0).center().child(symbol(BACK, "textSecondary")))
        .child(label("Back", 14.0, 300.0, 0.0, "textSecondary"));
    let mut bar = row()
        .w_full()
        .items_center()
        .justify_between()
        .pt(NAV_TOP)
        .px(sp.lg)
        .pb(if include_avatar { sp.md } else { sp.sm })
        .child(button("backButton", "Back", back).on_press(State::back));
    if include_avatar {
        bar = bar.child(circle(44.0, color("haze")).border(1.0, color("fog")));
    }
    bar
}

fn recording(s: &State, draft: &Draft) -> El {
    let paused = draft.status == RecorderState::Paused;
    let content = match &draft.status {
        RecorderState::Starting => label("Starting...", 24.0, 200.0, 1.0, "textTertiary"),
        RecorderState::Paused => label("Paused", 24.0, 200.0, 1.0, "textTertiary"),
        RecorderState::Failed(message) | RecorderState::Interrupted(message) => {
            label(message, 16.0, 400.0, 0.0, "recording").wrap()
        }
        RecorderState::Stopped => label("Recording stopped", 24.0, 200.0, 1.0, "textTertiary"),
        _ => label("Recording audio...", 20.0, 200.0, 1.0, "textSecondary"),
    };
    col()
        .key("recording")
        .fill(color("mist"))
        .transition(sheet(true))
        .child(nav(true))
        .child(recording_header(s, draft, paused))
        .child(error_banner(s))
        .child(
            col()
                .key("recording-content")
                .w_full()
                .min_h(0.0)
                .grow(1.0)
                .center()
                .px(VAPOR.spacing.lg)
                .child(content),
        )
        .child(speaker_setup(draft))
}

fn recording_header(s: &State, draft: &Draft, paused: bool) -> El {
    let (status, ink, glyph, key, action, opacity) = if paused {
        ("PAUSED", "sky", PLAY, "resumeButton", "Resume", 0.5)
    } else {
        ("RECORDING", "recording", PAUSE, "pauseButton", "Pause", 0.8)
    };
    let mut dot = circle(8.0, color(ink)).key("recordingDot");
    if !s.reduced_motion.get() {
        dot = dot.live_scale(&s.dot_scale);
    }
    let mut controls = row().items_center().gap(12.0);
    if matches!(
        draft.status,
        RecorderState::Recording | RecorderState::Paused
    ) {
        controls = controls.child(
            button(key, action, round_control(32.0, glyph, true)).on_press_tx(
                |s: &mut State, tx| {
                    if let Page::Recording(draft) = &mut s.page {
                        draft.toggle_pause();
                        tx.wake_after(std::time::Duration::from_millis(16));
                    }
                },
            ),
        );
    }
    controls = controls.child(
        label(clock(draft.elapsed, true), 20.0, 300.0, 2.0, "textPrimary")
            .key("recordingTimer")
            .opacity(opacity),
    );
    col()
        .w_full()
        .child(
            row()
                .w_full()
                .h(64.0)
                .px(VAPOR.spacing.lg)
                .justify_between()
                .items_center()
                .child(
                    row()
                        .items_center()
                        .gap(12.0)
                        .child(dot)
                        .child(label(status, 14.0, 300.0, 2.0, ink).key("recordingStatus")),
                )
                .child(controls),
        )
        .child(rule(color("fog").alpha(0.5)))
}

fn round_control(size: f32, glyph: Symbol, border: bool) -> El {
    let mut button = circle(size, color("haze"))
        .center()
        .child(symbol(glyph, "textSecondary"));
    if border {
        button = button.border(1.0, color("fog"));
    } else {
        button = button.shadow(2.0, 16.0, Color::BLACK.alpha(0.04));
    }
    button
}

fn speaker_setup(draft: &Draft) -> El {
    let sp = &VAPOR.spacing;
    let title = if draft.expanded {
        "Who's speaking?"
    } else {
        "Assign speakers & finish"
    };
    let mut heading = row().w_full().items_center().gap(sp.sm);
    if !draft.expanded {
        heading = heading.child(symbol(PEOPLE, "textSecondary"));
    }
    heading = heading
        .child(label(
            title,
            if draft.expanded { 18.0 } else { 15.0 },
            400.0,
            0.0,
            "textPrimary",
        ))
        .child(el().grow(1.0))
        .child(symbol(
            if draft.expanded {
                CHEVRON_DOWN
            } else {
                CHEVRON_UP
            },
            "textTertiary",
        ));
    let mut card = col()
        .w_full()
        .gap(if draft.expanded { sp.md } else { 12.0 })
        .px(sp.lg)
        .pb(sp.lg)
        .pt(if draft.expanded { sp.lg } else { sp.md })
        .child(
            button("speakerSetupToggle", title, heading).on_press_tx(|s: &mut State, tx| {
                if let Page::Recording(draft) = &mut s.page {
                    draft.expanded = !draft.expanded;
                    tx.motion(Spring::new(SPEAKER_CARD_DURATION, 0.0));
                }
            }),
        );
    if draft.expanded {
        card = card
            .child(label(
                "Pick a count, then tap to name them.",
                13.0,
                300.0,
                0.0,
                "textSecondary",
            ))
            .child(speaker_counts(draft.count));
        if let Some(count) = draft.count {
            let mut names = col().w_full().gap(10.0).child(label(
                "Speakers",
                12.0,
                400.0,
                0.0,
                "textSecondary",
            ));
            for index in 0..count {
                names = names.child(speaker_row(index, &draft.names[index]));
            }
            card = card.child(rule(color("fog"))).child(names);
        }
    }

    col()
        .key("speakerSetup")
        .w_full()
        .fill(color("cloud"))
        .child(rule(color("fog")))
        .child(card.child(save_button(
            draft.expanded && draft.count.is_some() && draft.can_save(),
        )))
}

fn speaker_counts(selected: Option<usize>) -> El {
    let mut counts = row().w_full().gap(VAPOR.spacing.sm);
    for (index, title) in ["1", "2", "3", "4+"].into_iter().enumerate() {
        let count = index + 1;
        let is_selected = Some(count) == selected;
        let (fill, ink, weight) = if is_selected {
            ("sky", "cloud", 500.0)
        } else {
            ("haze", "textSecondary", 400.0)
        };
        let mut pill = el()
            .grow(1.0)
            .h(40.0)
            .center()
            .radius(12.0)
            .fill(color(fill))
            .child(label(title, 15.0, weight, 0.0, ink));
        if !is_selected {
            pill = pill.border(1.0, color("fog"));
        }
        counts = counts.child(
            button(
                format!("speakerCount{count}"),
                format!("{title} speakers"),
                pill,
            )
            .checked(is_selected)
            .on_press_tx(move |s: &mut State, tx| {
                if let Page::Recording(draft) = &mut s.page {
                    draft.count = Some(count);
                    tx.instant();
                }
            }),
        );
    }
    counts
}

fn speaker_row(index: usize, name: &str) -> El {
    let title = if name.is_empty() {
        format!("Speaker {}", index + 1)
    } else {
        name.to_owned()
    };
    let ink = ["sky", "lavender", "deep", "dusk"][index];
    let line = row()
        .w_full()
        .h(38.0)
        .px(12.0)
        .items_center()
        .gap(VAPOR.spacing.sm)
        .radius(10.0)
        .fill(color("haze"))
        .border(1.0, color("fog"))
        .child(circle(8.0, color(ink)))
        .child(label(&title, 13.0, 300.0, 0.0, "textTertiary").truncate())
        .child(el().grow(1.0))
        .child(symbol(CHEVRON, "textTertiary"));
    button(format!("speakerRow{index}"), title, line).on_press_tx(move |s: &mut State, tx| {
        if let Page::Recording(draft) = &mut s.page {
            draft.name_edit = rune::TextEdit::new(draft.names[index].clone());
            draft.modal = Some(RecordingModal::Name(index));
            tx.focus("speakerName", false);
        }
    })
}

fn save_button(enabled: bool) -> El {
    let (fill, ink, opacity) = if enabled {
        ("recording", "cloud", 1.0)
    } else {
        ("fog", "textTertiary", 0.5)
    };
    let bar = row()
        .w_full()
        .h(44.0)
        .center()
        .gap(VAPOR.spacing.sm)
        .radius(12.0)
        .fill(color(fill))
        .opacity(opacity)
        .child(el().size(12.0, 12.0).radius(2.0).fill(color(ink)))
        .child(label("Stop & Save", 14.0, 500.0, 0.0, ink));
    if enabled {
        button("stopAndSaveButton", "Stop & Save", bar).on_press(State::save)
    } else {
        bar.key("stopAndSaveButton")
            .role("button")
            .label("Stop & Save")
            .disabled(true)
    }
}

fn recording_modal(draft: &Draft, modal: RecordingModal) -> El {
    let sp = &VAPOR.spacing;
    let (title, body, key, action, ink, apply): (_, _, _, _, _, fn(&mut State)) = match modal {
        RecordingModal::Discard => (
            "Discard Recording?",
            label(
                "This will permanently delete the recording and all transcript data.",
                14.0,
                300.0,
                0.0,
                "textSecondary",
            )
            .wrap(),
            "discardRecording",
            "Discard",
            "recording",
            State::discard,
        ),
        RecordingModal::Name(_) => (
            "Name speaker",
            text_input(&draft.name_edit, font(14.0, 400.0, 0.0))
                .key("speakerName")
                .label("Speaker name")
                .w_full()
                .h(40.0)
                .px(sp.sm)
                .radius(12.0)
                .fill(color("haze"))
                .color(color("textPrimary"))
                .placeholder("Speaker name", color("textTertiary"))
                .on_edit(|s: &mut State| match &mut s.page {
                    Page::Recording(draft) => &mut draft.name_edit,
                    _ => unreachable!("name field is only mounted on the recording screen"),
                })
                .on_submit(|s: &mut State, tx| {
                    apply_name(s);
                    tx.blur();
                }),
            "saveSpeaker",
            "Save",
            "deep",
            apply_name,
        ),
    };
    let cancel = button(
        "cancelModal",
        "Cancel",
        label("Cancel", 14.0, 500.0, 0.0, "textSecondary").padding(sp.sm),
    )
    .on_press(close_modal);
    let primary = button(
        key,
        action,
        label(action, 14.0, 500.0, 0.0, ink).padding(sp.sm),
    )
    .on_press(apply);
    let card = col()
        .key("recordingDialog")
        .role("dialog")
        .label(title)
        .w(300.0)
        .padding(sp.lg)
        .gap(sp.md)
        .radius(VAPOR.radii.md)
        .fill(color("cloud"))
        .shadow(8.0, 48.0, Color::BLACK.alpha(0.12))
        .child(label(title, 20.0, 400.0, 0.0, "textPrimary"))
        .child(body)
        .child(
            row()
                .w_full()
                .justify_end()
                .gap(sp.sm)
                .child(cancel)
                .child(primary),
        );
    el().key("modal")
        .pin(Some(0.0), Some(0.0), Some(0.0), Some(0.0))
        .center()
        .fill(Color::BLACK.alpha(0.1))
        .transition(Transition::opacity())
        .on_press(close_modal)
        .child(card.on_press(|_: &mut State| {}))
}

pub fn close_modal(s: &mut State) {
    if let Page::Recording(draft) = &mut s.page {
        draft.modal = None;
    }
}

fn apply_name(s: &mut State) {
    if let Page::Recording(draft) = &mut s.page {
        draft.save_name();
    }
}

fn detail(s: &State, playback: &Playback) -> El {
    let sp = &VAPOR.spacing;
    let session = &playback.session;
    let (action, glyph) = if playback.playing {
        ("Pause playback", PAUSE_PLAYER)
    } else {
        ("Play recording", PLAY_PLAYER)
    };
    let audio = row()
        .key("audioPlayer")
        .w_full()
        .items_center()
        .gap(sp.md)
        .py(10.0)
        .pl(12.0)
        .pr(16.0)
        .radius(VAPOR.radii.md)
        .fill(color("cloud").alpha(0.7))
        .border(1.0, color("cloud").alpha(0.25))
        .shadow(2.0, 32.0, Color::BLACK.alpha(0.04))
        .transition(appear())
        .child(
            button("playbackButton", action, round_control(36.0, glyph, false)).on_press_tx(
                |s: &mut State, tx| {
                    if let Page::Detail(playback) = &s.page {
                        playback.toggle(tx);
                    }
                },
            ),
        )
        .child(
            col()
                .grow(1.0)
                .gap(6.0)
                .child(label(&session.title, 13.0, 300.0, 0.0, "textPrimary"))
                .child(
                    el().key("playbackProgress")
                        .w_full()
                        .h(3.0)
                        .radius(2.0)
                        .fill(color("fog"))
                        .child(
                            el().w_frac(playback.progress)
                                .h_full()
                                .radius(2.0)
                                .fill(color("sky")),
                        ),
                ),
        )
        .child(
            label(
                clock(playback.elapsed, false),
                10.0,
                300.0,
                0.5,
                "textTertiary",
            )
            .key("playbackTime"),
        );

    col()
        .key("sessionDetail")
        .fill(color("mist"))
        .transition(sheet(false))
        .child(nav(false))
        .child(
            col()
                .w_full()
                .px(sp.lg)
                .pt(sp.md)
                .gap(sp.xs)
                .child(label(&session.title, 28.0, 200.0, -0.5, "textPrimary"))
                .child(label(
                    clock(session.duration as u64, false),
                    14.0,
                    300.0,
                    0.0,
                    "textSecondary",
                )),
        )
        .child(error_banner(s))
        .child(row().w_full().justify_center().pt(2.0 * sp.xl).child(label(
            "No transcript available",
            14.0,
            300.0,
            0.0,
            "textTertiary",
        )))
        .child(el().grow(1.0))
        .child(el().w_full().px(sp.lg).pb(sp.lg).child(audio))
}

fn error_banner(s: &State) -> El {
    match &s.error {
        Some(error) => label(error, 14.0, 400.0, 0.0, "recording")
            .wrap()
            .w_full()
            .px(VAPOR.spacing.lg)
            .py(VAPOR.spacing.sm),
        None => el(),
    }
}

fn sheet(vertical: bool) -> Transition {
    let distance = if vertical { (0.0, 48.0) } else { (50.0, 0.0) };
    let spring = Spring::new(SHEET_DURATION, 0.0);
    Transition::offset(distance.0, distance.1)
        .combined(Transition::opacity())
        .springs(SpringPair {
            enter: spring,
            exit: spring,
        })
}

fn appear() -> Transition {
    let spring = Spring::new(VAPOR.motion.seconds("normal") as f32, 0.0);
    Transition::blur(4.0)
        .combined(Transition::scale(0.98))
        .springs(SpringPair {
            enter: spring,
            exit: spring,
        })
}

fn clock(seconds: u64, pad_minutes: bool) -> String {
    if seconds >= 3600 {
        format!(
            "{}:{:02}:{:02}",
            seconds / 3600,
            seconds / 60 % 60,
            seconds % 60
        )
    } else if pad_minutes {
        format!("{:02}:{:02}", seconds / 60, seconds % 60)
    } else {
        format!("{}:{:02}", seconds / 60, seconds % 60)
    }
}
