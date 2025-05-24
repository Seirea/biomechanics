const rl = @import("raylib");

pub fn AssetPool(comptime T: type) type {
    return struct {
        assets: []const *Asset(T),
        fn init(assets: []const *Asset(T)) AssetPool(T) {
            return .{ .assets = assets };
        }
        pub fn deinitAll(self: AssetPool(T)) void {
            for (self.assets) |x| {
                x.deinit();
            }
        }
    };
}

pub const SoundWrapper = struct {
    sound: rl.Sound,
    pub fn play(self: SoundWrapper) void {
        rl.playSound(self.sound);
    }
    pub fn stop(self: SoundWrapper) void {
        rl.stopSound(self.sound);
    }
    pub fn isPlaying(self: SoundWrapper) bool {
        return rl.isSoundPlaying(self.sound);
    }
    pub fn loadFrom(fp: [:0]const u8) !SoundWrapper {
        return .{ .sound = try rl.loadSound(fp) };
    }
    pub fn deinit(self: SoundWrapper) void {
        rl.unloadSound(self.sound);
    }
};

/// Audio or Texture Stream
pub fn Asset(comptime T: type) type {
    return struct {
        asset: ?T = null,
        file_path: [:0]const u8,

        pub fn init(comptime fp: [:0]const u8) Asset(T) {
            return .{ .file_path = fp };
        }

        pub fn getOrLoad(self: *Asset(T)) T {
            if (self.asset == null) {
                self.asset = switch (comptime T) {
                    rl.Texture => rl.Texture.fromImage(
                        rl.Image.init(self.file_path) catch @panic("could not load image"),
                    ) catch @panic("could not load texture from image"),
                    SoundWrapper => SoundWrapper.loadFrom(self.file_path) catch @panic("could not load sound wrapper"),
                    rl.Music => rl.loadMusicStream(self.file_path) catch @panic("could not load music"),
                    else => unreachable,
                };
            }
            return self.asset.?;
        }

        pub fn deinit(self: *Asset(T)) void {
            if (self.asset) |x| {
                switch (comptime T) {
                    rl.Texture => {
                        x.unload();
                    },
                    SoundWrapper => {
                        x.deinit();
                    },
                    rl.Music => {
                        rl.unloadMusicStream(x);
                    },
                    else => {
                        unreachable;
                    },
                }
            }
        }
    };
}
// aliases for easier usage
pub const TAsset = Asset(rl.Texture);
pub const MAsset = Asset(rl.Music);
pub const SAsset = Asset(SoundWrapper);

pub var poiPinTex = TAsset.init("resources/poi-ani.png");
pub var poiPinLockedTex = TAsset.init("resources/locked-pin.png");
pub var poiPinHoverTex = TAsset.init("resources/poi-hover-ani.png");
pub var poiPinCompletedTex = TAsset.init("resources/checked-pin.png");

pub var globeTexture = TAsset.init("resources/globe.png");
pub var gameLogo = TAsset.init("resources/logo.png");
pub var spaceBg = TAsset.init("resources/space.png");
pub var playBg = TAsset.init("resources/play-bg.png");

pub var solarComponent0 = TAsset.init("resources/POI/SolarPanel/0/pic.png");
pub var solarComponent1 = TAsset.init("resources/POI/SolarPanel/1/pic.png");
pub var solarComponent2 = TAsset.init("resources/POI/SolarPanel/2/pic.png");

pub var nuclearComponent0 = TAsset.init("resources/POI/NuclearReactor/0/pic.png");
pub var nuclearComponent1 = TAsset.init("resources/POI/NuclearReactor/1/pic.png");
pub var nuclearComponent2 = TAsset.init("resources/POI/NuclearReactor/2/pic.png");

pub var carbonComponent0 = TAsset.init("resources/POI/CarbonCapture/0/pic.png");
pub var carbonComponent1 = TAsset.init("resources/POI/CarbonCapture/1/pic.png");
pub var carbonComponent2 = TAsset.init("resources/POI/CarbonCapture/2/pic.png");

pub var desertCutscene = TAsset.init("resources/cutscenes/desert.png");
pub var labCutscene = TAsset.init("resources/cutscenes/lab.png");
pub var endingCutscene = TAsset.init("resources/cutscenes/ending.png");

pub var completedComponent = TAsset.init("resources/component-win.png");
pub var completedMachine = TAsset.init("resources/machine-win.png");

pub var solarMachine = TAsset.init("resources/POI/SolarPanel/machine.png");
pub var nuclearMachine = TAsset.init("resources/POI/NuclearReactor/machine.png");
pub var carbonMachine = TAsset.init("resources/POI/CarbonCapture/machine.png");

pub var backBtn = TAsset.init("resources/back-btn.png");
pub var backBtnHover = TAsset.init("resources/back-btn-hover.png");
pub var checkmark = TAsset.init("resources/checkmark.png");
pub var lock = TAsset.init("resources/lock.png");

pub var playBtn = TAsset.init("resources/play-btn.png");
pub var playBtnHover = TAsset.init("resources/play-btn-hover.png");
pub var playBtnPress = TAsset.init("resources/play-btn-press.png");

pub var continueBtn = TAsset.init("resources/continue-btn.png");
pub var continueBtnHover = TAsset.init("resources/continue-btn-hover.png");
pub var continueBtnPress = TAsset.init("resources/continue-btn-pressed.png");

pub var repairBtn = TAsset.init("resources/repair-btn.png");
pub var repairBtnHover = TAsset.init("resources/repair-btn-hover.png");
pub var repairBtnPress = TAsset.init("resources/repair-btn-press.png");

pub var standard_node = TAsset.init("resources/POI/standard-node.png");

pub var n_type_silicon_node = TAsset.init("resources/POI/SolarPanel/Nodes/0.png");
pub var p_type_silicon_node = TAsset.init("resources/POI/SolarPanel/Nodes/1.png");
pub var sealant_node = TAsset.init("resources/POI/SolarPanel/Nodes/2.png");
pub var screw_node = TAsset.init("resources/POI/SolarPanel/Nodes/3.png");

pub var absorber_1_node = TAsset.init("resources/POI/NuclearReactor/Nodes/absorber-1.png");
pub var absorber_2_node = TAsset.init("resources/POI/NuclearReactor/Nodes/absorber-2.png");
pub var absorber_3_node = TAsset.init("resources/POI/NuclearReactor/Nodes/absorber-3.png");
pub var control_rod_node = TAsset.init("resources/POI/NuclearReactor/Nodes/control-rod.png");
pub var steam_plate_node = TAsset.init("resources/POI/NuclearReactor/Nodes/steam-plate.png");
pub var columns_node = TAsset.init("resources/POI/NuclearReactor/Nodes/columns.png");

pub var injection_walls_1_node = TAsset.init("resources/POI/CarbonCapture/Nodes/injection-walls-1.png");
pub var injection_walls_2_node = TAsset.init("resources/POI/CarbonCapture/Nodes/injection-walls-2.png");
pub var injection_walls_3_node = TAsset.init("resources/POI/CarbonCapture/Nodes/injection-walls-3.png");
pub var pipeline_segment_node = TAsset.init("resources/POI/CarbonCapture/Nodes/pipeline-segment.png");
pub var solvent_node = TAsset.init("resources/POI/CarbonCapture/Nodes/solvent.png");

pub var assetPool = AssetPool(rl.Texture).init(&.{
    &poiPinTex,
    &poiPinLockedTex,
    &poiPinHoverTex,
    &poiPinCompletedTex,

    &globeTexture,
    &gameLogo,
    &spaceBg,
    &playBg,

    &solarComponent0,
    &solarComponent1,
    &solarComponent2,

    &nuclearComponent0,
    &nuclearComponent1,
    &nuclearComponent2,

    &carbonComponent0,
    &carbonComponent1,
    &carbonComponent2,

    &desertCutscene,
    &labCutscene,
    &endingCutscene,

    &completedComponent,
    &completedMachine,

    &solarMachine,
    &nuclearMachine,
    &carbonMachine,

    &backBtn,
    &backBtnHover,
    &checkmark,
    &lock,

    &playBtn,
    &playBtnHover,
    &playBtnPress,

    &continueBtn,
    &continueBtnHover,
    &continueBtnPress,

    &repairBtn,
    &repairBtnHover,
    &repairBtnPress,

    &standard_node,

    &n_type_silicon_node,
    &p_type_silicon_node,
    &sealant_node,
    &screw_node,

    &absorber_1_node,
    &absorber_2_node,
    &absorber_3_node,
    &control_rod_node,
    &steam_plate_node,
    &columns_node,

    &injection_walls_1_node,
    &injection_walls_2_node,
    &injection_walls_3_node,
    &pipeline_segment_node,
    &solvent_node,
});

pub var introductionSpeech1 = SAsset.init("resources/audio/intro1.ogg");
pub var introductionSpeech2 = SAsset.init("resources/audio/intro2.ogg");
pub var endingSpeech = SAsset.init("resources/audio/ending.ogg");

pub var click_sfx = SAsset.init("resources/sfx/click.mp3");
pub var slide_sfx = SAsset.init("resources/sfx/slide.mp3");
pub var win_sfx = SAsset.init("resources/sfx/win.mp3");

pub var ending_music = MAsset.init("resources/music/reflected-light.ogg");
pub var main_music = MAsset.init("resources/music/whispers-of-tranquility.ogg");

pub var soundPool = AssetPool(SoundWrapper).init(&.{
    &introductionSpeech1,
    &introductionSpeech2,
    &endingSpeech,

    &click_sfx,
    &slide_sfx,
    &win_sfx,
});

pub var musicPool = AssetPool(rl.Music).init(&.{
    &main_music,
    &ending_music,
});
