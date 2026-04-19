(function () {
  window.CatGame = window.CatGame || {
    config: {
      storageKey: "catGameSaveV1",
      version: "1.8.0",
      startingFurniture: ["bed_basic", "bowl_basic"],
      releaseNotes: {
        "zh-CN": [
          "房间里的家具现在可以自由拖拽摆放，位置会跟随存档一起保存。",
          "猫咪加入性别与怀孕系统，只有公猫和母猫才能配对，孕期母猫喂食会消耗更多猫粮。",
          "老虎机滚动动画已收紧在转轮窗口内，视觉表现更稳定。",
        ],
        en: [
          "Furniture can now be freely dragged around inside the room, and positions are saved with your progress.",
          "Cats now have genders and pregnancy rules, so only male and female pairs can breed and pregnant mothers consume more food.",
          "The slot machine spin animation is now clipped cleanly inside each reel window.",
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
