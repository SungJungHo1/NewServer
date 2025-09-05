@echo off
chcp 65001 >nul
title Frida HTTPS Capture Auto Installer
color 0A

echo ================================================
echo      Frida HTTPS 캡처 자동 설치 v2.0
echo ================================================
echo.

:: 관리자 권한 확인
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] 관리자 권한이 필요합니다.
    echo     마우스 우클릭 - "관리자 권한으로 실행"
    pause
    exit /b
)

:: 변수 설정
set FRIDA_VERSION=17.2.17
set ADB_PATH=C:\adb
set WORK_DIR=%CD%

:: ============ STEP 1: ADB 설치 ============
echo [1/7] ADB 설치 확인...
where adb >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ ADB 이미 설치됨
    goto :check_python
)

echo   ADB 설치 중...
powershell -Command "try { Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile '%TEMP%\adb.zip' -UseBasicParsing; Expand-Archive -Path '%TEMP%\adb.zip' -DestinationPath 'C:\' -Force; if (Test-Path 'C:\platform-tools') { Move-Item 'C:\platform-tools' '%ADB_PATH%' -Force } } catch { exit 1 }"

if %errorlevel% neq 0 (
    echo   ✗ ADB 다운로드 실패. 인터넷 연결을 확인하세요.
    pause
    exit /b
)

setx PATH "%PATH%;%ADB_PATH%" /M >nul 2>&1
set PATH=%PATH%;%ADB_PATH%
echo   ✓ ADB 설치 완료
echo.

:: ============ STEP 2: Python 확인 ============
:check_python
echo [2/7] Python 확인...
python --version >nul 2>&1
if %errorlevel% neq 0 (
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
echo.

:: ============ STEP 3: Frida Tools 설치 ============
echo [3/7] Frida Tools 설치...
pip show frida-tools >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Frida Tools 이미 설치됨
) else (
    echo   설치 중...
    pip install frida-tools frida >nul 2>&1
    if %errorlevel% neq 0 (
        echo   ✗ Frida 설치 실패
        pause
        exit /b
    )
    echo   ✓ Frida Tools 설치 완료
)
echo.

:: ============ STEP 4: 디바이스 연결 확인 ============
echo [4/7] Android 디바이스 확인...
adb devices | findstr "device$" >nul
if %errorlevel% neq 0 (
    echo   ✗ Android 디바이스가 연결되지 않았습니다.
    echo.
    echo   1. USB 디버깅을 활성화하세요
    echo   2. USB 케이블로 연결하세요
    echo   3. 폰에서 "이 컴퓨터를 항상 허용" 선택
    echo.
    pause
    exit /b
)

for /f "tokens=1" %%i in ('adb devices ^| findstr "device$"') do set DEVICE_ID=%%i
echo   ✓ 디바이스 연결됨: %DEVICE_ID%

:: 루트 확인
adb shell "su -c 'whoami'" 2>nul | findstr "root" >nul
if %errorlevel% neq 0 (
    echo   ! 루트 권한 미확인 (Magisk에서 허용 필요)
) else (
    echo   ✓ 루트 권한 확인됨
)
echo.

:: ============ STEP 5: Frida Server 설치 ============
echo [5/7] Frida Server 설치...

:: 아키텍처 확인
for /f "tokens=*" %%i in ('adb shell getprop ro.product.cpu.abi') do set ARCH_FULL=%%i
set ARCH_FULL=%ARCH_FULL: =%

if "%ARCH_FULL:~0,5%"=="arm64" (
    set ARCH=arm64
) else if "%ARCH_FULL:~0,3%"=="arm" (
    set ARCH=arm
) else (
    set ARCH=arm64
)
echo   아키텍처: %ARCH%

set SERVER_FILE=frida-server-%FRIDA_VERSION%-android-%ARCH%

:: 다운로드 확인
if exist "%SERVER_FILE%" (
    echo   ✓ Frida Server 이미 다운로드됨
    goto :install_server
)

echo   다운로드 중...
powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/frida/frida/releases/download/%FRIDA_VERSION%/%SERVER_FILE%.xz' -OutFile '%SERVER_FILE%.xz' -UseBasicParsing } catch { exit 1 }"

if %errorlevel% neq 0 (
    echo   ✗ 다운로드 실패
    pause
    exit /b
)

:: 압축 해제
if exist "%ProgramFiles%\7-Zip\7z.exe" (
    "%ProgramFiles%\7-Zip\7z.exe" x "%SERVER_FILE%.xz" -y >nul
    del "%SERVER_FILE%.xz"
) else if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" (
    "%ProgramFiles(x86)%\7-Zip\7z.exe" x "%SERVER_FILE%.xz" -y >nul
    del "%SERVER_FILE%.xz"
) else (
    echo   ! 7-Zip이 없습니다. XZ 파일을 수동으로 압축 해제하세요.
    echo   파일: %SERVER_FILE%.xz
    pause
)

:install_server
:: 서버 설치
echo   디바이스에 설치 중...
adb shell "su -c 'pkill frida-server'" 2>nul
adb push "%SERVER_FILE%" /data/local/tmp/frida-server >nul 2>&1
adb shell "su -c 'chmod 755 /data/local/tmp/frida-server'"
adb shell "su -c '/data/local/tmp/frida-server &'" 2>nul
timeout /t 2 >nul

:: 포트 포워딩
adb forward tcp:27042 tcp:27042 >nul 2>&1
echo   ✓ Frida Server 설치 완료
echo.

:: ============ STEP 6: 스크립트 생성 ============
echo [6/7] HTTPS 캡처 스크립트 생성...

:: https-capture.js 생성
(
echo Java.perform^(function^(^) {
echo     console.log^("[*] HTTPS 요청/응답 캡처 시작"^);
echo     
echo     // OkHttp3 요청/응답 캡처
echo     try {
echo         var OkHttpClient = Java.use^('okhttp3.OkHttpClient'^);
echo         var RealCall = Java.use^('okhttp3.internal.connection.RealCall'^);
echo         var Buffer = Java.use^('okio.Buffer'^);
echo         
echo         // 동기 요청 캡처
echo         RealCall.execute.implementation = function^(^) {
echo             var request = this.request^(^);
echo             console.log^("\n========== HTTPS 요청 =========="^);
echo             console.log^("URL: " + request.url^(^).toString^(^)^);
echo             console.log^("Method: " + request.method^(^)^);
echo             console.log^("Headers: " + request.headers^(^).toString^(^)^);
echo             
echo             // Request Body 캡처
echo             try {
echo                 var requestBody = request.body^(^);
echo                 if^(requestBody^) {
echo                     var buffer = Buffer.$new^(^);
echo                     requestBody.writeTo^(buffer^);
echo                     console.log^("Request Body: " + buffer.readUtf8^(^)^);
echo                 }
echo             } catch^(e^) {}
echo             
echo             // Response 실행
echo             var response = this.execute^(^);
echo             
echo             // Response 캡처
echo             console.log^("\n========== HTTPS 응답 =========="^);
echo             console.log^("Status Code: " + response.code^(^)^);
echo             console.log^("Headers: " + response.headers^(^).toString^(^)^);
echo             
echo             // Response Body 캡처
echo             try {
echo                 var responseBody = response.body^(^);
echo                 if^(responseBody^) {
echo                     var content = responseBody.string^(^);
echo                     console.log^("Response Body: " + content^);
echo                     
echo                     // 새로운 response body 생성하여 반환
echo                     var ResponseBody = Java.use^('okhttp3.ResponseBody'^);
echo                     var MediaType = Java.use^('okhttp3.MediaType'^);
echo                     var newBody = ResponseBody.create^(
echo                         MediaType.parse^("application/json"^),
echo                         content
echo                     ^);
echo                     
echo                     // Response 재생성
echo                     var builder = response.newBuilder^(^);
echo                     builder.body^(newBody^);
echo                     response = builder.build^(^);
echo                 }
echo             } catch^(e^) {
echo                 console.log^("Response Body 읽기 실패: " + e^);
echo             }
echo             
echo             console.log^("================================\n"^);
echo             return response;
echo         };
echo         
echo         // 비동기 요청 캡처
echo         RealCall.enqueue.implementation = function^(callback^) {
echo             var request = this.request^(^);
echo             console.log^("\n========== HTTPS 비동기 요청 =========="^);
echo             console.log^("URL: " + request.url^(^).toString^(^)^);
echo             console.log^("Method: " + request.method^(^)^);
echo             console.log^("Headers: " + request.headers^(^).toString^(^)^);
echo             
echo             // Request Body
echo             try {
echo                 var requestBody = request.body^(^);
echo                 if^(requestBody^) {
echo                     var buffer = Buffer.$new^(^);
echo                     requestBody.writeTo^(buffer^);
echo                     console.log^("Request Body: " + buffer.readUtf8^(^)^);
echo                 }
echo             } catch^(e^) {}
echo             
echo             // Callback 래핑
echo             var originalCallback = callback;
echo             var Callback = Java.use^('okhttp3.Callback'^);
echo             var wrappedCallback = Java.registerClass^({
echo                 name: 'com.frida.WrappedCallback',
echo                 implements: [Callback],
echo                 methods: {
echo                     onFailure: function^(call, exception^) {
echo                         console.log^("[!] 요청 실패: " + exception.toString^(^)^);
echo                         originalCallback.onFailure^(call, exception^);
echo                     },
echo                     onResponse: function^(call, response^) {
echo                         console.log^("\n========== HTTPS 비동기 응답 =========="^);
echo                         console.log^("Status Code: " + response.code^(^)^);
echo                         console.log^("Headers: " + response.headers^(^).toString^(^)^);
echo                         
echo                         try {
echo                             var responseBody = response.body^(^);
echo                             if^(responseBody^) {
echo                                 var content = responseBody.string^(^);
echo                                 console.log^("Response Body: " + content^);
echo                                 
echo                                 // 새 body 생성
echo                                 var ResponseBody = Java.use^('okhttp3.ResponseBody'^);
echo                                 var MediaType = Java.use^('okhttp3.MediaType'^);
echo                                 var newBody = ResponseBody.create^(
echo                                     MediaType.parse^("application/json"^),
echo                                     content
echo                                 ^);
echo                                 
echo                                 var builder = response.newBuilder^(^);
echo                                 builder.body^(newBody^);
echo                                 response = builder.build^(^);
echo                             }
echo                         } catch^(e^) {}
echo                         
echo                         console.log^("================================\n"^);
echo                         originalCallback.onResponse^(call, response^);
echo                     }
echo                 }
echo             }^);
echo             
echo             this.enqueue^(wrappedCallback.$new^(^)^);
echo         };
echo         
echo     } catch^(e^) {
echo         console.log^("[-] OkHttp 후킹 실패: " + e^);
echo     }
echo     
echo     console.log^("[*] HTTPS 캡처 준비 완료"^);
echo }^);
) > https-capture.js

:: run.bat 생성
(
echo @echo off
echo echo Frida 서버 시작...
echo adb shell "su -c 'pkill frida-server'"
echo adb shell "su -c '/data/local/tmp/frida-server ^&'"
echo timeout /t 2 ^>nul
echo adb forward tcp:27042 tcp:27042
echo cls
echo echo ========================================
echo echo        Frida HTTPS Capture Tool
echo echo ========================================
echo echo.
echo echo [1] 실행 중인 앱 목록:
echo frida-ps -U
echo echo.
echo echo [2] 사용법:
echo echo    frida -U -p [PID] -l https-capture.js
echo echo.
echo echo [3] 예시 ^(카카오뱅크^):
echo echo    frida -U -p 12345 -l https-capture.js
echo echo.
echo pause
) > run.bat

echo   ✓ 스크립트 생성 완료
echo.

:: ============ STEP 7: 테스트 ============
echo [7/7] 연결 테스트...
frida-ps -U 2>nul | findstr "PID" >nul
if %errorlevel% equ 0 (
    echo   ✓ Frida 정상 작동 확인
) else (
    echo   ! Frida 연결 실패 - 수동으로 확인 필요
)
echo.

:: ============ 완료 ============
echo ================================================
echo           설치가 완료되었습니다!
echo ================================================
echo.
echo 생성된 파일:
echo   • https-capture.js - HTTPS 트래픽 캡처 스크립트
echo   • run.bat - Frida 실행 도우미
echo.
echo 사용 방법:
echo   1. 대상 앱 실행
echo   2. run.bat 실행
echo   3. PID 확인 후 명령어 실행
echo.
echo 명령어 예시:
echo   frida -U -p [PID] -l https-capture.js
echo.
echo 결과 저장:
echo   frida -U -p [PID] -l https-capture.js ^> output.txt
echo.
pause