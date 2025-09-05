@echo off
chcp 65001 >nul
title Frida HTTPS Capture Auto Installer
color 0A
:: 스크립트가 있는 폴더로 이동
cd /d "%~dp0"

:: 이제 여기가 작업 디렉토리
echo 현재 위치: %CD%

:: 로그 파일 생성
set LOG_FILE=frida_install_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set LOG_FILE=%LOG_FILE: =0%
echo 설치 시작: %date% %time% > %LOG_FILE%

echo ================================================
echo      Frida HTTPS 캡처 자동 설치 v2.4
echo           (로그 저장 버전)
echo ================================================
echo.
echo 로그 파일: %LOG_FILE%
echo.

:: 로그 기록 함수
goto :start
:log
echo %~1
echo [%time%] %~1 >> %LOG_FILE%
goto :eof
:start

:: 관리자 권한 확인
call :log "관리자 권한 확인 중..."
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :log "ERROR: 관리자 권한이 없습니다"
    echo [!] 관리자 권한이 필요합니다.
    echo     마우스 우클릭 - "관리자 권한으로 실행"
    pause
    exit /b
)
call :log "OK: 관리자 권한 확인됨"

:: 변수 설정
set FRIDA_VERSION=17.2.17
set ADB_PATH=C:\adb
set WORK_DIR=%CD%
call :log "작업 디렉토리: %WORK_DIR%"

:: ============ STEP 1: ADB 설치 ============
echo.
call :log "===== STEP 1/7: ADB 설치 확인 ====="
echo [1/7] ADB 설치 확인...
where adb >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ ADB 이미 설치됨
    call :log "ADB 이미 설치됨"
    for /f "tokens=*" %%i in ('adb version 2^>nul') do call :log "ADB 버전: %%i"
    goto :check_python
)

call :log "ADB 설치 시작..."
echo   ADB 설치 중...
powershell -Command "try { Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile '%TEMP%\adb.zip' -UseBasicParsing; Expand-Archive -Path '%TEMP%\adb.zip' -DestinationPath 'C:\' -Force; if (Test-Path 'C:\platform-tools') { Move-Item 'C:\platform-tools' '%ADB_PATH%' -Force } } catch { exit 1 }" >> %LOG_FILE% 2>&1

if %errorlevel% neq 0 (
    call :log "ERROR: ADB 다운로드 실패"
    echo   ✗ ADB 다운로드 실패. 인터넷 연결을 확인하세요.
    pause
    exit /b
)

setx PATH "%PATH%;%ADB_PATH%" /M >nul 2>&1
set PATH=%PATH%;%ADB_PATH%
echo   ✓ ADB 설치 완료
call :log "ADB 설치 완료"
echo.

:: ============ STEP 2: Python 확인 ============
:check_python
call :log "===== STEP 2/7: Python 확인 ====="
echo [2/7] Python 확인...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    call :log "ERROR: Python이 설치되지 않았습니다"
    echo   ✗ Python이 설치되지 않았습니다.
    echo.
    echo   다음 링크에서 Python을 설치하세요:
    echo   https://www.python.org/downloads/
    echo.
    echo   ※ 설치 시 "Add Python to PATH" 체크 필수!
    echo.
    pause
    exit /b
)
echo   ✓ Python 설치 확인
for /f "tokens=*" %%i in ('python --version 2^>nul') do call :log "Python 버전: %%i"
echo.

:: ============ STEP 3: Frida Tools 설치 ============
call :log "===== STEP 3/7: Frida Tools 설치 ====="
echo [3/7] Frida Tools 설치...
pip show frida-tools >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Frida Tools 이미 설치됨
    call :log "Frida Tools 이미 설치됨"
    for /f "tokens=*" %%i in ('frida --version 2^>nul') do call :log "Frida 버전: %%i"
) else (
    call :log "Frida Tools 설치 시작..."
    echo   설치 중...
    pip install frida-tools frida >> %LOG_FILE% 2>&1
    if %errorlevel% neq 0 (
        call :log "ERROR: Frida 설치 실패"
        echo   ✗ Frida 설치 실패
        pause
        exit /b
    )
    echo   ✓ Frida Tools 설치 완료
    call :log "Frida Tools 설치 완료"
)
echo.

:: ============ STEP 4: 디바이스 연결 확인 ============
call :log "===== STEP 4/7: Android 디바이스 확인 ====="
echo [4/7] Android 디바이스 확인...
adb devices >> %LOG_FILE% 2>&1
adb devices | findstr "device$" >nul
if %errorlevel% neq 0 (
    call :log "ERROR: Android 디바이스가 연결되지 않았습니다"
    echo   ✗ Android 디바이스가 연결되지 않았습니다.
    echo.
    echo   1. USB 디버깅을 활성화하세요
    echo   2. USB 케이블로 연결하세요
    echo   3. 폰에서 "이 컴퓨터를 항상 허용" 선택
    echo.
    pause
    exit /b
)

for /f "tokens=1" %%i in ('adb devices ^| findstr "device$"') do (
    set DEVICE_ID=%%i
    call :log "디바이스 연결됨: %%i"
)
echo   ✓ 디바이스 연결됨: %DEVICE_ID%

:: 루트 확인
call :log "루트 권한 확인 중..."
adb shell "su -c 'whoami'" >> %LOG_FILE% 2>&1
adb shell "su -c 'whoami'" 2>nul | findstr "root" >nul
if %errorlevel% neq 0 (
    echo   ! 루트 권한 미확인 (Magisk에서 허용 필요)
    call :log "WARNING: 루트 권한 미확인"
) else (
    echo   ✓ 루트 권한 확인됨
    call :log "OK: 루트 권한 확인됨"
)
echo.

:: ============ STEP 5: Frida Server 설치 ============
call :log "===== STEP 5/7: Frida Server 설치 ====="
echo [5/7] Frida Server 설치...

:: 아키텍처 확인
for /f "tokens=*" %%i in ('adb shell getprop ro.product.cpu.abi') do (
    set ARCH_FULL=%%i
    call :log "디바이스 아키텍처: %%i"
)
set ARCH_FULL=%ARCH_FULL: =%

if "%ARCH_FULL:~0,5%"=="arm64" (
    set ARCH=arm64
) else if "%ARCH_FULL:~0,3%"=="arm" (
    set ARCH=arm
) else (
    set ARCH=arm64
)
echo   아키텍처: %ARCH%
call :log "Frida 아키텍처: %ARCH%"

set SERVER_FILE=frida-server-%FRIDA_VERSION%-android-%ARCH%
call :log "서버 파일: %SERVER_FILE%"

:: 다운로드 확인
if exist "%SERVER_FILE%" (
    echo   ✓ Frida Server 이미 다운로드됨
    call :log "Frida Server 파일 존재함"
    goto :install_server
)

call :log "Frida Server 다운로드 시작..."
echo   다운로드 중...
set DOWNLOAD_URL=https://github.com/frida/frida/releases/download/%FRIDA_VERSION%/%SERVER_FILE%.xz
call :log "다운로드 URL: %DOWNLOAD_URL%"

powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%SERVER_FILE%.xz' -UseBasicParsing } catch { Write-Host $_.Exception.Message; exit 1 }" >> %LOG_FILE% 2>&1

if %errorlevel% neq 0 (
    call :log "ERROR: 다운로드 실패"
    echo   ✗ 다운로드 실패
    pause
    exit /b
)
call :log "다운로드 완료"

:: 압축 해제
call :log "압축 해제 시작..."
if exist "%ProgramFiles%\7-Zip\7z.exe" (
    "%ProgramFiles%\7-Zip\7z.exe" x "%SERVER_FILE%.xz" -y >> %LOG_FILE% 2>&1
    if %errorlevel% equ 0 (
        del "%SERVER_FILE%.xz"
        call :log "7-Zip으로 압축 해제 완료"
    )
) else if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" (
    "%ProgramFiles(x86)%\7-Zip\7z.exe" x "%SERVER_FILE%.xz" -y >> %LOG_FILE% 2>&1
    if %errorlevel% equ 0 (
        del "%SERVER_FILE%.xz"
        call :log "7-Zip(x86)으로 압축 해제 완료"
    )
) else (
    call :log "WARNING: 7-Zip이 없습니다"
    echo   ! 7-Zip이 없습니다. XZ 파일을 수동으로 압축 해제하세요.
    echo   파일: %SERVER_FILE%.xz
    pause
)

:install_server
:: 파일 확인
if not exist "%SERVER_FILE%" (
    call :log "ERROR: %SERVER_FILE% 파일이 없습니다"
    echo   ! %SERVER_FILE% 파일이 없습니다.
    echo   압축을 해제했는지 확인하세요.
    pause
    exit /b
)

for %%A in ("%SERVER_FILE%") do (
    set FILE_SIZE=%%~zA
    call :log "파일 크기: %%~zA bytes"
)
echo   파일 크기: %FILE_SIZE% bytes

:: 서버 설치
call :log "기존 프로세스 종료 중..."
echo   기존 프로세스 종료 중...
adb shell "su -c 'pkill -f frida-server'" >> %LOG_FILE% 2>&1
timeout /t 1 >nul

call :log "디바이스에 파일 전송 시작..."
echo   디바이스에 설치 중...

:: Push 시도
call :log "방법1: /sdcard 경유 전송"
adb push "%SERVER_FILE%" /sdcard/frida-server-temp >> %LOG_FILE% 2>&1
if %errorlevel% neq 0 (
    call :log "방법1 실패, 방법2 시도: 직접 전송"
    echo   ! Push 실패. 다시 시도 중...
    adb push "%SERVER_FILE%" /data/local/tmp/frida-server >> %LOG_FILE% 2>&1
    if %errorlevel% neq 0 (
        call :log "ERROR: 파일 전송 실패"
        echo   ✗ 파일 전송 실패
        echo   로그 파일을 확인하세요: %LOG_FILE%
        pause
        exit /b
    )
    call :log "직접 전송 성공"
) else (
    call :log "sdcard 전송 성공, 파일 이동 중..."
    echo   파일 이동 중...
    adb shell "su -c 'cp /sdcard/frida-server-temp /data/local/tmp/frida-server'" >> %LOG_FILE% 2>&1
    adb shell "rm /sdcard/frida-server-temp" >> %LOG_FILE% 2>&1
    call :log "파일 이동 완료"
)

call :log "권한 설정 중..."
echo   권한 설정 중...
adb shell "su -c 'chmod 755 /data/local/tmp/frida-server'" >> %LOG_FILE% 2>&1

call :log "서버 시작 중..."
echo   서버 시작 중...
adb shell "su -c 'nohup /data/local/tmp/frida-server > /dev/null 2>&1 &'" >> %LOG_FILE% 2>&1
timeout /t 3 >nul

call :log "포트 포워딩 설정 중..."
echo   포트 포워딩 설정...
adb forward tcp:27042 tcp:27042 >> %LOG_FILE% 2>&1

:: 프로세스 확인
call :log "프로세스 확인 중..."
adb shell "ps | grep frida-server" >> %LOG_FILE% 2>&1
adb shell "ps | grep frida-server" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Frida Server 실행 중
    call :log "OK: Frida Server 실행 중"
) else (
    echo   ! Frida Server 실행 확인 실패
    call :log "WARNING: Frida Server 실행 확인 실패"
    echo   수동으로 확인해보세요: adb shell ps ^| grep frida
)
echo.

if exist "https-capture.js" (
    echo   ✓ https-capture.js 생성 완료
    call :log "https-capture.js 생성 완료"
) else (
    call :log "ERROR: https-capture.js 생성 실패"
)

:: kakao.bat 생성 (카카오뱅크 전용 - 수동 실행 버전)
call :log "kakao.bat 생성 중..."
echo   kakao.bat 생성 중...
(
echo @echo off
echo chcp 65001 ^>nul
echo title 카카오뱅크 캡처
echo color 0E
echo.
echo echo 카카오뱅크 HTTPS 캡처
echo echo ======================
echo echo.
echo.
echo :: 초기화
echo echo [1] 초기화 중...
echo echo   ✓ 초기화 완료
echo echo.
echo.
echo :: 수동 서버 실행 안내
echo echo ┌───────────────────────────────────────┐
echo echo │  [2] 새 CMD 창에서 실행할 명령:       │
echo echo └───────────────────────────────────────┘
echo echo.
echo echo   adb shell
echo echo   su
echo echo   /data/local/tmp/frida-server
echo echo.
echo echo ─────────────────────────────────────────
echo echo.
echo echo 새 CMD 창에서 위 명령을 실행한 후 Enter...
echo pause ^>nul
echo echo.
echo.
echo :: 포트 포워딩
echo echo [3] 포트 설정 중...
echo adb forward tcp:27042 tcp:27042 2^>nul
echo echo   ✓ 포트 포워딩 완료
echo echo.
echo.
echo :: 연결 확인
echo echo [4] 연결 확인 중...
echo timeout /t 2 ^>nul
echo frida-ps -U ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo   ⚠ Frida 연결 실패!
echo     echo   새 터미널에서 frida-server 실행 확인
echo     pause
echo     exit /b
echo ^)
echo echo   ✓ 연결 성공
echo echo.
echo.
echo :: 카카오뱅크 자동 찾기
echo echo [5] 카카오뱅크 찾는 중...
echo for /f "tokens=1,2*" %%%%a in ^('frida-ps -U ^^^| findstr /i "카카오"'^) do ^(
echo     set PID=%%%%a
echo     set APP_NAME=%%%%b %%%%c
echo ^)
echo.
echo if "%%PID%%"=="" ^(
echo     echo   카카오뱅크가 실행되지 않았습니다.
echo     echo   앱을 실행한 후 다시 시도하세요.
echo     pause
echo     exit /b
echo ^)
echo.
echo echo   ✓ 발견: %%APP_NAME%% ^(PID: %%PID%%^)
echo echo.
echo echo [6] 캡처 시작... ^(종료: Ctrl+C^)
echo echo ════════════════════════════════════
echo echo.
echo frida -U -p %%PID%% -l https-capture.js
echo.
echo echo.
echo echo 캡처 종료됨
echo pause
) > kakao.bat

if exist "kakao.bat" (
    echo   ✓ kakao.bat 생성 완료
    call :log "kakao.bat 생성 완료"
)

echo   ✓ 모든 스크립트 생성 완료
echo     - https-capture.js
echo     - run.bat (일반 실행)
echo     - quick.bat (빠른 실행)
echo     - kakao.bat (카카오뱅크 전용)
echo.

:: ============ STEP 7: 테스트 ============
call :log "===== STEP 7/7: 연결 테스트 ====="
echo [7/7] 연결 테스트...
frida-ps -U >> %LOG_FILE% 2>&1
frida-ps -U 2>nul | findstr "PID" >nul
if %errorlevel% equ 0 (
    echo   ✓ Frida 정상 작동 확인!
    call :log "OK: Frida 정상 작동 확인"
) else (
    echo   ! Frida 연결 테스트 실패
    call :log "ERROR: Frida 연결 실패"
    echo   로그 파일을 확인하세요: %LOG_FILE%
)
echo.

:: ============ 완료 ============
call :log "===== 설치 완료 ====="
echo ================================================
echo           설치가 완료되었습니다!
echo ================================================
echo.
echo 로그 파일: %LOG_FILE%
echo.
echo 생성된 파일:
echo   • https-capture.js - HTTPS 트래픽 캡처 스크립트
echo   • run.bat - 일반 실행 (메뉴 방식)
echo   • quick.bat - 빠른 실행 (PID만 입력)
echo   • kakao.bat - 카카오뱅크 전용
echo.
echo 사용 방법:
echo   1. run.bat 실행 → PID 입력
echo   2. quick.bat 실행 → 빠른 캡처
echo   3. kakao.bat 실행 → 카카오뱅크 자동 캡처
echo.
pause