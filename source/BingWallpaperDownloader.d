/*****
Bing 每日壁纸下载器
    运行方式1（交互式）：直接双击运行，按提示输入参数
    运行方式2（命令行）：BingWallpaperDownloader.exe [天数] [分辨率]
        参数1(必填)：下载天数 1-8
        参数2(可选)：分辨率 1=1920x1080 2=4K(默认1)
    必含今日图片 | 文件名：日期-分辨率.jpg
    
编译：dmd source\BingWallpaperDownloader.d -O -release -inline -m64 -boundscheck=off -L/OPT:REF -L/OPT:ICF -of=.dub\BingWallpaperDownloader.exe
BingWallpaperDownloader.exe 同级目录下必须要有 libcurl.dll 文件("%DMD_HOME%\windows\bin64\libcurl.dll")

使用示例：
BingWallpaperDownloader.exe 3        → 下载3天，默认1080P
BingWallpaperDownloader.exe 5 2      → 下载5天，4K超清
******/

import std.conv: to, ConvException;
import std.file: exists, writeFile = write, mkdirRecurse;
import std.json: parseJSON, JSONValue;
import std.net.curl: get, HTTP, HTTPStatusException;
import std.path: buildPath;
import std.stdio: write, writeln, stdin;
import std.string: format, indexOf, toLower, strip;

immutable string SAVE_ROOT_DIR = "./BingWallpapers";
immutable string BING_API_BASE = "https://cn.bing.com/HPImageArchive.aspx?format=js&idx=%d&n=1&mkt=zh-CN";
immutable string BING_HOST = "https://cn.bing.com";

// 交互式输入整数：带提示、范围校验、默认值，输入错误自动重试
int promptInt(string prompt, int min, int max, int defaultValue)
{
    while(true)
    {
        write(prompt, " (默认 ", defaultValue, "): ");
        string input = stdin.readln().strip();
        
        // 直接回车用默认值
        if(input.length == 0)
        {
            return defaultValue;
        }

        try
        {
            int val = to!int(input);
            if(val >= min && val <= max)
            {
                return val;
            }
            writeln("[X] 请输入 ", min, " ~ ", max, " 之间的数字");
        }
        catch(ConvException e)
        {
            writeln("[X] 输入无效，请输入整数");
        }
    }
}

// 下载单张图片（idx=0今日）
void downloadSingleImage(int idx, string resolution)
{
    try
    {
        writeln("\n正在下载第 ", idx + 1, " 天的壁纸...");
        
        string api = format(BING_API_BASE, idx);
        string jsonResponse = cast(string)get(api);
        JSONValue json = parseJSON(jsonResponse);

        auto image = json["images"].array[0];
        string baseUrl = image["urlbase"].str;
        string startDate = image["startdate"].str;

        // 截断 & 符号，清除原有分辨率后缀
        size_t paramSplit = baseUrl.indexOf('&');
        if (paramSplit != -1) {
            baseUrl = baseUrl[0 .. paramSplit];
        }

        string formatDate = startDate[0..4] ~ "-" ~ startDate[4..6] ~ "-" ~ startDate[6..8];
        string imageUrl = BING_HOST ~ baseUrl ~ "_" ~ resolution ~ ".jpg";
        string fileName = formatDate ~ "-" ~ resolution.toLower() ~ ".jpg";
        string savePath = buildPath(SAVE_ROOT_DIR, fileName);

        ubyte[] data = tryDownload(baseUrl, resolution);
        writeFile(savePath, data);
        
        writeln("[O] ", fileName, " 下载成功\n");
    }
    catch (Exception e)
    {
        writeln("[X] 下载失败：", e.msg);
    }
}

/// 二进制下载图片，保证文件完整无损坏
ubyte[] downloadImage(string url) {
    writeln(url);
    return get!(HTTP, ubyte)(url);
}

/// 下载单张，增加404自动降级逻辑
ubyte[] tryDownload(string baseUrl, string resTag) {
    string fullUrl = BING_HOST ~ baseUrl ~ "_" ~ resTag ~ ".jpg";
    try {
        return downloadImage(fullUrl);
    } catch (HTTPStatusException e) {
        // 404 自动降级到1080P
        if(e.status == 404 && resTag != "1920x1080") {
            writeln("! 当前分辨率不存在，自动切换1080P");
            return downloadImage(BING_HOST ~ baseUrl ~ "_1920x1080.jpg");
        }
        throw e;
    }
}

// 主函数
void main(string[] args)
{
    version (Windows)
    {
        import core.sys.windows.windows;
    
        // 1. 保存当前控制台原始代码页（中文系统默认 936 GBK）
        auto originalOutputCP = GetConsoleOutputCP();
        
        // 2. 切换为 UTF-8 代码页，解决中文输出乱码与 stdio 写入异常
        SetConsoleOutputCP(65001);
        
        // 3. 作用域守卫：程序退出时（无论正常/异常）自动恢复原始代码页
        scope(exit) {
            SetConsoleOutputCP(originalOutputCP);
        }
    }
    
    writeln("\n=== Bing 每日壁纸下载器 ===");

    int days;
    int paramRes;

    // 参数过多校验
    if (args.length > 3)
    {
        writeln("\n使用方法: ");
        writeln("  bing_downloader.exe [下载天数] [分辨率(可选)]");
        writeln("    下载天数：1-8（必含今日图片）");
        writeln("    分辨率：1=1920x1080(默认)  2=4K(uhd)");
        writeln("示例1：bing_downloader.exe 3    (默认1080P)");
        writeln("示例2：bing_downloader.exe 5 2  (5天4K)");
        writeln("\n直接运行无参数可进入交互式选择");
        return;
    }

    try
    {
        if (args.length >= 2)
        {
            // 命令行参数模式
            days = to!int(args[1]);
            paramRes = args.length == 3 ? to!int(args[2]) : 1;
        }
        else
        {
            // 交互式选择模式
            writeln("\n--- 交互式配置 ---");
            days     = promptInt("输入天数(1-8)", 1, 8, 1);
            paramRes = promptInt("选择分辨率：1=1080P  2=4K", 1, 2, 1);
        }

        // 天数范围校验
        if (days < 1 || days > 8)
        {
            writeln("[X] 只能下载 1~8 天！");
            return;
        }

        // 分辨率映射
        string resolution;
        if (paramRes == 1)
            resolution = "1920x1080";
        else if (paramRes == 2)
            resolution = "UHD";
        else
        {
            writeln("[X] 分辨率只能输入 1 或 2！");
            return;
        }

        writeln("\n天数：", days,"天");
        writeln("目录：", SAVE_ROOT_DIR);
        writeln("分辨率：", resolution);
        writeln("----------------------------------------");

        if (!exists(SAVE_ROOT_DIR))
            mkdirRecurse(SAVE_ROOT_DIR);

        // 从今日开始下载
        for (int i = 0; i < days; i++)
        {
            downloadSingleImage(i, resolution);
        }

        writeln("[O] 全部下载完成！");
    }
    catch (ConvException e)
    {
        writeln("[X] 参数必须是整数！");
    }
    catch (Exception e)
    {
        writeln("[X] 程序错误：", e.msg);
    }
}
