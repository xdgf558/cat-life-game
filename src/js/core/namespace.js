(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.6.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "整体 UI 改成更明亮的掌机冒险风格，页面层次和按钮反馈更丰富。",
          "新增多首可循环背景音乐，会随首页、打工、陪猫和游戏厅状态切换。",
          "新增游戏厅模块和老虎机玩法，可以投入金币进行抽奖。",
        ],
        en: [
          "Refreshed the UI with a brighter handheld-adventure inspired style and richer button feedback.",
          "Added multiple looping background music themes that switch between home, work, cat care, and arcade states.",
          "Added an arcade module with a slot machine that lets you spend gold on spins.",
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
      diseaseCheckIntervalMs: 15 * 60 * 1000,
      staminaRecoveryIntervalMs: 60 * 60 * 1000,
      staminaRecoveryAmount: 5,
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
    },
    systems: {},
    ui: {},
  };
})();
