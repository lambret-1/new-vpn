//
//  分流规则导入预设.swift
//  NewVPN
//
//  精简版国内外分流规则：常用域名 + IP段
//  注意：douyin.com 是国内抖音（直连），tiktok.com 是国外TikTok（代理），请勿混淆
//

import Foundation

extension 预设规则集 {

    // MARK: - 国内直连（域名后缀）
    private static let _直连_suffix: [String] = [
        // 中国国家域名
        "cn", "com.cn", "net.cn", "org.cn", "gov.cn", "edu.cn", "ac.cn",
        // 百度
        "baidu.com", "baidubcr.com", "baidupan.com", "baidupcs.com", "baidustatic.com", "bdimg.com", "bdstatic.com", "bcebos.com", "baidubce.com",
        // 阿里/淘宝
        "alibaba.com", "alibabacloud.com", "alicdn.com", "aliimg.com", "alipay.com", "alipayobjects.com", "aliyun.com", "aliyuncs.com", "aliyundrive.com", "taobao.com", "tmall.com", "jd.com", "jd.hk", "1688.com", "aliexpress.com",
        // 腾讯/微信/QQ
        "qq.com", "tencent.com", "tencent-cloud.com", "weixin.qq.com", "wx.qq.com", "qpic.cn", "gtimg.cn", "gtimg.com", "myapp.com", "qqmail.com", "foxmail.com",
        // 字节跳动（国内）
        "bytedance.com", "bytedance.net", "douyin.com", "douyinpic.com", "douyinvod.com", "douyinstatic.com", "amemv.com", "iesdouyin.com", "pstatp.com", "snssdk.com", "toutiao.com", "feiliao.com",
        // 快手
        "kuaishou.com", "kuaishouzt.com", "gifshow.com", "ksyun.com",
        // 小红书
        "xiaohongshu.com", "xhscdn.com", "qiniu.com",
        // 美团/点评
        "meituan.com", "meituan.net", "dianping.com", "dpfile.com",
        // 网易
        "163.com", "126.com", "163yun.com", "163.net", "127.net", "netease.com", "163img.com",
        // 新浪/搜狐/凤凰
        "sina.com", "sina.com.cn", "sinaimg.cn", "sinaimg.com", "sohu.com", "sohu.com.cn", "ifeng.com", "thepaper.cn",
        // 微博/知乎/B站
        "weibo.com", "weibocdn.com", "zhihu.com", "zhimg.com", "bilibili.com", "bilibili.cn", "biliapi.com", "biliapi.net", "hdslb.com", "acfun.cn", "acfun.com",
        // 地图/出行
        "amap.com", "autonavi.com", "baidu.cn", "ctrip.com", "qunar.com", "qunarzz.com", "meituan.com", "didi.cn", "xiaojukeji.com", "mobike.com", "ofo.com",
        // 银行/金融
        "icbc.com.cn", "ccb.com", "boc.cn", "abchina.com", "cmbchina.com", "bankcomm.com", "spdb.com.cn", "citicbank.com", "cebbank.com", "psbc.com", "hxb.com.cn", "cgbchina.com.cn", "cib.com.cn", "eastmoney.com", "10jqka.com.cn", "hexun.com", "jrj.com.cn", "cnstock.com", "stcn.com", "xueqiu.com", "sinafinance.com",
        // 运营商
        "10086.cn", "chinamobile.com", "189.cn", "chinatelecom.cn", "10010.com", "chinaunicom.cn",
        // 手机厂商
        "huawei.com", "huaweicloud.com", "xiaomi.com", "mi.com", "oppo.com", "vivo.com.cn", "vivo.com", "oneplus.com", "meizu.com", "smartisan.com",
        // 办公/协作
        "dingtalk.com", "dingtalk.net", "feishu.cn", "feishu.net", "larksuite.com", "bytedance.com", "wps.cn", "wps.com", "kdocs.cn", "yuque.com",
        // 技术/开发者
        "csdn.net", "csdnimg.cn", "jianshu.com", "jianshu.io", "cnblogs.com", "oschina.net", "gitee.com", "coding.net", "cn.aliyun.com", "tencent-cloud.com", "huaweicloud.com", "qiniu.com", "upyun.com", "又拍云.com",
        // 新闻/资讯
        "xinhuanet.com", "people.com.cn", "chinadaily.com.cn", "caijing.com.cn", "yicai.com", "caixin.com", "36kr.com", "huxiu.com", "tmtpost.com", "leiphone.com", "ithome.com", "cnbeta.com.tw",
        // 视频/音乐
        "iqiyi.com", "iqiyipic.com", "youku.com", "tudou.com", "mgtv.com", "mgtv.com.cn", "pptv.com", "le.com", "letv.com", "xiami.com", "kuwo.cn", "kugou.com", "music.163.com", "qqmusic.qq.com", "y.qq.com",
        // 生活/工具
        "58.com", "ganji.com", "lianjia.com", "ke.com", "anjuke.com", "fang.com", "soufun.com", "zhaopin.com", "51job.com", "liepin.com", "bosszhipin.com", "lagou.com", "mafengwo.cn", "qyer.com", "12306.cn", "95516.com", "umeng.com", "umengcloud.com",
        // 其他常用
        "360.com", "360.cn", "360safe.com", "360buyimg.com", "hao123.com", "2345.com", "114la.com", "4399.com", "7k7k.com", "17173.com", "duowan.com", "yy.com", "huanqiu.com", "guancha.cn", "tiexue.net", "maopu.com", "tianya.cn", "douban.com", "dbcache.com",
    ]

    // MARK: - 国内直连（精确域名）
    private static let _直连_domain: [String] = [
        "www.baidu.com",
        "www.taobao.com",
        "www.jd.com",
        "www.qq.com",
        "www.163.com",
        "www.weibo.com",
        "www.zhihu.com",
        "www.bilibili.com",
        "www.douyin.com",
        "www.kuaishou.com",
        "www.xiaohongshu.com",
        "www.meituan.com",
        "www.dianping.com",
        "www.amap.com",
        "www.aliyun.com",
        "www.tencent.com",
        "www.huawei.com",
        "www.mi.com",
        "www.12306.cn",
        "www.icbc.com.cn",
        "www.ccb.com",
        "ditu.amap.com",
        "map.baidu.com",
        "pan.baidu.com",
        "mail.163.com",
        "mail.qq.com",
    ]

    // MARK: - 国内直连（关键词）
    private static let _直连_keyword: [String] = [
        "baidu",
        "taobao",
        "tmall",
        "jd.com",
        "qq.com",
        "weixin",
        "alipay",
        "douyin",
        "bytedance",
        "kuaishou",
        "meituan",
        "dianping",
        "bilibili",
        "zhihu",
        "weibo",
        "163.com",
        "aliyun",
        "tencent",
        "huawei",
        "xiaomi",
        "amap",
        "12306",
    ]

    // MARK: - 国内直连（IP段）
    private static let _直连_cidr: [String] = [
        // 内网/保留地址
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "100.64.0.0/10",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "224.0.0.0/4",
        "240.0.0.0/4",
        // 国内公共DNS
        "223.5.5.5/32",
        "223.6.6.6/32",
        "114.114.114.114/32",
        "114.114.115.115/32",
        "119.29.29.29/32",
        "180.76.76.76/32",
    ]

    // MARK: - 国外代理（域名后缀）
    private static let _代理_suffix: [String] = [
        // Google 全家桶
        "google.com", "google.co.jp", "google.co.uk", "google.co.hk", "google.com.hk", "googleapis.com", "gstatic.com", "googleusercontent.com", "googlevideo.com", "ytimg.com", "ggpht.com", "gvt1.com", "gvt2.com", "g.co", "goo.gl", "1e100.net", "google.dev", "googleanalytics.com", "googletagmanager.com", "googlesyndication.com", "googleadservices.com", "doubleclick.net", "admob.com", "firebase.google.com", "firebaseio.com", "googlezip.net",
        // YouTube
        "youtube.com", "youtu.be", "youtube-nocookie.com", "youtubei.googleapis.com", "youtube.googleapis.com", "yt3.ggpht.com",
        // 社交媒体
        "facebook.com", "fb.com", "fbcdn.net", "facebook.net", "instagram.com", "cdninstagram.com", "twitter.com", "x.com", "t.co", "twimg.com", "twitpic.com", "periscope.tv", "pscp.tv", "tweetdeck.com", "threads.net", "blueskyweb.xyz", "bsky.app", "bsky.social", "mastodon.social", "reddit.com", "redditmedia.com", "redd.it", "pinterest.com", "pinimg.com", "tumblr.com", "tumblr.co", "linkedin.com", "licdn.com", "medium.com", "substack.com", "quora.com", "qph.cf2.quoracdn.net",
        // Telegram
        "telegram.org", "t.me", "telegram.me", "telegram.dog", "telegra.ph", "telesco.pe", "telegram-cdn.org", "cdn-telegram.org", "tdesktop.com", "tx.me", "telega.one", "fragment.com", "graph.org", "tg.dev",
        // TikTok（国外版，注意与国内抖音douyin.com区分）
        "tiktok.com", "tiktokcdn.com", "tiktokcdn-us.com", "tiktokcdn-eu.com", "tiktokv.com", "tiktokv.us", "tiktokv.eu", "tiktokd.net", "tiktokd.org", "tik-tokapi.com", "tiktokmusic.app", "tiktokshop.com", "tiktokglobalshop.com", "byteoversea.com", "ibyteimg.com", "ibytedtos.com", "muscdn.com", "musical.ly", "tiktokrow.net", "ttwebview.com",
        // 视频/流媒体
        "netflix.com", "nflxvideo.net", "nflxso.net", "nflxext.com", "disney.com", "disneyplus.com", "hulu.com", "huluim.com", "primevideo.com", "amazonvideo.com", "hbo.com", "hbomax.com", "max.com", "spotify.com", "scdn.co", "spotifycdn.net", "soundcloud.com", "sndcdn.com", "applemusic.com", "music.apple.com", "twitch.tv", "ttvnw.net", "vimeo.com", "vimeocdn.com", "dailymotion.com",
        // 开发者/技术
        "github.com", "github.io", "githubusercontent.com", "githubassets.com", "githubapp.com", "githubstatus.com", "github.dev", "ghcr.io", "gist.github.com", "codeload.github.com", "raw.githubusercontent.com", "avatars.githubusercontent.com", "objects.githubusercontent.com", "github.blog", "github.community", "githubpreview.dev", "gitlab.com", "gitlab.io", "stackoverflow.com", "stackexchange.com", "superuser.com", "serverfault.com", "npmjs.com", "npmjs.org", "unpkg.com", "jsdelivr.net", "jsdelivr.com", "pypi.org", "python.org", "pypi.io", "docker.com", "docker.io", "hub.docker.com", "k8s.io", "kubernetes.io", "terraform.io", "ansible.com",
        // AI/ChatGPT
        "openai.com", "chat.openai.com", "chatgpt.com", "oaistatic.com", "oaiusercontent.com", "oaistatsig.com", "sora.com", "anthropic.com", "claude.ai", "gemini.google.com", "bard.google.com", "ai.google.dev", "aistudio.google.com", "generativelanguage.googleapis.com", "huggingface.co", "hf.co", "replicate.com", "stability.ai", "midjourney.com", "runwayml.com", "pika.art", "cursor.com", "copilot.microsoft.com", "githubcopilot.com",
        // 电商
        "amazon.com", "amazon.co.jp", "amazon.co.uk", "amazon.de", "amazonaws.com", "cloudfront.net", "ebay.com", "ebayimg.com", "shopify.com", "myshopify.com", "shopifycdn.com", "etsy.com", "etsystatic.com", "aliexpress.com", "wish.com", "shein.com", "sheinside.com", "temu.com",
        // 云服务/CDN
        "cloudflare.com", "cloudflare.net", "workers.dev", "cloudflareapps.com", "cloudflareinsights.com", "cf-ipfs.com", "cf-tic.com", "cdn77.com", "fastly.net", "akamai.net", "akamaihd.net", "akamaized.net", "limelight.com", "verizon.com", "digitalocean.com", "linode.com", "vultr.com", "aws.amazon.com", "azure.com", "microsoftonline.com",
        // 通讯/协作
        "discord.com", "discordapp.com", "discord.media", "discordapp.net", "slack.com", "slack-edge.com", "zoom.us", "zoom.com.cn", "teams.microsoft.com", "skype.com", "whatsapp.com", "whatsapp.net", "signal.org", "wire.com", "keybase.io", "proton.me", "protonmail.com", "protonvpn.com", "tutanota.com",
        // 苹果（国外服务）
        "icloud.com", "icloud-content.com", "apple.com", "apple-cloudkit.com", "cdn-apple.com", "mzstatic.com", "itunes.com", "itunes.apple.com", "apps.apple.com", "developer.apple.com", "testflight.apple.com",
        // 维基/百科
        "wikipedia.org", "wikimedia.org", "wikiquote.org", "wiktionary.org", "wikibooks.org", "wikinews.org", "wikisource.org", "wikiversity.org", "wikivoyage.org", "mediawiki.org",
        // 设计/创意
        "figma.com", "figma.net", "dribbble.com", "dribbblers.com", "behance.net", "adobe.com", "adobe.io", "canva.com", "notion.so", "notion.site", "obsidian.md",
        // 搜索/工具
        "duckduckgo.com", "ddg.gg", "bing.com", "bing.net", "msn.com", "yahoo.com", "yandex.com", "yandex.ru", "brave.com", "search.brave.com", "startpage.com",
        // 游戏/平台
        "steampowered.com", "steamcommunity.com", "steamgames.com", "steamcontent.com", "epicgames.com", "unrealengine.com", "unity.com", "ea.com", "blizzard.com", "battle.net", "riotgames.com", "playstation.com", "xbox.com", "nintendo.com",
        // 其他
        "wordpress.com", "wordpress.org", "blogspot.com", "blogger.com", "wix.com", "squarespace.com", "weebly.com", "godaddy.com", "namecheap.com", "cloudflare.com", "wikipedia.org", "archive.org", "web.archive.org", "v2ray.com", "v2rayng.com", "clash-lang.org", "sing-box.app", "shadowsocks.org", "wireguard.com", "openvpn.net",
    ]

    // MARK: - 国外代理（精确域名）
    private static let _代理_domain: [String] = [
        "www.google.com",
        "www.youtube.com",
        "www.facebook.com",
        "www.twitter.com",
        "x.com",
        "www.instagram.com",
        "www.reddit.com",
        "www.tiktok.com",
        "www.netflix.com",
        "www.github.com",
        "chat.openai.com",
        "chatgpt.com",
        "www.wikipedia.org",
        "www.linkedin.com",
        "www.pinterest.com",
        "www.tumblr.com",
        "www.quora.com",
        "www.medium.com",
        "www.spotify.com",
        "www.soundcloud.com",
        "www.twitch.tv",
        "www.vimeo.com",
        "www.disneyplus.com",
        "www.hulu.com",
        "www.primevideo.com",
        "www.amazon.com",
        "www.ebay.com",
        "www.shopify.com",
        "www.icloud.com",
        "www.apple.com",
        "www.cloudflare.com",
        "www.discord.com",
        "www.slack.com",
        "www.zoom.us",
        "www.whatsapp.com",
        "web.telegram.org",
        "www.notion.so",
        "www.figma.com",
        "www.adobe.com",
        "www.stackoverflow.com",
        "www.npmjs.com",
        "pypi.org",
        "hub.docker.com",
        "store.steampowered.com",
        "www.epicgames.com",
        "play.google.com",
        "mail.google.com",
        "drive.google.com",
        "maps.google.com",
        "translate.google.com",
        "gemini.google.com",
        "bard.google.com",
        "www.bing.com",
        "duckduckgo.com",
        "search.brave.com",
        "www.yahoo.com",
        "www.wordpress.com",
        "www.blogspot.com",
        "www.archive.org",
        "v2ray.com",
        "sing-box.app",
    ]

    // MARK: - 国外代理（关键词）
    private static let _代理_keyword: [String] = [
        "google",
        "youtube",
        "facebook",
        "twitter",
        "instagram",
        "reddit",
        "tiktok",
        "netflix",
        "github",
        "gitlab",
        "stackoverflow",
        "openai",
        "chatgpt",
        "anthropic",
        "claude",
        "gemini",
        "telegram",
        "discord",
        "slack",
        "whatsapp",
        "spotify",
        "twitch",
        "disney",
        "hulu",
        "amazon",
        "cloudflare",
        "docker",
        "kubernetes",
        "npmjs",
        "pypi",
        "wikipedia",
        "linkedin",
        "pinterest",
        "tumblr",
        "quora",
        "medium",
        "substack",
        "figma",
        "notion",
        "adobe",
        "steam",
        "epicgames",
        "playstation",
        "xbox",
        "nintendo",
        "v2ray",
        "clash",
        "sing-box",
        "shadowsocks",
        "wireguard",
        "openvpn",
        "proton",
        "signal",
        "zoom",
        "teams",
        "skype",
        "apple",
        "icloud",
        "itunes",
        "appstore",
        "testflight",
        "microsoft",
        "azure",
        "office365",
        "outlook",
        "hotmail",
        "bing",
        "duckduckgo",
        "brave",
        "yahoo",
        "yandex",
        "wordpress",
        "blogspot",
        "blogger",
        "godaddy",
        "namecheap",
        "archive",
        "huggingface",
        "replicate",
        "stability",
        "midjourney",
        "runway",
        "pika",
        "cursor",
        "copilot",
    ]

    // MARK: - 国外代理（IP段）
    private static let _代理_cidr: [String] = [
        // Google / YouTube
        "8.8.8.8/32",
        "8.8.4.4/32",
        "1.1.1.1/32",
        "1.0.0.1/32",
        // Cloudflare
        "104.16.0.0/12",
        "172.64.0.0/13",
        "162.158.0.0/15",
        "198.41.128.0/17",
        "141.101.64.0/18",
        "108.162.192.0/18",
    ]

    // MARK: - 广告拦截（精简版）
    private static let _广告_suffix: [String] = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "googletagmanager.com",
        "google-analytics.com",
        "facebook.net",
        "fbcdn.net",
        "scorecardresearch.com",
        "quantserve.com",
        "adnxs.com",
        "criteo.com",
        "taboola.com",
        "outbrain.com",
        "pubmatic.com",
        "rubiconproject.com",
        "openx.net",
        "appsflyer.com",
        "adjust.com",
        "kochava.com",
        "talkingdata.com",
        "umeng.com",
        "umengcloud.com",
        "cnzz.com",
        "51.la",
        "51yes.com",
        "51jobcdn.com",
    ]

    private static let _广告_domain: [String] = []
    private static let _广告_keyword: [String] = ["adservice", "advertising", "tracker", "tracking", "analytics", "beacon", "pixel", "telemetry"]
    private static let _广告_cidr: [String] = []

    // MARK: - 构造规则
    private static func 构造导入规则(动作: 分流动作, 后缀: [String], 精确: [String], 关键词: [String], 网段: [String], 起始优先级: Int) -> [分流规则项] {
        var 列表: [分流规则项] = []
        var p = 起始优先级
        for v in 后缀 { 列表.append(分流规则项(名称: "精简-后缀-\(v)", 类型: .域名后缀, 匹配值: v, 动作: 动作, 优先级: p)); p += 1 }
        for v in 精确 { 列表.append(分流规则项(名称: "精简-域名-\(v)", 类型: .域名精确, 匹配值: v, 动作: 动作, 优先级: p)); p += 1 }
        for v in 关键词 { 列表.append(分流规则项(名称: "精简-关键词-\(v)", 类型: .域名关键词, 匹配值: v, 动作: 动作, 优先级: p)); p += 1 }
        for v in 网段 { 列表.append(分流规则项(名称: "精简-网段-\(v)", 类型: .IP段, 匹配值: v, 动作: 动作, 优先级: p)); p += 1 }
        return 列表
    }

    // MARK: - 预设规则集
    static let 导入·直连规则 = 预设规则集(
        名称: "精简·国内直连",
        描述: "国内常用域名和IP段，走直连（含国内抖音douyin.com）",
        图标: "network",
        规则列表: 构造导入规则(动作: .直连, 后缀: _直连_suffix, 精确: _直连_domain, 关键词: _直连_keyword, 网段: _直连_cidr, 起始优先级: 10)
    )

    static let 导入·广告拦截 = 预设规则集(
        名称: "精简·广告拦截",
        描述: "常见广告与追踪域名拦截",
        图标: "hand.raised",
        规则列表: 构造导入规则(动作: .拦截, 后缀: _广告_suffix, 精确: _广告_domain, 关键词: _广告_keyword, 网段: _广告_cidr, 起始优先级: 500)
    )

    static let 导入·代理规则 = 预设规则集(
        名称: "精简·国外代理",
        描述: "国外常用域名和IP段，走代理（含国外TikTok tiktok.com，与国内抖音区分）",
        图标: "paperplane",
        规则列表: 构造导入规则(动作: .代理, 后缀: _代理_suffix, 精确: _代理_domain, 关键词: _代理_keyword, 网段: _代理_cidr, 起始优先级: 2000)
    )

    /// 导入的预设规则集（追加到内置预设之后）
    static let 全部导入预设: [预设规则集] = [
        .导入·直连规则,
        .导入·广告拦截,
        .导入·代理规则,
    ]
}
