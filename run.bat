@echo off
chcp 65001 >nul
title Frida HTTPS Capture
color 0B

echo ========================================
echo        Frida HTTPS Capture Tool
echo ========================================
echo.

:: Frida 서버 시작
echo [1] Frida 서버 시작 중...
start /B adb shell "su -c 'pkill -f frida-server'" 2>nul
timeout /t 1 >nul
start /B adb shell "su -c '/data/local/tmp/frida-server ^&'" 2>nul
timeout /t 3 >nul
adb forward tcp:27042 tcp:27042 2>nul
echo     ✓ 서버 시작 완료
echo.

:: 프로세스 목록
echo [2] 실행 중인 앱 목록:
echo ----------------------------------------
frida-ps -U
echo ----------------------------------------
echo.

:: PID 입력
set /p PID="[3] 캡처할 PID 입력: "

if "%PID%"=="" (
    echo PID를 입력하지 않았습니다.
    pause
    exit /b
)

echo.
echo [4] 캡처 시작 (종료: Ctrl+C)
echo ========================================
echo.

:: 캡처 실행
frida -U -p %PID% -l https-capture.js

echo.
echo 캡처 종료됨
pause
