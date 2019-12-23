const Feeds = artifacts.require("Feeds");

contract("Feeds test", async accounts => {
  let feeds;

  beforeEach(async () => {
    feeds = await Feeds.new(accounts[0]);
  });

  it("should set correctly", async () => {
    const expected = 120;
    feeds.set(expected);

    const value = await feeds.value();

    assert.equal(value, expected, "feeds.value should be 120");
  });

  it("should get correctly", async () => {
    const expected = 120;
    feeds.set(expected);

    const value = await feeds.get();

    assert.equal(value, expected, "feeds.value should be 120");
  });

  it("should getWithError correctly", async () => {
    const expected = 120;
    feeds.set(expected);

    const result = await feeds.getWithError();
    const value = result['0'];
    const active = result['1'];

    assert.equal(value, expected, "value should be 120");
    assert.equal(active, false, "active should be false");
  });

  it("should disable correctly", async () => {
    feeds.disable();
    const active = await feeds.active();

    assert.equal(active, false, "active should be false");
  });
});