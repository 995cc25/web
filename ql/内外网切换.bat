@echo off
color 0a
:start

echo ==========================请输入数字内外网切换操作：
echo.
echo.
echo.
echo.
echo                                                              1开启外网并关闭内网
echo.
echo.
echo.
echo.
echo                                                              2打开内网并关闭外网
echo.
echo.
echo.
echo.
set /p var="----------------请输入对应号码切换内外网："

if %var%==1 goto waiwang
if %var%==2 goto neiwang


:waiwang
cls
netsh interface set interface "外网" enabled
netsh interface set interface "内网" disabled
echo.开启外网成功
echo&pause
exit


:neiwang
cls
netsh interface set interface "内网" enabled
netsh interface set interface "外网" disabled
echo.打开内网成功
echo&pause
exit





