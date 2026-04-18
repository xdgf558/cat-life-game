(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.6.1",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "老虎机新增滚动动画效果，开转与停下更有街机感。",
          "任务里新增老虎机累计赢取 1 万金币的成就奖励。",
          "商店新增猫草，营养膏和猫草都可以在猫咪页直接使用。",
        ],
        en: [
          "Added reel scrolling animation to the slot machine for a stronger arcade feel.",
          "Added a new achievement for earning 10,000 gold through the slot machine.",
          "Added cat grass to the shop, and both nutrition paste and cat grass can now be used from the cat page.",
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
      arcadeSpin: null,
    },
    systems: {},
    ui: {},
  };
})();
