(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.4.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "逗猫棒改为消耗次数道具，用完后会自动消失。",
          "新增猫咪年龄与疾病系统，年龄按现实时间 10 倍成长。",
          "新增医院页面，不同疾病会有不同治疗费用。",
          "其他猫咪现在需要金币 5000 且原始猫咪满 1 岁后解锁。",
        ],
        en: [
          "Toy wands are now limited-use items and disappear when spent.",
          "Added cat aging and disease systems with 10x real-time growth.",
          "Added a hospital page with disease-based treatment costs.",
          "Extra cats now unlock at 5000 gold and after the first cat turns 1 year old.",
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
