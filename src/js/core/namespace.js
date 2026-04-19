(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.9.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "房间加入改造功能，升级后面积更大、可容纳更多家具，房间里的猫咪尺寸也同步优化。",
          "新增独立存档管理页，集中显示本地存档提示、手动保存、导出、导入和重置功能。",
          "继续保持本地单机存档模式，所有进度仍保存在当前浏览器的 localStorage 中。",
        ],
        en: [
          "The room now supports renovations, with more floor space, higher furniture capacity, and better-scaled cats in the room scene.",
          "Added a dedicated save management page for local save tips, manual saving, export, import, and reset actions.",
          "The game remains fully local and browser-only, with progress stored in localStorage.",
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
    },
    systems: {},
    ui: {},
  };
})();
