const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const location_info = @import("location_info.zig");

const fonts = @import("fonts.zig");
const game = @import("game.zig");
const gui = @import("gui.zig");
const utils = @import("utils.zig");
const types = @import("types.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

pub fn main() anyerror!void {
    rl.initWindow(consts.screenWidth, consts.screenHeight, "BioMechanics: The Puzzles of Restoration");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    fonts.main_font = try rl.Font.initEx(
        fonts.Family.ArkPixel,
        fonts.Size.Medium,
        null,
    );
    defer rl.unloadFont(fonts.main_font);

    rl.drawFPS(0, 0);
    // rl.setExitKey(.null);
    rl.setTargetFPS(240);
    rg.setStyle(.default, .{ .default = .text_size }, fonts.Size.Medium);

    rg.setFont(fonts.main_font);

    // Textures unloading (assets are lazily loaded)
    defer assets.assetPool.deinitAll();
    defer assets.soundPool.deinitAll();
    defer assets.musicPool.deinitAll();

    // runtime data
    var startedCutscene = false;
    var startedEnding = false;
    var finishedAudio1 = false;

    //var finishedAudio2 = false;
    var startTime: ?f64 = null;
    const ending_speech = assets.endingSpeech.getOrLoad().sound;

    var tut_anim_timer: f32 = 0;
    var tutorial_watched_at_least_once: bool = false;
    var show_speedrun_timer: bool = false;
    var animFrames: i32 = 0;
    const tutorialAnim = try rl.loadImageAnim("resources/tutorial.gif", &animFrames);
    const tut_tex = try rl.loadTextureFromImage(tutorialAnim);
    var nextFrameDataOffset: usize = 0;
    var currentAnimFrame: i32 = 0;

    var game_start_time: f64 = 0;
    var game_end_time: f64 = 0;

    var currentScreen: types.Screen = .MainMenu;
    var current_text: *const []const u8 = &"";
    var timer_buffer: [32:0]u8 = undefined;

    var mousePos = rl.Vector2.zero();

    const info_anchor = rl.Vector2.init(190, 200);
    var text_view = gui.ScrollingTextView.init(
        info_anchor.x,
        info_anchor.y + 50,
        750,
        500,
        "",
        fonts.main_font,
    );

    var pois = [_]gui.PoiPin{
        gui.PoiPin.init(.SolarPanels, 0.75, 0.45, false),
        gui.PoiPin.init(.CarbonCapture, 0.44, 0.37, true),
        gui.PoiPin.init(.Nuclear, 0.60, 0.65, true),
    };

    const main_music = assets.main_music.getOrLoad();

    if (!rl.isMusicStreamPlaying(main_music)) {
        rl.playMusicStream(main_music);
    }
    rl.setMusicVolume(main_music, 0.375);

    // Main game loop
    while (!rl.windowShouldClose()) {
        // drawing stuff
        {
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(rl.Color.black);
            mousePos = rl.getMousePosition();

            switch (currentScreen) {
                .MainMenu => {
                    rl.updateMusicStream(main_music);
                    const anchor = rl.Vector2.init(@as(f32, @floatFromInt(rl.getScreenWidth())) / 2.0, 300);
                    gui.drawTextureCenteredAtPoint(0.8, 0.0, anchor, assets.gameLogo.getOrLoad());
                    if (gui.imgBtn(
                        1.0,
                        rl.Vector2.init(anchor.x, anchor.y + 175),
                        assets.playBtn.getOrLoad(),
                        assets.playBtnHover.getOrLoad(),
                        assets.playBtnPress.getOrLoad(),
                        mousePos,
                    )) {
                        currentScreen = .Info;
                    }
                },
                .Globe => {
                    rl.updateMusicStream(main_music);
                    gui.drawTextureCentered(8.435, 0, assets.spaceBg.getOrLoad());
                    gui.drawTextureCentered(8.0, 0, assets.globeTexture.getOrLoad());
                    var location: ?types.Location = null;
                    for (&pois) |*poi| {
                        switch (poi.render(mousePos)) {
                            .Pressed => {
                                location = poi.location;
                            },
                            .Hovered => {
                                const dat: [:0]const u8 = @ptrCast(poi.location.getInfo().name);
                                const bounds = rl.measureTextEx(fonts.main_font, dat, fonts.Size.Small, 0);
                                rl.drawRectangleRec(
                                    rl.Rectangle.init(
                                        mousePos.x - (bounds.x / 2) - consts.tooltip_padding,
                                        mousePos.y + 32,
                                        bounds.x + (2 * consts.tooltip_padding),
                                        bounds.y,
                                    ),
                                    rl.Color.black,
                                );

                                rl.drawTextEx(
                                    fonts.main_font,
                                    dat,
                                    rl.Vector2.init(mousePos.x - (bounds.x / 2), mousePos.y + 32),
                                    fonts.Size.Small,
                                    0,
                                    rl.Color.white,
                                );
                            },
                            else => {},
                        }
                    }
                    if (location) |loc| {
                        currentScreen = types.Screen{ .LocationInfo = loc };
                    }
                },
                .Play => |*place| {
                    rl.updateMusicStream(main_music);
                    gui.drawTextureCentered(0.8, 0, assets.playBg.getOrLoad());

                    const loc_real = place.location;
                    const loc_info = loc_real.getInfo();
                    if (gui.backBtn(mousePos)) {
                        currentScreen = .{ .ComponentInfo = place.location };
                        game.unloadLevel();
                        std.debug.print("Unloaded: {}\n", .{game.levelUnloaded()});
                    } else {
                        if (game.levelUnloaded() or rl.isKeyPressed(.r)) {
                            game.unloadLevel();
                            game.loadLevel(loc_info.levels[place.level]);
                            std.debug.print("Loaded: {s}\n", .{loc_info.levels[place.level].name});
                        }
                    }

                    if (game.loop()) {
                        if (place.level < loc_info.levels.len - 1) {
                            var location = location_info.location_data[@intFromEnum(place.location)];
                            location.levels[place.level].solved = true;
                            place.level += 1;
                            location.levels[place.level].locked = false;

                            game.loadLevel(loc_info.levels[place.level]);
                            std.debug.print("Loaded: {s} due to win\n", .{loc_info.levels[place.level].name});
                        } else {
                            currentScreen = .Globe;
                            game.unloadLevel();
                            for (&pois, 0..) |*poi, idx| {
                                std.debug.print("This location: {s}\n", .{loc_real.getInfo().name});
                                if (poi.location == loc_real) {
                                    poi.isCompleted = true;
                                    std.debug.print("Finished POI {s}\n", .{poi.location.getInfo().name});
                                    if (idx + 1 < pois.len) {
                                        pois[idx + 1].isLocked = false;
                                        std.debug.print("Unlocked next POI due to win\n", .{});
                                    } else {
                                        currentScreen = .Ending;
                                    }

                                    break;
                                }
                            }
                            // TODO: display area completion
                        }
                    }
                },
                .Info => {
                    const sound1 = assets.introductionSpeech1.getOrLoad().sound;
                    const sound2 = assets.introductionSpeech2.getOrLoad().sound;
                    // rendering bg
                    const asset = if (!finishedAudio1)
                        assets.desertCutscene.getOrLoad()
                    else
                        assets.labCutscene.getOrLoad();
                    asset.drawEx(
                        rl.Vector2.zero(),
                        0,
                        utils.renderSize().x / @as(f32, @floatFromInt(asset.width)),
                        rl.Color.white,
                    );

                    const bounds = rl.measureTextEx(
                        fonts.main_font,
                        @ptrCast(current_text.*),
                        fonts.Size.Medium,
                        0,
                    );

                    rl.drawRectangleRec(
                        rl.Rectangle.init(
                            utils.renderSize().x / 2 - (bounds.x / 2) - consts.tooltip_padding,
                            utils.renderSize().y / 2 - 100,
                            bounds.x + (2 * consts.tooltip_padding),
                            bounds.y,
                        ),
                        rl.Color.black,
                    );

                    rl.drawTextEx(
                        fonts.main_font,
                        @ptrCast(current_text.*),
                        utils.renderSize().scale(0.5).add(utils.v2(-(bounds.x / 2), -100)),
                        fonts.Size.Medium,
                        0,
                        rl.Color.white,
                    );

                    if (!startedCutscene) {
                        startTime = rl.getTime();
                        startedCutscene = true;

                        rl.playSound(sound1);
                        continue;
                    }
                    // time since audio started
                    const time_delta = rl.getTime() - startTime.?;

                    if (!finishedAudio1) {
                        switch (@as(u8, @intFromFloat(time_delta))) {
                            0...2 => current_text = &"Beginning in the second half of the 21st century,",
                            3...9 => current_text = &"a series of climate disasters made 38% of the land\nonce suitable for nurturing humanity unlivable.",
                            else => current_text = &"By 2075, for the first time in history since the black\ndeath, the global population decreased.",
                        }
                    } else {
                        switch (@as(u8, @intFromFloat(time_delta))) {
                            0...4 => current_text = &"In the following decades, the UN has redoubled its\nefforts to fight climate change.",
                            5...8 => current_text = &"At the heart of its campaign has been a new department,\nheaded by you,",
                            9...11 => current_text = &"for the development of technologies that work\nwith nature to rebuild the planet.",
                            12...18 => current_text = &"You stand on the edge of triumph, about to oversee\nthe completion of these machines to save your species,",
                            19...20 => current_text = &"which are 25 years in the making.",
                            else => current_text = &"Only a few problems remain to be solved before the biomechanics\nof the earth are put back into balance.",
                        }
                    }

                    // skipping w/ mouse
                    if (rl.isMouseButtonPressed(.left)) {
                        if (!finishedAudio1) {
                            rl.stopSound(sound1);
                            finishedAudio1 = true;
                            rl.playSound(sound2);
                            startTime = rl.getTime();
                        } else {
                            rl.stopSound(sound2);
                            currentScreen = .Tutorial;
                        }
                    }
                    if (!finishedAudio1 and time_delta > 16.5) {
                        finishedAudio1 = true;
                        rl.playSound(sound2);
                        startTime = rl.getTime();
                    }
                    if (finishedAudio1 and time_delta > 26.5) {
                        rl.stopSound(sound2);
                        currentScreen = .Tutorial;
                    }

                    // if (!(finishedAudio1 or rl.isSoundPlaying(sound1))) {
                    //     finishedAudio1 = true;
                    //     rl.playSound(sound2);
                    //     continue;
                    // }
                    // if (finishedAudio1 and !rl.isSoundPlaying(sound2)) {
                    //     finishedAudio2 = true;
                    // }
                    // std.debug.print("test: {}\n", .{rl.isSoundPlaying(sound1)});

                    // if (time_delta > 42.5) { // (finishedAudio1 and finishedAudio2) {
                    //     currentScreen = .Globe;
                    // }

                    //currentScreen = .Globe;
                },
                .Tutorial => {
                    const speed = 6;
                    tut_anim_timer += rl.getFrameTime();

                    while (tut_anim_timer >= speed) {
                        if (currentAnimFrame + 1 == animFrames) {
                            tutorial_watched_at_least_once = true;
                        }
                        currentAnimFrame = @rem(currentAnimFrame + 1, animFrames);
                        nextFrameDataOffset = 4 * @as(u32, @intCast(tutorialAnim.width * tutorialAnim.height * currentAnimFrame));
                        rl.updateTexture(tut_tex, @ptrFromInt(@as(usize, @intFromPtr(tutorialAnim.data)) + nextFrameDataOffset));
                        tut_anim_timer = 0.0;
                    }
                    rl.drawTextureEx(
                        tut_tex,
                        rl.Vector2.zero(),
                        0,
                        3.375,
                        rl.Color.white,
                    );
                    if (tutorial_watched_at_least_once or rl.isKeyDown(.right_bracket)) {
                        rl.drawTextEx(
                            fonts.main_font,
                            "Click to exit tutorial",
                            rl.Vector2.init(10, @floatFromInt(rl.getRenderHeight() - 64)),
                            fonts.Size.Medium,
                            0,
                            rl.Color.white,
                        );
                        if (rl.isMouseButtonPressed(.left)) {
                            rl.unloadImage(tutorialAnim);

                            game_start_time = rl.getTime();
                            currentScreen = .Globe;
                        }
                    }
                },
                .LocationInfo => |*location| {
                    rl.updateMusicStream(main_music);
                    if (gui.backBtn(mousePos)) {
                        currentScreen = .Globe;
                    }
                    const info = location.getInfo();
                    const anchor = rl.Vector2.init(150, 75);
                    const tex = info.image_name.getOrLoad();
                    const scale_factor = (utils.renderSize().x - 2 * anchor.x) / @as(f32, @floatFromInt(tex.width)) * info.image_scale;

                    rl.drawTextEx(
                        fonts.main_font,
                        std.mem.concatWithSentinel(
                            std.heap.c_allocator,
                            u8,
                            &.{ info.name, " Repair" },
                            0,
                        ) catch |err| blk: {
                            std.log.err("err: {}", .{err});
                            break :blk @as([:0]const u8, @ptrCast(info.name));
                        },
                        anchor,
                        fonts.Size.Medium,
                        0,
                        rl.Color.light_gray,
                    );
                    const text_info_anchor = anchor.add(utils.yv(fonts.Size.Medium + 5));
                    rl.drawTextEx(
                        fonts.main_font,
                        @ptrCast(info.info),
                        text_info_anchor,
                        fonts.Size.Small,
                        1,
                        rl.Color.white,
                    );
                    const text_size = rl.measureTextEx(
                        fonts.main_font,
                        @ptrCast(info.info),
                        fonts.Size.Small,
                        1.0,
                    );
                    const tex_size = utils.texSize(tex).scale(scale_factor);
                    tex.drawEx(
                        rl.Vector2.init(
                            utils.renderSize().scale(0.5).x - tex_size.scale(0.5).x,
                            text_info_anchor.y + text_size.y + 5,
                        ),
                        0.0,
                        scale_factor,
                        rl.Color.white,
                    );
                    const after_tex = text_info_anchor.add(utils.yv(tex_size.y + text_size.y + 10));
                    if (gui.imgBtn(
                        3.0,
                        rl.Vector2.init(utils.renderSize().scale(0.5).x, after_tex.y + 50),
                        assets.repairBtn.getOrLoad(),
                        assets.repairBtnHover.getOrLoad(),
                        assets.repairBtnPress.getOrLoad(),
                        mousePos,
                    )) {
                        currentScreen = .{ .ComponentInfo = location.* };
                    }

                    text_view.setText(info.info);
                },
                .ComponentInfo => |*location| {
                    rl.updateMusicStream(main_music);
                    if (gui.backBtn(mousePos)) {
                        currentScreen = .{ .LocationInfo = location.* };
                    }
                    const height = 250;
                    const main_anchor = rl.Vector2.init(100, 100);
                    rl.drawTextEx(
                        fonts.main_font,
                        std.mem.concatWithSentinel(
                            std.heap.c_allocator,
                            u8,
                            &.{ location.getInfo().name, " Repair" },
                            0,
                        ) catch |err| blk: {
                            std.debug.print("err: {}", .{err});
                            break :blk @as([:0]const u8, @ptrCast(location.getInfo().name));
                        },
                        main_anchor,
                        fonts.Size.Medium,
                        1.0,
                        rl.Color.white,
                    );

                    for (location.getInfo().levels, 0..) |lev, ix| {
                        const anchor = main_anchor.add(utils.yv(50 + @as(f32, @floatFromInt((height + 20) * ix))));
                        const bounds = utils.withWH(anchor, utils.renderSize().x * 0.8, height);
                        rl.drawRectangleLinesEx(
                            bounds,
                            5,
                            rl.Color.white,
                        );
                        rl.drawTextEx(
                            fonts.main_font,
                            @ptrCast(lev.name),
                            anchor.addValue(20),
                            fonts.Size.Medium,
                            1.0,
                            rl.Color.white,
                        );
                        rl.drawTextEx(
                            fonts.main_font,
                            @ptrCast(lev.info),
                            anchor.add(utils.v2(8, fonts.Size.Medium + 10)),
                            fonts.Size.Small,
                            1.0,
                            rl.Color.white,
                        );
                        const img_anchor = anchor.add(utils.v2(750, height / 2));
                        const tex = lev.texture.getOrLoad();

                        gui.drawTextureCenteredAtPoint(
                            0.4,
                            0,
                            img_anchor,
                            tex,
                        );

                        if (lev.locked) {
                            gui.drawTextureCenteredAtPoint(
                                2.0,
                                0,
                                img_anchor,
                                assets.lock.getOrLoad(),
                            );
                            // assets.lock.getOrLoad().drawEx(
                            //     img_anchor
                            //         .add(utils.texSize(tex).scale(0.4).scale(0.5))
                            //         .subtract(utils
                            //         .texSize(assets.lock.getOrLoad())
                            //         .scale(0.5)),
                            //     0.0,
                            //     2.0,
                            //     rl.Color.white,
                            // );
                        }
                        if (lev.solved)
                            assets.checkmark.getOrLoad().drawEx(img_anchor, 0.0, 1.0, rl.Color.white);
                        if (!lev.locked and !lev.solved and rl.checkCollisionPointRec(mousePos, bounds) and rl.isMouseButtonPressed(.left)) {
                            std.debug.print("request {s}... and setting loc={s}\n", .{ lev.name, location.getInfo().name });

                            game.unloadLevel();
                            currentScreen = .{
                                .Play = .{
                                    .level = @intCast(ix),
                                    .location = location.*,
                                },
                            };
                        }
                    }
                },
                .Ending => {
                    // rendering bg
                    const asset = assets.endingCutscene.getOrLoad();
                    asset.drawEx(
                        rl.Vector2.zero(),
                        0,
                        utils.renderSize().x / @as(f32, @floatFromInt(asset.width)),
                        rl.Color.white,
                    );

                    const bounds = rl.measureTextEx(
                        fonts.main_font,
                        @ptrCast(current_text.*),
                        fonts.Size.Medium,
                        0,
                    );

                    rl.drawRectangleRec(
                        rl.Rectangle.init(
                            utils.renderSize().x / 2 - (bounds.x / 2) - consts.tooltip_padding,
                            utils.renderSize().y / 2 - 100,
                            bounds.x + (2 * consts.tooltip_padding),
                            bounds.y,
                        ),
                        rl.Color.black,
                    );

                    rl.drawTextEx(
                        fonts.main_font,
                        @ptrCast(current_text.*),
                        utils.renderSize().scale(0.5).add(utils.v2(-(bounds.x / 2), -100)),
                        fonts.Size.Medium,
                        0,
                        rl.Color.white,
                    );

                    const ending_music = assets.ending_music.getOrLoad();

                    if (!startedEnding) {
                        startTime = rl.getTime();
                        startedEnding = true;
                        current_text = &"";

                        rl.stopMusicStream(main_music);
                        rl.setMusicVolume(ending_music, 0.375);
                        rl.playMusicStream(ending_music);

                        continue;
                    }
                    rl.updateMusicStream(ending_music);

                    // time since audio started
                    const time_delta = rl.getTime() - startTime.?;

                    switch (@as(u8, @intFromFloat(time_delta))) {
                        0...2 => {
                            if (time_delta >= 2.8 and !rl.isSoundPlaying(ending_speech)) {
                                rl.playSound(ending_speech);
                            }
                        },
                        3...8 => current_text = &"Aided by your machines, the UN was able to manage the rehabilitation\nof the planet over the next ten years.",
                        9...13 => current_text = &"The human population has grown steadily,\nas lands and resources have started to be renewed.",
                        14...17 => current_text = &"Now retired, you sit comfortably,\nwatching over the world which created you",
                        18...22 => current_text = &"and which you have saved.",
                        23...26 => current_text = &"",
                        else => {
                            startTime = rl.getTime();
                            currentScreen = .Credits;
                        },
                    }
                },
                .Credits => {
                    if (game_end_time == 0) {
                        game_end_time = rl.getTime();
                    }

                    const ending_music = assets.ending_music.getOrLoad();
                    rl.updateMusicStream(ending_music);

                    const delta = rl.getTime() - startTime.?;
                    rl.drawTextEx(fonts.main_font, consts.credits, rl.Vector2.init(16, @floatCast((delta * -50) + 1024.0)), fonts.Size.Large, 0, rl.Color.white);
                },
            }

            //rl.drawFPS(0, 0);
            if (rl.isKeyPressed(.t)) {
                show_speedrun_timer = !show_speedrun_timer;
            }

            if (show_speedrun_timer) {
                var delta: f64 = undefined;
                if (game_start_time == 0) {
                    delta = 0;
                } else if (game_end_time != 0) {
                    delta = game_end_time - game_start_time;
                } else {
                    delta = rl.getTime() - game_start_time;
                }

                if (std.fmt.bufPrintZ(&timer_buffer, "{d:.3}", .{delta})) |out| {
                    rl.drawTextEx(
                        fonts.main_font,
                        @ptrCast(out),
                        rl.Vector2.init(16, @floatFromInt(rl.getRenderHeight() - fonts.Size.Medium)),
                        fonts.Size.Medium,
                        0,
                        rl.Color.green,
                    );
                } else |_| {
                    // no more space left to print out the timer.
                }
            }

            // end drawing
        }
    }
}
