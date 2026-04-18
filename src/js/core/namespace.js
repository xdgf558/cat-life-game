(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.5.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "完成手机屏幕适配，按钮和导航支持触屏操作。",
          "玩家体力改为按现实时间恢复：每小时恢复 5 点，升级不再恢复体力。",
          "新增高级打工工作“IT 工程师”，现实时间 10 分钟，收益更高。",
        ],
        en: [
          "Added mobile-friendly responsive layout and touch-friendly controls.",
          "Player stamina now restores in real time at 5 points per hour, and leveling up no longer restores stamina.",
          "Added a high-tier job, IT Engineer, with a 10-minute real-time duration and better rewards.",
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
