(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.9.1",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "陪玩现在必须消耗逗猫棒，没有剩余次数时将无法陪玩。",
          "图鉴改成格子收藏展示，已获得猫咪会显示在展示格中，点击后才展开属性详情。",
          "猫咪配对功能已从图鉴迁移到医院页面，治疗与繁育入口集中管理。",
        ],
        en: [
          "Playtime now always consumes one toy wand use, and you cannot play when no uses remain.",
          "The collection page is now a boxed gallery, and cat details only appear after you click a collected cat.",
          "Cat pairing has been moved from the collection page to the hospital page so treatment and breeding are managed together.",
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
      collectionInspectCatId: null,
    },
    systems: {},
    ui: {},
  };
})();
