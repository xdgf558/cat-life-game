(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.3.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "加入猫咪死亡后的重新领养机制。",
          "设置页新增中英语言切换，支持英文界面。",
          "猫咪新增状态图标，会随心情和死亡状态变化。",
          "商店里的道具和家具新增图标展示。",
        ],
        en: [
          "Added a readoption system after a cat dies.",
          "Added English language support and a settings language switch.",
          "Cats now have expressive state icons for mood and death.",
          "Shop items and furniture now display icons.",
        ],
      },
      readoptCost: 80,
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
