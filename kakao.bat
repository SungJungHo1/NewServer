@echo off
chcp 65001 >nul
title 카카오뱅크 캡처
color 0E

echo 카카오뱅크 HTTPS 캡처
echo ======================
echo.

:: 초기화
echo   ✓ 초기화 완료
echo.

:: 수동 서버 실행 안내
echo ┌───────────────────────────────────────┐
echo.
echo   adb shell
echo   su
echo   /data/local/tmp/frida-server
echo.
echo ─────────────────────────────────────────
echo.
echo 새 CMD 창에서 위 명령을 실행한 후 Enter...
pause >nul
echo.

:: 포트 포워딩
adb forward tcp:27042 tcp:27042 2>nul
echo   ✓ 포트 포워딩 완료
echo.

:: 연결 확인
echo [4] 연결 확인 중...
timeout /t 2 >nul
frida-ps -U >nul 2>&1
if %errorlevel% neq 0 (
    echo   ⚠ Frida 연결 실패!
    echo   새 터미널에서 frida-server 실행 확인
    pause
    exit /b
)
echo   ✓ 연결 성공
echo.

:: 카카오뱅크 자동 찾기
echo [5] 카카오뱅크 찾는 중...
for /f "tokens=1,2*" %%a in ('frida-ps -U ^| findstr /i "카카오"') do (
    set PID=%%a
    set APP_NAME=%%b %%c
)

if "%PID%"=="" (
    echo   카카오뱅크가 실행되지 않았습니다.
    echo   앱을 실행한 후 다시 시도하세요.
    pause
    exit /b
)

echo   ✓ 발견: %APP_NAME% (PID: %PID%)
echo.
echo [6] 캡처 시작... (종료: Ctrl+C)
echo ════════════════════════════════════
echo.
frida -U -p %PID% -l https-capture.js

echo.
echo 캡처 종료됨
pause
