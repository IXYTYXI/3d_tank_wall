@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title 钢铁战场 - 卸载
set "PACKAGE_DIR=%~dp0"
cd /d "%PACKAGE_DIR%" || exit /b 1
if not exist "SteelFront.package" goto invalid
findstr /x /c:"SteelFront portable package v1" "SteelFront.package" >nul || goto invalid
echo 钢铁战场便携版卸载器
echo 将删除以下目录中的游戏程序、资源、启动入口和随包说明：
echo "%PACKAGE_DIR%"
echo 不会删除目录外的其他版本或你自行放入的文件。
echo 第三方许可、用户目录中的日志和着色器缓存保留。请先退出游戏。
choice /C YN /N /M "确认卸载？[Y=卸载 / N=取消] "
if errorlevel 2 goto cancelled
if errorlevel 1 goto check_running
goto cancelled
:check_running
tasklist /FI "IMAGENAME eq SteelFront.exe" /NH 2>nul | findstr /I /C:"SteelFront.exe" >nul
if not errorlevel 1 goto running
for %%F in ("SteelFront.exe" "SteelFront.pck" "HighQuality.cmd" "安装与玩法说明.txt") do (
 if exist "%%~F" del /Q "%%~F"
)
for %%F in ("SteelFront.exe" "SteelFront.pck" "HighQuality.cmd" "安装与玩法说明.txt") do (
 if exist "%%~F" goto incomplete
)
if exist "SteelFront.package" del /Q "SteelFront.package"
echo 游戏程序和资源已卸载；剩余许可文件与文件夹可手动删除。
echo 按键后卸载器删除自身，其他文件保留。
pause
endlocal
del /Q "%~f0" & exit /b 0
:cancelled
echo 已取消，未删除游戏文件。
pause
exit /b 0
:running
echo 检测到游戏仍在运行，请退出游戏后重新运行卸载器。
pause
exit /b 1
:invalid
echo 无法确认游戏目录，已停止。请在完整解压目录内运行卸载器。
pause
exit /b 1
:incomplete
echo 部分文件被占用或无写入权限，请关闭游戏后重试。
echo 未删除其他文件，也未强制结束进程。
pause
exit /b 1
