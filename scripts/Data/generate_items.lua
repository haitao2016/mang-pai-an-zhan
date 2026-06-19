-- ============================================================================
-- generate_items.lua - 藏品数据生成脚本
-- 运行方式：lua scripts/Data/generate_items.lua
-- ============================================================================

-- 东方艺术品系列（50 件）
local easternItems = {
    { name = "青花瓷瓶", rarity = 1, value = { min = 200, max = 500 }, category = "瓷器" },
    { name = "景德镇茶具", rarity = 1, value = { min = 150, max = 400 }, category = "瓷器" },
    { name = "粉彩花瓶", rarity = 2, value = { min = 400, max = 800 }, category = "瓷器" },
    { name = "斗彩杯", rarity = 2, value = { min = 500, max = 1000 }, category = "瓷器" },
    { name = "珐琅彩碗", rarity = 3, value = { min = 1000, max = 2000 }, category = "瓷器" },
    { name = "宋瓷笔洗", rarity = 4, value = { min = 3000, max = 5000 }, category = "瓷器" },
    { name = "王羲之书法", rarity = 3, value = { min = 1500, max = 3000 }, category = "字画" },
    { name = "张旭草书", rarity = 3, value = { min = 1200, max = 2500 }, category = "字画" },
    { name = "山水长卷", rarity = 2, value = { min = 600, max = 1200 }, category = "字画" },
    { name = "工笔花鸟", rarity = 2, value = { min = 400, max = 900 }, category = "字画" },
    { name = "写意人物", rarity = 1, value = { min = 200, max = 500 }, category = "字画" },
    { name = "宋徽宗瘦金", rarity = 4, value = { min = 4000, max = 6000 }, category = "字画" },
    { name = "和田玉佩", rarity = 2, value = { min = 500, max = 1000 }, category = "玉器" },
    { name = "羊脂白玉", rarity = 3, value = { min = 1500, max = 3000 }, category = "玉器" },
    { name = "翡翠手镯", rarity = 3, value = { min = 1200, max = 2500 }, category = "玉器" },
    { name = "碧玉摆件", rarity = 2, value = { min = 400, max = 800 }, category = "玉器" },
    { name = "子冈玉牌", rarity = 4, value = { min = 3500, max = 5500 }, category = "玉器" },
    { name = "青铜鼎", rarity = 3, value = { min = 1000, max = 2000 }, category = "青铜器" },
    { name = "错金银器", rarity = 3, value = { min = 1500, max = 2800 }, category = "青铜器" },
    { name = "青铜镜", rarity = 2, value = { min = 300, max = 700 }, category = "青铜器" },
    { name = "漆器屏风", rarity = 2, value = { min = 500, max = 1000 }, category = "漆器" },
    { name = "雕漆盒", rarity = 2, value = { min = 400, max = 800 }, category = "漆器" },
    { name = "红雕漆瓶", rarity = 3, value = { min = 800, max = 1500 }, category = "漆器" },
    { name = "紫砂壶", rarity = 2, value = { min = 500, max = 1100 }, category = "紫砂" },
    { name = "供春壶", rarity = 3, value = { min = 1000, max = 2000 }, category = "紫砂" },
    { name = "曼生壶", rarity = 4, value = { min = 3000, max = 5000 }, category = "紫砂" },
    { name = "竹雕笔筒", rarity = 1, value = { min = 150, max = 400 }, category = "竹木" },
    { name = "黄花梨盒", rarity = 2, value = { min = 400, max = 900 }, category = "竹木" },
    { name = "紫檀柜", rarity = 3, value = { min = 1200, max = 2200 }, category = "竹木" },
    { name = "沉香手串", rarity = 2, value = { min = 600, max = 1200 }, category = "竹木" },
    { name = "金丝楠木", rarity = 3, value = { min = 1000, max = 1800 }, category = "竹木" },
    { name = "景泰蓝瓶", rarity = 2, value = { min = 500, max = 1000 }, category = "珐琅" },
    { name = "画珐琅盒", rarity = 2, value = { min = 400, max = 800 }, category = "珐琅" },
    { name = "錾金器", rarity = 3, value = { min = 800, max = 1500 }, category = "珐琅" },
    { name = "织锦挂屏", rarity = 1, value = { min = 200, max = 500 }, category = "织绣" },
    { name = "缂丝唐卡", rarity = 3, value = { min = 1200, max = 2200 }, category = "织绣" },
    { name = "苏绣屏风", rarity = 2, value = { min = 500, max = 1000 }, category = "织绣" },
    { name = "蜀锦腰带", rarity = 2, value = { min = 400, max = 800 }, category = "织绣" },
    { name = "龙袍", rarity = 4, value = { min = 4000, max = 7000 }, category = "织绣" },
    { name = "犀角杯", rarity = 4, value = { min = 3500, max = 6000 }, category = "杂项" },
    { name = "象牙雕", rarity = 3, value = { min = 1000, max = 2000 }, category = "杂项" },
    { name = "玳瑁盒", rarity = 2, value = { min = 300, max = 700 }, category = "杂项" },
    { name = "蜜蜡挂件", rarity = 1, value = { min = 150, max = 400 }, category = "杂项" },
    { name = "琥珀摆件", rarity = 2, value = { min = 500, max = 1000 }, category = "杂项" },
    { name = "砗磲念珠", rarity = 2, value = { min = 400, max = 900 }, category = "杂项" },
    { name = "田黄印章", rarity = 3, value = { min = 1500, max = 2800 }, category = "杂项" },
    { name = "鸡血石雕", rarity = 3, value = { min = 1000, max = 2000 }, category = "杂项" },
    { name = "紫晶洞", rarity = 2, value = { min = 600, max = 1200 }, category = "杂项" },
    { name = "端砚", rarity = 2, value = { min = 500, max = 1000 }, category = "文房" },
    { name = "歙砚", rarity = 2, value = { min = 400, max = 900 }, category = "文房" },
    { name = "湖笔", rarity = 1, value = { min = 100, max = 300 }, category = "文房" },
}

-- 西洋收藏系列（50 件）
local westernItems = {
    { name = "瑞士怀表", rarity = 1, value = { min = 200, max = 500 }, category = "钟表" },
    { name = "德国座钟", rarity = 1, value = { min = 180, max = 450 }, category = "钟表" },
    { name = "法国挂钟", rarity = 2, value = { min = 400, max = 800 }, category = "钟表" },
    { name = "英国落地钟", rarity = 2, value = { min = 600, max = 1200 }, category = "钟表" },
    { name = "百达翡丽怀表", rarity = 4, value = { min = 4000, max = 7000 }, category = "钟表" },
    { name = "江诗丹顿表", rarity = 4, value = { min = 3500, max = 6000 }, category = "钟表" },
    { name = "伯爵腕表", rarity = 3, value = { min = 1500, max = 3000 }, category = "钟表" },
    { name = "卡地亚手镯", rarity = 2, value = { min = 500, max = 1000 }, category = "珠宝" },
    { name = "梵克雅宝项链", rarity = 3, value = { min = 1200, max = 2500 }, category = "珠宝" },
    { name = "宝格丽戒指", rarity = 2, value = { min = 600, max = 1200 }, category = "珠宝" },
    { name = "蒂芙尼胸针", rarity = 2, value = { min = 400, max = 900 }, category = "珠宝" },
    { name = "海瑞温斯顿钻", rarity = 4, value = { min = 5000, max = 8000 }, category = "珠宝" },
    { name = "红宝石戒指", rarity = 3, value = { min = 1000, max = 2000 }, category = "珠宝" },
    { name = "蓝宝石吊坠", rarity = 3, value = { min = 1200, max = 2200 }, category = "珠宝" },
    { name = "油画《风景》", rarity = 1, value = { min = 200, max = 600 }, category = "油画" },
    { name = "静物油画", rarity = 2, value = { min = 400, max = 1000 }, category = "油画" },
    { name = "人物肖像", rarity = 2, value = { min = 500, max = 1200 }, category = "油画" },
    { name = "抽象艺术", rarity = 2, value = { min = 600, max = 1500 }, category = "油画" },
    { name = "印象派真迹", rarity = 4, value = { min = 5000, max = 10000 }, category = "油画" },
    { name = "文艺复兴画", rarity = 4, value = { min = 6000, max = 12000 }, category = "油画" },
    { name = "雕塑《思想者》", rarity = 3, value = { min = 1500, max = 3000 }, category = "雕塑" },
    { name = "铜雕摆件", rarity = 2, value = { min = 400, max = 900 }, category = "雕塑" },
    { name = "大理石雕", rarity = 3, value = { min = 1000, max = 2000 }, category = "雕塑" },
    { name = "木雕面具", rarity = 1, value = { min = 150, max = 400 }, category = "雕塑" },
    { name = "象牙雕塑", rarity = 4, value = { min = 3000, max = 5500 }, category = "雕塑" },
    { name = "波斯地毯", rarity = 2, value = { min = 500, max = 1100 }, category = "地毯" },
    { name = "土耳其挂毯", rarity = 2, value = { min = 400, max = 900 }, category = "地毯" },
    { name = "印度丝毯", rarity = 1, value = { min = 200, max = 500 }, category = "地毯" },
    { name = "古董沙发", rarity = 2, value = { min = 600, max = 1200 }, category = "家具" },
    { name = "路易十五椅", rarity = 3, value = { min = 1500, max = 3000 }, category = "家具" },
    { name = "维多利亚柜", rarity = 2, value = { min = 500, max = 1000 }, category = "家具" },
    { name = "巴洛克镜", rarity = 2, value = { min = 400, max = 800 }, category = "家具" },
    { name = "桃花心木桌", rarity = 2, value = { min = 500, max = 1000 }, category = "家具" },
    { name = "鎏金座钟", rarity = 2, value = { min = 400, max = 900 }, category = "金属器" },
    { name = "银质餐具", rarity = 1, value = { min = 200, max = 500 }, category = "金属器" },
    { name = "黄铜烛台", rarity = 1, value = { min = 100, max = 300 }, category = "金属器" },
    { name = "纯银酒壶", rarity = 2, value = { min = 400, max = 800 }, category = "金属器" },
    { name = "青铜雕塑", rarity = 2, value = { min = 500, max = 1000 }, category = "金属器" },
    { name = "瓷板画", rarity = 2, value = { min = 400, max = 900 }, category = "瓷器" },
    { name = "韦奇伍德瓷", rarity = 2, value = { min = 300, max = 700 }, category = "瓷器" },
    { name = "迈森瓷器", rarity = 3, value = { min = 800, max = 1600 }, category = "瓷器" },
    { name = "塞夫尔瓷", rarity = 3, value = { min = 1000, max = 2000 }, category = "瓷器" },
    { name = "骨灰盒瓷", rarity = 1, value = { min = 150, max = 400 }, category = "瓷器" },
    { name = "古董相机", rarity = 2, value = { min = 400, max = 900 }, category = "科技" },
    { name = "留声机", rarity = 2, value = { min = 500, max = 1000 }, category = "科技" },
    { name = "老式打字机", rarity = 1, value = { min = 200, max = 500 }, category = "科技" },
    { name = "指南针", rarity = 1, value = { min = 150, max = 400 }, category = "科技" },
    { name = "老式电话", rarity = 1, value = { min = 180, max = 450 }, category = "科技" },
    { name = "航海图", rarity = 2, value = { min = 400, max = 800 }, category = "文献" },
    { name = "古地图", rarity = 2, value = { min = 500, max = 1000 }, category = "文献" },
    { name = "手抄本", rarity = 3, value = { min = 1000, max = 2000 }, category = "文献" },
    { name = "古籍善本", rarity = 4, value = { min = 3000, max = 6000 }, category = "文献" },
}

-- 生成 Lua 代码
print("-- ============================================================================")
print("-- Extended Items Data - Generated by generate_items.lua")
print("-- 东方艺术品系列 (50 件) + 西洋收藏系列 (50 件)")
print("-- ============================================================================\n")

print("-- 东方艺术品系列")
for i, item in ipairs(easternItems) do
    local desc = "来自东方的精致" .. item.category
    print(string.format([[    {
        id = "eastern_%03d",
        name = "%s",
        description = "%s",
        rarity = %d,
        value = %d,
        category = "%s",
        series = "eastern"
    },]], i, item.name, desc, item.rarity, math.floor((item.value.min + item.value.max) / 2), item.category))
end

print("\n-- 西洋收藏系列")
for i, item in ipairs(westernItems) do
    local desc = "来自欧洲的精美" .. item.category
    print(string.format([[    {
        id = "western_%03d",
        name = "%s",
        description = "%s",
        rarity = %d,
        value = %d,
        category = "%s",
        series = "western"
    },]], i, item.name, desc, item.rarity, math.floor((item.value.min + item.value.max) / 2), item.category))
end

print("\n-- 总计生成 " .. #easternItems + #westernItems .. " 件新藏品")
