@echo off
title ��������

:: --------------------------------------------------------------------------------
:: �������� ��ʼ ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: ��ȡ�����ļ�
for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (set %%i=%%j)

:: set ip=127.0.0.1
:: set user=root
:: :: �����в�֧�������ַ���<��>��|��&��^��%
:: set passwd=12345678
:: :: ����·�������·���Կո�ֿ���֧�ֻ�������
:: set search_path="/home/app1 ${APP2_HOME}"

:: --------------------------------------------------------------------------------
:: �������� ���� ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo ������Ϣ��
echo     Ip       ��%ip%
echo     User     ��%user%
echo     Password ��%passwd%
echo     ����·�� ��%search_path%

echo.
echo ��ȷ����Ϣ�Ƿ���ȷ���������ȷ����X�رմ��ڣ������������������. . .
pause
echo.

:: �����ͨ��
tools\plink.exe -pw %passwd% %user%@%ip% "date >/dev/null"
if %errorlevel% neq 0 (
    echo.
    echo ����ʧ�ܣ����������Ƿ���ȷ��
    pause
    exit
)

:: ��ʼʱ��
set start_time=%date% %time%

:: ��ȡ������ʱ��
for /f "delims=" %%i in ('tools\plink.exe -pw %passwd% %user%@%ip% "date +%%Y%%m%%d%%H%%M%%S"') do (set serverTime=%%i)

set backupPathServer=/tmp/replace_package_backup_%serverTime%
set backupPathLocal=package_backup\%ip%_backup_%serverTime%
echo ��ʾ���������ͬʱ�ڷ������ͱ��ؽ��б��ݡ�
echo ����������Ŀ¼Ϊ ��%backupPathServer%
echo ���ر���Ŀ¼Ϊ   ��%backupPathLocal%
echo.

:: ����Ŀ¼
tools\plink.exe -pw %passwd% %user%@%ip% "mkdir -p %backupPathServer%/new && mkdir -p %backupPathServer%/old"
mkdir %backupPathLocal%\new && mkdir %backupPathLocal%\old

echo =======================================================================
echo �ϴ����������
echo =======================================================================
tools\pscp.exe -pw %passwd% package_send\* %user%@%ip%:%backupPathServer%/new
copy package_send\* %backupPathLocal%\new >nul

tools\pscp.exe -pw %passwd% tools\replace_package.sh %user%@%ip%:%backupPathServer% >nul
copy tools\replace_package.sh %backupPathLocal% >nul
echo.

echo =======================================================================
echo ���Ҳ��滻�������
echo =======================================================================
tools\plink.exe -pw %passwd% %user%@%ip% "bash %backupPathServer%/replace_package.sh %search_path% | tee -a %backupPathServer%/replace_package.log"
echo.

echo =======================================================================
echo ���ؾ��������
echo =======================================================================
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/old/* %backupPathLocal%\old
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/*.txt %backupPathLocal% >nul
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathServer%/*.log %backupPathLocal% >nul
echo.

:: ����ʱ��
set end_time=%date% %time%

echo ��ϲ���ļ�ȫ���滻�ɹ���
echo.
echo ��ʼʱ�䣺%start_time%
echo ����ʱ�䣺%end_time%
echo.

pause
