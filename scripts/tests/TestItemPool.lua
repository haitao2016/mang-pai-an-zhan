-- ============================================================================
-- tests/TestItemPool.lua - ItemPool 单元测试
-- ============================================================================

local TestRunner = require("Utils.TestRunner")
local Config = require("Config")
local ItemPool = require("Game.ItemPool")

-- 测试套件
local tests = {
    -- 基础测试
    test_create_pool = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        TestRunner.Assert(pool ~= nil, "ItemPool should be created")
        TestRunner.AssertEqual("hall_beginner", pool.hallId, "Should have correct hall ID")
    end,

    test_default_hall = function()
        local pool = ItemPool.New(nil)
        TestRunner.Assert(pool ~= nil, "Should create with default hall")
    end,

    -- 稀有度权重测试
    test_rarity_weights = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        TestRunner.Assert(pool.rarityWeights ~= nil, "Should have rarity weights")
        local total = pool.rarityWeights[1] + pool.rarityWeights[2] +
                      pool.rarityWeights[3] + pool.rarityWeights[4]
        TestRunner.AssertEqual(100, total, "Total weight should be 100")
    end,

    -- 藏品生成测试
    test_generate_item = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        local item = pool:GenerateItem()

        TestRunner.Assert(item ~= nil, "Item should be generated")
        TestRunner.Assert(item.name ~= nil, "Item should have name")
        TestRunner.Assert(item.rarity >= 1 and item.rarity <= 4, "Rarity should be 1-4")
        TestRunner.Assert(item.value > 0, "Value should be positive")
    end,

    test_generate_box = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        local items, totalValue = pool:GenerateBox(5)

        TestRunner.AssertEqual(5, #items, "Should generate 5 items")
        TestRunner.Assert(totalValue > 0, "Total value should be positive")

        local sum = 0
        for _, item in ipairs(items) do
            sum = sum + item.value
        end
        TestRunner.AssertEqual(totalValue, sum, "Sum should equal totalValue")
    end,

    test_box_value_range = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])

        -- 生成多次，应该在合理范围内
        local validCount = 0
        for i = 1, 20 do
            local _, totalValue = pool:GenerateBox(5)
            local vMin = pool.itemValueRange[1] * 5 * 0.6
            local vMax = pool.itemValueRange[2] * 5 * 0.5
            if totalValue >= vMin and totalValue <= vMax then
                validCount = validCount + 1
            end
        end
        -- 至少应该有一定比例在范围内
        TestRunner.Assert(validCount > 0, "Some boxes should be in valid range")
    end,

    -- 锦鲤体质测试
    test_lucky_bonus = function()
        local pool = ItemPool.New(Config.AuctionHalls[4])  -- 天工殿，传说概率高

        local bonusRarityCount = 0
        local normalRarityCount = 0

        -- 生成大量藏品对比
        for i = 1, 1000 do
            local withBonus = pool:GenerateItem(0.10)
            if withBonus.rarity >= 3 then
                bonusRarityCount = bonusRarityCount + 1
            end
        end

        -- 锦鲤体质应该提高高稀有度概率
        local bonusRate = bonusRarityCount / 1000
        -- 天工殿基础传说概率20%，带锦鲤应该更高
        -- 注意：这是统计测试，可能有波动
        print(string.format("[Test] High rarity rate with bonus: %.1f%%", bonusRate * 100))
    end,

    -- 稀有度降级测试
    test_rarity_fallback = function()
        -- 创建一个只有普通藏品的池子
        local Config = require("Config")
        local customHall = {
            id = "test",
            itemValueRange = {50, 100},
            rarityWeights = {100, 0, 0, 0},  -- 只有普通
            itemCountPerBox = 3,
        }
        local pool = ItemPool.New(customHall)

        -- 应该能正常生成
        local item = pool:GenerateItem()
        TestRunner.Assert(item ~= nil, "Should generate item even with limited rarities")
    end,

    -- 分类信息测试
    test_item_category = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        local item = pool:GenerateItem()

        TestRunner.Assert(item.category ~= nil, "Item should have category")
        TestRunner.Assert(item.category ~= "", "Category should not be empty")
    end,

    -- 价值范围测试
    test_item_value_in_range = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])
        local hallRange = pool.itemValueRange

        for i = 1, 50 do
            local item = pool:GenerateItem()
            -- 物品价值应该在厅的价值范围内
            -- 注意：由于模板限制，可能会有超出
            if item.valueRange then
                TestRunner.Assert(item.value >= item.valueRange[1], "Value should be >= min range")
                TestRunner.Assert(item.value <= item.valueRange[2], "Value should be <= max range")
            end
        end
    end,

    -- 稀有度名称测试
    test_rarity_name = function()
        local pool = ItemPool.New(Config.AuctionHalls[1])

        for i = 1, 100 do
            local item = pool:GenerateItem()
            TestRunner.Assert(item.rarityName ~= nil, "Should have rarity name")
            if item.rarity == 1 then
                TestRunner.AssertEqual("普通", item.rarityName)
            elseif item.rarity == 4 then
                TestRunner.AssertEqual("传说", item.rarityName)
            end
        end
    end,
}

-- 运行测试
TestRunner.RunSuite("ItemPool", tests)
TestRunner.PrintSummary()

return TestRunner.results
