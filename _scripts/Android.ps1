# Android.ps1 - Android 工具集

# APK 混淆信息检测
function appinfo {
    param([Parameter(Mandatory)][string]$Path)
    python "D:\SecTools\AppTools\apphide\appinfo\appinfo.py" $Path
}
