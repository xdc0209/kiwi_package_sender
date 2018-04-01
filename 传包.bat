@echo off
title 传包工具

:: --------------------------------------------------------------------------------
:: 参数设置 开始 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: 读取配置文件
for /f "eol=# tokens=1,2 delims==" %%i in (传包-配置.ini) do (set %%i=%%j)

:: set ip=127.0.0.1
:: set user=root
:: :: 密码中不支持特殊字符：<、>、|、&、^、%
:: set passwd=12345678
:: :: 搜索路径，多个路径以空格分开，支持环境变量
:: set search_path="/home/app1 ${APP2_HOME}"

:: --------------------------------------------------------------------------------
:: 参数设置 结束 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo 配置信息：
echo     Ip       ：%ip%
echo     User     ：%user%
echo     Password ：%passwd%
echo     搜索路径 ：%search_path%

echo.
echo 请确认信息是否正确，如果不正确，点X关闭窗口！！！否则任意键继续. . .
pause
echo.

:: 检查连通性
tools\plink.exe -pw %passwd% %user%@%ip% "date >/dev/null"
if %errorlevel% neq 0 (
    echo.
    echo 连接失败，请检查配置是否正确。
    pause
    exit
)

:: 开始时间
set start_time=%date% %time%

:: 获取服务器时间
for /f "delims=" %%i in ('tools\plink.exe -pw %passwd% %user%@%ip% "date +%%Y%%m%%d%%H%%M%%S"') do (set serverTime=%%i)

set backupPathServer=/tmp/replace_package_backup_%serverTime%
set backupPathLocal=package_backup\%ip%_backup_%serverTime%
echo 提示：软件包将同时在服务器和本地进行备份。
echo 服务器备份目录为 ：%backupPathServer%
echo 本地备份目录为   ：%backupPathLocal%
echo.

:: 创建目录
tools\plink.exe -pw %passwd% %user%@%ip% "mkdir -p %backupPathServer%/new && mkdir -p %backupPathServer%/old"
mkdir %backupPathLocal%\new && mkdir %backupPathLocal%\old

echo =======================================================================
echo 上传新软件包：
echo =======================================================================
tools\pscp.exe -pw %passwd% package_send\* %user%@%ip%:%backupPathServer%/new
copy package_send\* %backupPathLocal%\new >nul

tools\pscp.exe -pw %passwd% tools\replace_package.sh %user%@%ip%:%backupPathServer% >nul
copy tools\replace_package.sh %backupPathLocal% >nul
echo.

echo =======================================================================
echo 查找并替换软件包：
echo =======================================================================
tools\plink.exe -pw %passwd% %user%@%ip% "bash %backupPathServer%/replace_package.sh %search_path% | tee -a %backupPathServer%/replace_package.log"
echo.

echo =======================================================================
echo 下载旧软件包：
echo =======================================================================
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/old/* %backupPathLocal%\old
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/*.txt %backupPathLocal% >nul
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/*.log %backupPathLocal% >nul
echo.

:: 结束时间
set end_time=%date% %time%

echo 恭喜，文件全部替换成功。
echo.
echo 开始时间：%start_time%
echo 结束时间：%end_time%
echo.

pause
