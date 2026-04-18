(function (game) {
  function recalculateComfort() {
    var baseComfort = 10;
    var furnitureScore = game.state.game.home.placedFurniture.reduce(function (sum, furnitureId) {
      var item = game.data.itemMap[furnitureId];
      return sum + (item && item.comfort ? item.comfort : 0);
    }, 0);

    game.state.game.home.comfortScore = baseComfort + furnitureScore;
    return game.state.game.home.comfortScore;
  }

  function getPlacedFurniture() {
    return game.state.game.home.placedFurniture
      .map(function (furnitureId) {
        return game.data.itemMap[furnitureId];
      })
      .filter(Boolean);
  }

  game.systems.homeSystem = {
    recalculateComfort: recalculateComfort,
    getPlacedFurniture: getPlacedFurniture,
  };
})(window.CatGame);
