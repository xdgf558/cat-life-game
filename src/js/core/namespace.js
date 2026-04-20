(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.10.1",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "新增猫咪自定义取名功能，可以在猫咪页面单独修改每只猫的名字。",
          "背景音乐新增本地音频导入功能，可把一首本地音乐保存为当前存档的自定义BGM。",
          "自定义BGM启用后会优先播放本地音乐；关闭后仍会回到原本的场景主题音乐。",
        ],
        en: [
          "Added custom cat naming so each cat can be renamed from the cat page.",
          "Added local audio import support so one custom BGM track can be saved inside the current local save.",
          "When custom BGM is enabled it takes priority over scene music, and disabling it restores the original dynamic soundtrack.",
        ],
        ja: [
          "猫ごとの名前変更機能を追加し、猫ページから個別に名前を付けられるようにしました。",
          "ローカル音楽ファイルの読み込みに対応し、現在のセーブに自分だけのBGMを保存できます。",
          "カスタムBGMを有効にするとローカル音楽が優先再生され、無効化すると元の場面別BGMへ戻ります。",
        ],
      },
      readoptCost: 80,
      toyWandUsesPerPurchase: 6,
      catUnlockRequirements: {
        gold: 5000,
        baseCatId: "cat_001",
        baseAgeYears: 1,
      },
      catAgeAcceleration: 10,
      pregnancyDurationMs: 30 * 60 * 1000,
      pregnancyFoodMultiplier: 2,
      roomUpgradeSteps: [
        { level: 1, capacity: 3, width: 620, height: 360, upgradeCost: 450 },
        { level: 2, capacity: 4, width: 760, height: 420, upgradeCost: 900 },
        { level: 3, capacity: 5, width: 900, height: 500, upgradeCost: 1600 },
        { level: 4, capacity: 6, width: 1020, height: 580, upgradeCost: null },
      ],
      diseaseCheckIntervalMs: 15 * 60 * 1000,
      staminaRecoveryIntervalMs: 60 * 60 * 1000,
      staminaRecoveryAmount: 5,
      customMusicMaxBytes: 2 * 1024 * 1024,
      slotBets: [20, 50, 100],
      catDecayRules: {
        hunger: { intervalMs: 12 * 60 * 1000, label: "饱腹" },
        clean: { intervalMs: 8 * 60 * 1000, label: "清洁" },
        mood: { intervalMs: 6 * 60 * 1000, label: "心情" },
        health: { intervalMs: 10 * 60 * 1000, label: "健康" },
        energy: { intervalMs: 5 * 60 * 1000, label: "活力" },
      },
    },
    data: {},
    utils: {},
    state: {
      game: null,
      currentPage: "home",
      selectedCatId: "cat_001",
      notifications: [],
      arcadeSpin: null,
      roomDrag: null,
      collectionInspectCatId: null,
    },
    systems: {},
    ui: {},
  };
})();
