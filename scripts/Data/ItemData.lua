-- ============================================================================
-- ItemData.lua - 《盲拍暗战》藏品数据库（300 件）
-- 分 10 大类，每类按 4 档稀有度分层，价值区间各异
-- rarity: 1=普通, 2=稀有, 3=史诗, 4=传说
-- ============================================================================

local ItemData = {}

--- 所有藏品模板
ItemData.Items = {

    -- ================================================================
    -- 1. 瓷器 (30 件)
    -- ================================================================
    { name = "青花碗",         category = "瓷器", rarity = 1, valueRange = {200, 600} },
    { name = "白瓷盘",         category = "瓷器", rarity = 1, valueRange = {150, 550} },
    { name = "粉彩茶杯",       category = "瓷器", rarity = 1, valueRange = {180, 580} },
    { name = "釉下彩碟",       category = "瓷器", rarity = 1, valueRange = {160, 520} },
    { name = "素瓷花瓶",       category = "瓷器", rarity = 1, valueRange = {220, 650} },
    { name = "青瓷香炉",       category = "瓷器", rarity = 1, valueRange = {250, 700} },
    { name = "仿古瓷罐",       category = "瓷器", rarity = 1, valueRange = {180, 600} },
    { name = "窑变釉盏",       category = "瓷器", rarity = 1, valueRange = {200, 620} },
    { name = "景泰蓝花瓶",     category = "瓷器", rarity = 2, valueRange = {800, 2000} },
    { name = "宋代茶碗",       category = "瓷器", rarity = 2, valueRange = {900, 2200} },
    { name = "哥窑笔洗",       category = "瓷器", rarity = 2, valueRange = {1000, 2400} },
    { name = "钧窑花盆",       category = "瓷器", rarity = 2, valueRange = {850, 2100} },
    { name = "定窑白瓷瓶",     category = "瓷器", rarity = 2, valueRange = {950, 2300} },
    { name = "影青刻花碗",     category = "瓷器", rarity = 2, valueRange = {800, 1900} },
    { name = "建窑油滴盏",     category = "瓷器", rarity = 2, valueRange = {1100, 2600} },
    { name = "龙泉青瓷",       category = "瓷器", rarity = 3, valueRange = {2500, 5000} },
    { name = "唐三彩马",       category = "瓷器", rarity = 3, valueRange = {2800, 5500} },
    { name = "元青花大罐",     category = "瓷器", rarity = 3, valueRange = {3000, 6000} },
    { name = "明代斗彩杯",     category = "瓷器", rarity = 3, valueRange = {3200, 5800} },
    { name = "珐琅彩碗",       category = "瓷器", rarity = 3, valueRange = {2600, 5200} },
    { name = "汝窑天青釉洗",   category = "瓷器", rarity = 4, valueRange = {5500, 11000} },
    { name = "鸡缸杯",         category = "瓷器", rarity = 4, valueRange = {6000, 12000} },
    { name = "宣德炉",         category = "瓷器", rarity = 4, valueRange = {5000, 10000} },

    -- ================================================================
    -- 2. 玉石 (30 件)
    -- ================================================================
    { name = "翡翠手串",       category = "玉石", rarity = 1, valueRange = {200, 650} },
    { name = "和田玉坠",       category = "玉石", rarity = 1, valueRange = {250, 700} },
    { name = "岫玉摆件",       category = "玉石", rarity = 1, valueRange = {150, 500} },
    { name = "青白玉扳指",     category = "玉石", rarity = 1, valueRange = {180, 580} },
    { name = "碧玉笔架",       category = "玉石", rarity = 1, valueRange = {200, 600} },
    { name = "玛瑙鼻烟壶",     category = "玉石", rarity = 1, valueRange = {220, 650} },
    { name = "黄玉如意",       category = "玉石", rarity = 1, valueRange = {280, 720} },
    { name = "墨玉印章",       category = "玉石", rarity = 1, valueRange = {160, 540} },
    { name = "和田玉佩",       category = "玉石", rarity = 2, valueRange = {1000, 2500} },
    { name = "翡翠观音",       category = "玉石", rarity = 2, valueRange = {1200, 2800} },
    { name = "白玉镂雕牌",     category = "玉石", rarity = 2, valueRange = {900, 2200} },
    { name = "青玉山子",       category = "玉石", rarity = 2, valueRange = {1100, 2600} },
    { name = "红翡手镯",       category = "玉石", rarity = 2, valueRange = {1000, 2400} },
    { name = "碧玉香薰",       category = "玉石", rarity = 2, valueRange = {950, 2300} },
    { name = "冰种翡翠挂件",   category = "玉石", rarity = 2, valueRange = {1300, 2900} },
    { name = "羊脂玉壶",       category = "玉石", rarity = 3, valueRange = {2800, 5500} },
    { name = "帝王绿翡翠戒面", category = "玉石", rarity = 3, valueRange = {3500, 6500} },
    { name = "玉如意",         category = "玉石", rarity = 3, valueRange = {2500, 5000} },
    { name = "青玉龙纹璧",     category = "玉石", rarity = 3, valueRange = {3000, 5800} },
    { name = "翡翠满绿手镯",   category = "玉石", rarity = 3, valueRange = {3200, 6200} },
    { name = "和田籽料原石",   category = "玉石", rarity = 4, valueRange = {5500, 11000} },
    { name = "翡翠帝王绿项链", category = "玉石", rarity = 4, valueRange = {7000, 14000} },
    { name = "古玉龙凤佩",     category = "玉石", rarity = 4, valueRange = {6000, 12000} },

    -- ================================================================
    -- 3. 书画 (30 件)
    -- ================================================================
    { name = "水墨山水小品",   category = "书画", rarity = 1, valueRange = {180, 600} },
    { name = "花鸟扇面",       category = "书画", rarity = 1, valueRange = {150, 520} },
    { name = "行书条幅",       category = "书画", rarity = 1, valueRange = {200, 650} },
    { name = "工笔花卉团扇",   category = "书画", rarity = 1, valueRange = {220, 680} },
    { name = "写意墨竹",       category = "书画", rarity = 1, valueRange = {160, 550} },
    { name = "草书拓片",       category = "书画", rarity = 1, valueRange = {140, 480} },
    { name = "白描人物册页",   category = "书画", rarity = 1, valueRange = {200, 620} },
    { name = "没骨花卉",       category = "书画", rarity = 1, valueRange = {180, 580} },
    { name = "宋代山水卷",     category = "书画", rarity = 2, valueRange = {900, 2200} },
    { name = "元代墨竹图",     category = "书画", rarity = 2, valueRange = {1000, 2500} },
    { name = "明代人物画",     category = "书画", rarity = 2, valueRange = {850, 2100} },
    { name = "清代花鸟册",     category = "书画", rarity = 2, valueRange = {1100, 2600} },
    { name = "名家行书横幅",   category = "书画", rarity = 2, valueRange = {950, 2300} },
    { name = "金碧山水图",     category = "书画", rarity = 2, valueRange = {1200, 2800} },
    { name = "院体工笔翎毛",   category = "书画", rarity = 2, valueRange = {800, 2000} },
    { name = "明代字画",       category = "书画", rarity = 3, valueRange = {3000, 6000} },
    { name = "宋人小品册页",   category = "书画", rarity = 3, valueRange = {2800, 5500} },
    { name = "八大山人写意",   category = "书画", rarity = 3, valueRange = {3500, 6500} },
    { name = "董其昌山水卷",   category = "书画", rarity = 3, valueRange = {3200, 6200} },
    { name = "石涛泼墨图",     category = "书画", rarity = 3, valueRange = {2600, 5200} },
    { name = "富春山居图（残卷）", category = "书画", rarity = 4, valueRange = {6000, 12000} },
    { name = "清明上河图（仿本）", category = "书画", rarity = 4, valueRange = {5500, 11000} },
    { name = "兰亭序摹本",     category = "书画", rarity = 4, valueRange = {7000, 14000} },

    -- ================================================================
    -- 4. 金属器 (30 件)
    -- ================================================================
    { name = "铜制怀表",       category = "金属器", rarity = 1, valueRange = {200, 600} },
    { name = "银质书签",       category = "金属器", rarity = 1, valueRange = {150, 500} },
    { name = "铜香插",         category = "金属器", rarity = 1, valueRange = {160, 520} },
    { name = "铁壶",           category = "金属器", rarity = 1, valueRange = {180, 580} },
    { name = "铜镜",           category = "金属器", rarity = 1, valueRange = {220, 650} },
    { name = "银质酒杯",       category = "金属器", rarity = 1, valueRange = {200, 620} },
    { name = "铜锁",           category = "金属器", rarity = 1, valueRange = {140, 480} },
    { name = "白铜墨盒",       category = "金属器", rarity = 1, valueRange = {180, 600} },
    { name = "青铜鼎",         category = "金属器", rarity = 2, valueRange = {900, 2200} },
    { name = "鎏金铜佛像",     category = "金属器", rarity = 2, valueRange = {1100, 2600} },
    { name = "银鎏金发簪",     category = "金属器", rarity = 2, valueRange = {800, 2000} },
    { name = "铜胎珐琅瓶",     category = "金属器", rarity = 2, valueRange = {1000, 2400} },
    { name = "宣德铜香炉",     category = "金属器", rarity = 2, valueRange = {1200, 2800} },
    { name = "铁错金如意",     category = "金属器", rarity = 2, valueRange = {950, 2300} },
    { name = "银丝嵌宝盒",     category = "金属器", rarity = 2, valueRange = {1050, 2500} },
    { name = "商代铜爵",       category = "金属器", rarity = 3, valueRange = {3000, 5800} },
    { name = "金丝楠木包金盒", category = "金属器", rarity = 3, valueRange = {2600, 5200} },
    { name = "铜错金博山炉",   category = "金属器", rarity = 3, valueRange = {2800, 5500} },
    { name = "银鎏金经幢",     category = "金属器", rarity = 3, valueRange = {3200, 6000} },
    { name = "金嵌宝石冠",     category = "金属器", rarity = 3, valueRange = {3500, 6500} },
    { name = "后母戊鼎（微缩）", category = "金属器", rarity = 4, valueRange = {6000, 12000} },
    { name = "金缕玉衣残片",   category = "金属器", rarity = 4, valueRange = {5500, 11000} },
    { name = "纯金宝塔模型",   category = "金属器", rarity = 4, valueRange = {7000, 14000} },

    -- ================================================================
    -- 5. 木雕漆器 (30 件)
    -- ================================================================
    { name = "木雕摆件",       category = "木雕漆器", rarity = 1, valueRange = {150, 550} },
    { name = "檀木棋盘",       category = "木雕漆器", rarity = 1, valueRange = {180, 600} },
    { name = "黄杨木梳",       category = "木雕漆器", rarity = 1, valueRange = {120, 420} },
    { name = "竹雕笔筒",       category = "木雕漆器", rarity = 1, valueRange = {160, 540} },
    { name = "木制茶盘",       category = "木雕漆器", rarity = 1, valueRange = {200, 620} },
    { name = "漆器小碟",       category = "木雕漆器", rarity = 1, valueRange = {140, 480} },
    { name = "花梨木盒",       category = "木雕漆器", rarity = 1, valueRange = {180, 580} },
    { name = "红木镇纸",       category = "木雕漆器", rarity = 1, valueRange = {160, 520} },
    { name = "紫檀笔架",       category = "木雕漆器", rarity = 2, valueRange = {800, 2000} },
    { name = "黄花梨如意",     category = "木雕漆器", rarity = 2, valueRange = {1000, 2500} },
    { name = "竹刻臂搁",       category = "木雕漆器", rarity = 2, valueRange = {850, 2100} },
    { name = "雕漆捧盒",       category = "木雕漆器", rarity = 2, valueRange = {1100, 2600} },
    { name = "剔红花卉盘",     category = "木雕漆器", rarity = 2, valueRange = {900, 2200} },
    { name = "沉香木雕件",     category = "木雕漆器", rarity = 2, valueRange = {1200, 2800} },
    { name = "大漆鹿角椅",     category = "木雕漆器", rarity = 2, valueRange = {950, 2300} },
    { name = "紫檀百宝嵌屏",   category = "木雕漆器", rarity = 3, valueRange = {2500, 5000} },
    { name = "金漆彩绘屏风",   category = "木雕漆器", rarity = 3, valueRange = {3000, 5800} },
    { name = "黄花梨圈椅",     category = "木雕漆器", rarity = 3, valueRange = {3200, 6200} },
    { name = "象牙微雕",       category = "木雕漆器", rarity = 3, valueRange = {2800, 5500} },
    { name = "剔犀云纹盒",     category = "木雕漆器", rarity = 3, valueRange = {2600, 5200} },
    { name = "紫檀龙椅微缩",   category = "木雕漆器", rarity = 4, valueRange = {5500, 11000} },
    { name = "万工轿模型",     category = "木雕漆器", rarity = 4, valueRange = {6500, 13000} },
    { name = "乾隆御制漆盒",   category = "木雕漆器", rarity = 4, valueRange = {6000, 12000} },

    -- ================================================================
    -- 6. 珠宝首饰 (30 件)
    -- ================================================================
    { name = "珍珠耳坠",       category = "珠宝首饰", rarity = 1, valueRange = {200, 650} },
    { name = "玛瑙手链",       category = "珠宝首饰", rarity = 1, valueRange = {180, 580} },
    { name = "水晶杯",         category = "珠宝首饰", rarity = 1, valueRange = {220, 680} },
    { name = "银质胸针",       category = "珠宝首饰", rarity = 1, valueRange = {150, 500} },
    { name = "碧玺吊坠",       category = "珠宝首饰", rarity = 1, valueRange = {250, 720} },
    { name = "猫眼石戒指",     category = "珠宝首饰", rarity = 1, valueRange = {200, 640} },
    { name = "蜜蜡手串",       category = "珠宝首饰", rarity = 1, valueRange = {180, 600} },
    { name = "黑曜石吊坠",     category = "珠宝首饰", rarity = 1, valueRange = {160, 540} },
    { name = "琥珀项链",       category = "珠宝首饰", rarity = 2, valueRange = {900, 2200} },
    { name = "南红玛瑙镯",     category = "珠宝首饰", rarity = 2, valueRange = {1000, 2400} },
    { name = "蓝宝石耳环",     category = "珠宝首饰", rarity = 2, valueRange = {1100, 2600} },
    { name = "祖母绿吊坠",     category = "珠宝首饰", rarity = 2, valueRange = {1200, 2800} },
    { name = "红宝石胸针",     category = "珠宝首饰", rarity = 2, valueRange = {1050, 2500} },
    { name = "珊瑚珠串",       category = "珠宝首饰", rarity = 2, valueRange = {950, 2300} },
    { name = "金镶玉手镯",     category = "珠宝首饰", rarity = 2, valueRange = {1150, 2700} },
    { name = "红珊瑚摆件",     category = "珠宝首饰", rarity = 3, valueRange = {2800, 5500} },
    { name = "钻石胸花",       category = "珠宝首饰", rarity = 3, valueRange = {3200, 6200} },
    { name = "蓝宝石王冠",     category = "珠宝首饰", rarity = 3, valueRange = {3500, 6500} },
    { name = "金步摇",         category = "珠宝首饰", rarity = 3, valueRange = {2600, 5200} },
    { name = "东珠朝珠",       category = "珠宝首饰", rarity = 3, valueRange = {3000, 5800} },
    { name = "夜明珠",         category = "珠宝首饰", rarity = 4, valueRange = {5500, 11000} },
    { name = "鸽血红宝石项链", category = "珠宝首饰", rarity = 4, valueRange = {7000, 14000} },
    { name = "祖母绿皇冠",     category = "珠宝首饰", rarity = 4, valueRange = {6500, 13000} },

    -- ================================================================
    -- 7. 文房四宝 (30 件)
    -- ================================================================
    { name = "松烟墨锭",       category = "文房四宝", rarity = 1, valueRange = {120, 420} },
    { name = "端砚",           category = "文房四宝", rarity = 1, valueRange = {200, 650} },
    { name = "湖笔",           category = "文房四宝", rarity = 1, valueRange = {100, 380} },
    { name = "宣纸册",         category = "文房四宝", rarity = 1, valueRange = {140, 480} },
    { name = "石质印章",       category = "文房四宝", rarity = 1, valueRange = {160, 520} },
    { name = "铜质水盂",       category = "文房四宝", rarity = 1, valueRange = {180, 580} },
    { name = "紫砂壶",         category = "文房四宝", rarity = 1, valueRange = {250, 720} },
    { name = "镇纸",           category = "文房四宝", rarity = 1, valueRange = {140, 460} },
    { name = "歙砚",           category = "文房四宝", rarity = 2, valueRange = {800, 2000} },
    { name = "徽墨精品",       category = "文房四宝", rarity = 2, valueRange = {900, 2200} },
    { name = "鸡血石印章",     category = "文房四宝", rarity = 2, valueRange = {1100, 2600} },
    { name = "紫砂名壶",       category = "文房四宝", rarity = 2, valueRange = {1000, 2400} },
    { name = "青田石摆件",     category = "文房四宝", rarity = 2, valueRange = {850, 2100} },
    { name = "古琴配件",       category = "文房四宝", rarity = 2, valueRange = {950, 2300} },
    { name = "寿山石雕",       category = "文房四宝", rarity = 2, valueRange = {1050, 2500} },
    { name = "田黄石印",       category = "文房四宝", rarity = 3, valueRange = {3000, 6000} },
    { name = "龙尾砚",         category = "文房四宝", rarity = 3, valueRange = {2500, 5000} },
    { name = "古墨锭套装",     category = "文房四宝", rarity = 3, valueRange = {2800, 5500} },
    { name = "御题诗砚",       category = "文房四宝", rarity = 3, valueRange = {3200, 6200} },
    { name = "紫砂大师壶",     category = "文房四宝", rarity = 3, valueRange = {3500, 6500} },
    { name = "传国玉玺（仿）", category = "文房四宝", rarity = 4, valueRange = {6000, 12000} },
    { name = "兰亭砚",         category = "文房四宝", rarity = 4, valueRange = {5500, 11000} },
    { name = "御用文房套装",   category = "文房四宝", rarity = 4, valueRange = {7000, 14000} },

    -- ================================================================
    -- 8. 古钱币 (30 件)
    -- ================================================================
    { name = "清代铜钱",       category = "古钱币", rarity = 1, valueRange = {100, 380} },
    { name = "民国银毫",       category = "古钱币", rarity = 1, valueRange = {150, 500} },
    { name = "光绪通宝",       category = "古钱币", rarity = 1, valueRange = {120, 420} },
    { name = "宋代铁钱",       category = "古钱币", rarity = 1, valueRange = {140, 480} },
    { name = "清代制钱",       category = "古钱币", rarity = 1, valueRange = {100, 360} },
    { name = "咸丰重宝",       category = "古钱币", rarity = 1, valueRange = {180, 580} },
    { name = "开元通宝",       category = "古钱币", rarity = 1, valueRange = {160, 540} },
    { name = "乾隆通宝",       category = "古钱币", rarity = 1, valueRange = {130, 440} },
    { name = "袁大头银元",     category = "古钱币", rarity = 2, valueRange = {800, 2000} },
    { name = "大清银币",       category = "古钱币", rarity = 2, valueRange = {900, 2200} },
    { name = "光绪元宝",       category = "古钱币", rarity = 2, valueRange = {1000, 2400} },
    { name = "太平天国钱",     category = "古钱币", rarity = 2, valueRange = {850, 2100} },
    { name = "孙中山开国纪念币", category = "古钱币", rarity = 2, valueRange = {1100, 2600} },
    { name = "北宋折十钱",     category = "古钱币", rarity = 2, valueRange = {950, 2300} },
    { name = "金代铜钱",       category = "古钱币", rarity = 2, valueRange = {800, 1900} },
    { name = "战国刀币",       category = "古钱币", rarity = 3, valueRange = {2500, 5000} },
    { name = "王莽金错刀",     category = "古钱币", rarity = 3, valueRange = {3000, 5800} },
    { name = "靖康通宝",       category = "古钱币", rarity = 3, valueRange = {3200, 6200} },
    { name = "大齐通宝",       category = "古钱币", rarity = 3, valueRange = {2800, 5500} },
    { name = "至正之宝",       category = "古钱币", rarity = 3, valueRange = {2600, 5200} },
    { name = "大蜀通宝",       category = "古钱币", rarity = 4, valueRange = {5000, 10000} },
    { name = "皇宋通宝九叠篆", category = "古钱币", rarity = 4, valueRange = {6000, 12000} },
    { name = "咸丰大钱母钱",   category = "古钱币", rarity = 4, valueRange = {5500, 11000} },

    -- ================================================================
    -- 9. 织绣 (30 件)
    -- ================================================================
    { name = "棉布方巾",       category = "织绣", rarity = 1, valueRange = {100, 380} },
    { name = "丝绸香囊",       category = "织绣", rarity = 1, valueRange = {150, 500} },
    { name = "刺绣帕子",       category = "织绣", rarity = 1, valueRange = {120, 440} },
    { name = "织锦带",         category = "织绣", rarity = 1, valueRange = {140, 480} },
    { name = "绒花头饰",       category = "织绣", rarity = 1, valueRange = {160, 520} },
    { name = "绣花鞋垫",       category = "织绣", rarity = 1, valueRange = {100, 360} },
    { name = "缂丝扇套",       category = "织绣", rarity = 1, valueRange = {200, 620} },
    { name = "蜡染布片",       category = "织绣", rarity = 1, valueRange = {130, 460} },
    { name = "苏绣挂屏",       category = "织绣", rarity = 2, valueRange = {800, 2000} },
    { name = "蜀锦织品",       category = "织绣", rarity = 2, valueRange = {900, 2200} },
    { name = "湘绣花鸟",       category = "织绣", rarity = 2, valueRange = {850, 2100} },
    { name = "粤绣金线屏",     category = "织绣", rarity = 2, valueRange = {1000, 2400} },
    { name = "云锦段料",       category = "织绣", rarity = 2, valueRange = {1100, 2600} },
    { name = "缂丝小品",       category = "织绣", rarity = 2, valueRange = {1200, 2800} },
    { name = "盘金绣品",       category = "织绣", rarity = 2, valueRange = {950, 2300} },
    { name = "缂丝山水卷",     category = "织绣", rarity = 3, valueRange = {2500, 5000} },
    { name = "龙袍残片",       category = "织绣", rarity = 3, valueRange = {3000, 5800} },
    { name = "苏绣双面绣",     category = "织绣", rarity = 3, valueRange = {3200, 6200} },
    { name = "宫廷补子",       category = "织绣", rarity = 3, valueRange = {2800, 5500} },
    { name = "明代织金锦",     category = "织绣", rarity = 3, valueRange = {2600, 5200} },
    { name = "御制缂丝唐卡",   category = "织绣", rarity = 4, valueRange = {6000, 12000} },
    { name = "龙袍（复制品）",  category = "织绣", rarity = 4, valueRange = {5500, 11000} },
    { name = "缂丝百子图",     category = "织绣", rarity = 4, valueRange = {7000, 14000} },

    -- ================================================================
    -- 10. 杂项珍玩 (37 件 — 补足至 300 总数)
    -- ================================================================
    { name = "鼻烟壶",         category = "杂项珍玩", rarity = 1, valueRange = {150, 500} },
    { name = "铜铃",           category = "杂项珍玩", rarity = 1, valueRange = {100, 380} },
    { name = "陶俑",           category = "杂项珍玩", rarity = 1, valueRange = {180, 580} },
    { name = "石雕兽",         category = "杂项珍玩", rarity = 1, valueRange = {200, 620} },
    { name = "竹编提篮",       category = "杂项珍玩", rarity = 1, valueRange = {120, 420} },
    { name = "古扇",           category = "杂项珍玩", rarity = 1, valueRange = {160, 540} },
    { name = "景泰蓝小盒",     category = "杂项珍玩", rarity = 1, valueRange = {200, 650} },
    { name = "琉璃珠",         category = "杂项珍玩", rarity = 1, valueRange = {140, 480} },
    { name = "核雕手串",       category = "杂项珍玩", rarity = 1, valueRange = {180, 600} },
    { name = "葫芦器",         category = "杂项珍玩", rarity = 1, valueRange = {130, 460} },
    { name = "象牙扇",         category = "杂项珍玩", rarity = 2, valueRange = {900, 2200} },
    { name = "犀角杯",         category = "杂项珍玩", rarity = 2, valueRange = {1100, 2600} },
    { name = "琥珀雕件",       category = "杂项珍玩", rarity = 2, valueRange = {1000, 2400} },
    { name = "景泰蓝大瓶",     category = "杂项珍玩", rarity = 2, valueRange = {1200, 2800} },
    { name = "古琴",           category = "杂项珍玩", rarity = 2, valueRange = {1300, 2900} },
    { name = "铜胎画珐琅壶",   category = "杂项珍玩", rarity = 2, valueRange = {1000, 2400} },
    { name = "佛像铜牌",       category = "杂项珍玩", rarity = 2, valueRange = {850, 2100} },
    { name = "明代佛像",       category = "杂项珍玩", rarity = 3, valueRange = {3000, 5800} },
    { name = "西洋钟表",       category = "杂项珍玩", rarity = 3, valueRange = {2800, 5500} },
    { name = "清宫折扇",       category = "杂项珍玩", rarity = 3, valueRange = {2500, 5000} },
    { name = "唐代陶俑",       category = "杂项珍玩", rarity = 3, valueRange = {3200, 6200} },
    { name = "古琴名器",       category = "杂项珍玩", rarity = 3, valueRange = {3500, 6500} },
    { name = "编钟（微缩）",   category = "杂项珍玩", rarity = 4, valueRange = {5500, 11000} },
    { name = "九龙壁琉璃挂件", category = "杂项珍玩", rarity = 4, valueRange = {6000, 12000} },
    { name = "和氏璧（仿制）", category = "杂项珍玩", rarity = 4, valueRange = {7000, 14000} },
    -- 补充 4 件达到 300
    { name = "青铜面具",       category = "杂项珍玩", rarity = 3, valueRange = {2600, 5200} },
    { name = "骨雕菩萨像",     category = "杂项珍玩", rarity = 2, valueRange = {950, 2300} },
}

--- 所有分类名称（有序）
ItemData.Categories = {
    "瓷器", "玉石", "书画", "金属器", "木雕漆器",
    "珠宝首饰", "文房四宝", "古钱币", "织绣", "杂项珍玩",
}

return ItemData
