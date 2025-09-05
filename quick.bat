@echo off
chcp 65001 >nul
color 0A

:: 서버 시작 (백그라운드)
start /B adb shell "su -c 'pkill -f frida-server'" 2>nul
start /B adb shell "su -c '/data/local/tmp/frida-server ^&'" 2>nul
timeout /t 2 >nul
adb forward tcp:27042 tcp:27042 2>nul
cls

:: 간단한 앱 목록
echo ===== 주요 앱 목록 =====
frida-ps -U | findstr /i "kakao toss naver coupang"
echo =========================
echo.

:: PID 입력 및 실행
set /p PID="PID: "
if "%PID%"=="" exit
frida -U -p %PID% -l https-capture.js
