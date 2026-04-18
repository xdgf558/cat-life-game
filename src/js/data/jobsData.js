(function (game) {
  var jobs = [
    {
      id: "job_flyer",
      name: "发传单",
      nameEn: "Flyer Handout",
      unlockLevel: 1,
      duration: 2,
      durationMinutes: 2,
      staminaCost: 10,
      goldReward: 60,
      expReward: 22,
      description: "轻松上手的基础工作，适合开局攒第一桶金。",
      descriptionEn: "A simple starter job that's great for earning your first savings.",
      eventPool: [
        { text: "路过的上班族给了你额外小费。", textEn: "A passerby tipped you a little extra.", goldDelta: 20 },
        { text: "今天发得很顺利，没有额外状况。", textEn: "The shift went smoothly with no surprises.", goldDelta: 0 },
        { text: "风有点大，传单飞了几张，但还是顺利收工。", textEn: "A few flyers blew away in the wind, but you still finished the shift.", goldDelta: -5 },
      ],
    },
    {
      id: "job_store",
      name: "便利店兼职",
      nameEn: "Convenience Store Shift",
      unlockLevel: 2,
      duration: 3,
      durationMinutes: 3,
      staminaCost: 15,
      goldReward: 100,
      expReward: 35,
      description: "节奏更忙，但收入稳定，适合中期冲级。",
      descriptionEn: "Busier, but steady income. Great for mid-game leveling.",
      eventPool: [
        { text: "老板夸你手脚利落，奖励了额外奖金。", textEn: "Your boss praised your speed and gave you a bonus.", goldDelta: 30 },
        { text: "有位顾客不小心打翻饮料，忙了好一阵。", textEn: "A customer spilled a drink and cost you some time.", goldDelta: -10 },
        { text: "一切都很平稳，准时打卡下班。", textEn: "Everything stayed calm and you clocked out on time.", goldDelta: 0 },
      ],
    },
    {
      id: "job_petshop",
      name: "宠物店助理",
      nameEn: "Pet Shop Assistant",
      unlockLevel: 4,
      duration: 4,
      durationMinutes: 4,
      staminaCost: 20,
      goldReward: 160,
      expReward: 52,
      description: "能接触到猫咪用品，收益更高，也更累。",
      descriptionEn: "Higher rewards and cat-related perks, but also more exhausting.",
      eventPool: [
        { text: "店长送了你一袋普通猫粮。", textEn: "The manager gifted you one bag of basic cat food.", goldDelta: 0, itemReward: "food_basic", itemAmount: 1 },
        { text: "你帮客人挑选用品，得到了一笔奖励。", textEn: "You helped a customer choose supplies and got a reward.", goldDelta: 25 },
        { text: "今天工作很扎实，拿到了基础薪水。", textEn: "You worked steadily today and took home the base pay.", goldDelta: 0 },
      ],
    },
    {
      id: "job_it_engineer",
      name: "IT 工程师",
      nameEn: "IT Engineer",
      unlockLevel: 6,
      duration: 10,
      durationMinutes: 10,
      staminaCost: 30,
      goldReward: 400,
      expReward: 100,
      description: "高强度脑力工作，耗时更久，但回报也非常可观。",
      descriptionEn: "A demanding brain-heavy job that takes longer but pays extremely well.",
      eventPool: [
        { text: "线上事故处理得很漂亮，项目负责人给了额外奖金。", textEn: "You handled a production incident beautifully and got a bonus.", goldDelta: 60 },
        { text: "今天需求改了三轮，但你还是按时交付。", textEn: "Requirements changed three times, but you still shipped on time.", goldDelta: 0 },
        { text: "临时排查线上 bug 花了不少时间，奖金略少一些。", textEn: "Emergency bug fixing ate a lot of time, so the bonus was a bit smaller.", goldDelta: -30 },
      ],
    },
  ];

  game.data.jobs = jobs;
  game.data.jobMap = jobs.reduce(function (map, job) {
    map[job.id] = job;
    return map;
  }, {});
})(window.CatGame);
