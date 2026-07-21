# BingWallpaperDownloader

## Bing 每日壁纸下载器
    运行方式1（交互式）：直接双击运行，按提示输入参数
    运行方式2（命令行）：BingWallpaperDownloader.exe [天数] [分辨率]
        参数1(必填)：下载天数 1-8
        参数2(可选)：分辨率 1=1920x1080 2=4K(默认1)
        文件名     ：日期-分辨率.jpg 必含今日图片
    
## 编译：
```
dub -b release

or

dmd source\BingWallpaperDownloader.d -O -release -inline -m64 -boundscheck=off -L/OPT:REF -L/OPT:ICF -of=.dub\BingWallpaperDownloader.exe
```

BingWallpaperDownloader.exe 同级目录下必须要有 libcurl.dll 文件("%DMD_HOME%\windows\bin64\libcurl.dll")

使用示例：
```
BingWallpaperDownloader.exe 3        → 下载3天，默认1080P
BingWallpaperDownloader.exe 5 2      → 下载5天，4K超清
```
