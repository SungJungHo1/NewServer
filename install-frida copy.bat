@echo off
chcp 65001 >nul
title Frida HTTPS Capture Auto Installer
color 0A

echo ================================================
echo      Frida HTTPS 캡처 자동 설치 v2.1
echo           (Push 문제 수정 버전)
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
:: 파일 크기 확인
if not exist "%SERVER_FILE%" (
    echo   ! %SERVER_FILE% 파일이 없습니다.
    echo   압축을 해제했는지 확인하세요.
    pause
    exit /b
)

for %%A in ("%SERVER_FILE%") do set FILE_SIZE=%%~zA
echo   파일 크기: %FILE_SIZE% bytes

:: 서버 설치 (개선된 방법)
echo   기존 프로세스 종료 중...
adb shell "su -c 'pkill -f frida-server'" 2>nul
timeout /t 1 >nul

echo   디바이스에 설치 중...
:: 먼저 임시 위치로 푸시
adb push "%SERVER_FILE%" /sdcard/frida-server-temp
if %errorlevel% neq 0 (
    echo   ! Push 실패. 다시 시도 중...
    adb push "%SERVER_FILE%" /data/local/tmp/frida-server
    if %errorlevel% neq 0 (
        echo   ✗ 파일 전송 실패
        pause
        exit /b
    )
) else (
    :: sdcard에서 /data/local/tmp로 이동
    echo   파일 이동 중...
    adb shell "su -c 'cp /sdcard/frida-server-temp /data/local/tmp/frida-server'"
    adb shell "rm /sdcard/frida-server-temp"
)

echo   권한 설정 중...
adb shell "su -c 'chmod 755 /data/local/tmp/frida-server'"

echo   서버 시작 중...
:: 백그라운드에서 실행
adb shell "su -c 'nohup /data/local/tmp/frida-server > /dev/null 2>&1 &'"
timeout /t 3 >nul

:: 포트 포워딩
echo   포트 포워딩 설정...
adb forward tcp:27042 tcp:27042 >nul 2>&1

:: 프로세스 확인
adb shell "ps | grep frida-server" >nul 2>&1
if %errorlevel% equ 0 (
    echo   ✓ Frida Server 실행 중
) else (
    echo   ! Frida Server 실행 확인 실패
    echo   수동으로 확인해보세요: adb shell ps ^| grep frida
)
echo.

:: ============ STEP 6: 스크립트 생성 ============
echo [6/7] HTTPS 캡처 스크립트 생성...

:: https-capture.js 생성 (PowerShell 사용)
powershell -Command "$script = @'
Java.perform(function() {
    console.log('[*] HTTPS 요청/응답 캡처 시작');
    
    // OkHttp3 요청/응답 캡처
    try {
        var OkHttpClient = Java.use('okhttp3.OkHttpClient');
        var RealCall = Java.use('okhttp3.internal.connection.RealCall');
        var Buffer = Java.use('okio.Buffer');
        
        // 동기 요청 캡처
        RealCall.execute.implementation = function() {
            var request = this.request();
            console.log('\n========== HTTPS 요청 ==========');
            console.log('URL: ' + request.url().toString());
            console.log('Method: ' + request.method());
            console.log('Headers: ' + request.headers().toString());
            
            try {
                var requestBody = request.body();
                if(requestBody) {
                    var buffer = Buffer.`$new();
                    requestBody.writeTo(buffer);
                    console.log('Request Body: ' + buffer.readUtf8());
                }
            } catch(e) {}
            
            var response = this.execute();
            
            console.log('\n========== HTTPS 응답 ==========');
            console.log('Status Code: ' + response.code());
            console.log('Headers: ' + response.headers().toString());
            
            try {
                var responseBody = response.body();
                if(responseBody) {
                    var content = responseBody.string();
                    console.log('Response Body: ' + content);
                    
                    var ResponseBody = Java.use('okhttp3.ResponseBody');
                    var MediaType = Java.use('okhttp3.MediaType');
                    var newBody = ResponseBody.create(
                        MediaType.parse('application/json'),
                        content
                    );
                    
                    var builder = response.newBuilder();
                    builder.body(newBody);
                    response = builder.build();
                }
            } catch(e) {
                console.log('Response Body 읽기 실패: ' + e);
            }
            
            console.log('================================\n');
            return response;
        };
        
        // 비동기 요청 캡처
        RealCall.enqueue.implementation = function(callback) {
            var request = this.request();
            console.log('\n========== HTTPS 비동기 요청 ==========');
            console.log('URL: ' + request.url().toString());
            console.log('Method: ' + request.method());
            console.log('Headers: ' + request.headers().toString());
            
            try {
                var requestBody = request.body();
                if(requestBody) {
                    var buffer = Buffer.`$new();
                    requestBody.writeTo(buffer);
                    console.log('Request Body: ' + buffer.readUtf8());
                }
            } catch(e) {}
            
            var originalCallback = callback;
            var Callback = Java.use('okhttp3.Callback');
            var wrappedCallback = Java.registerClass({
                name: 'com.frida.WrappedCallback',
                implements: [Callback],
                methods: {
                    onFailure: function(call, exception) {
                        console.log('[!] 요청 실패: ' + exception.toString());
                        originalCallback.onFailure(call, exception);
                    },
                    onResponse: function(call, response) {
                        console.log('\n========== HTTPS 비동기 응답 ==========');
                        console.log('Status Code: ' + response.code());
                        console.log('Headers: ' + response.headers().toString());
                        
                        try {
                            var responseBody = response.body();
                            if(responseBody) {
                                var content = responseBody.string();
                                console.log('Response Body: ' + content);
                                
                                var ResponseBody = Java.use('okhttp3.ResponseBody');
                                var MediaType = Java.use('okhttp3.MediaType');
                                var newBody = ResponseBody.create(
                                    MediaType.parse('application/json'),
                                    content
                                );
                                
                                var builder = response.newBuilder();
                                builder.body(newBody);
                                response = builder.build();
                            }
                        } catch(e) {}
                        
                        console.log('================================\n');
                        originalCallback.onResponse(call, response);
                    }
                }
            });
            
            this.enqueue(wrappedCallback.`$new());
        };
        
    } catch(e) {
        console.log('[-] OkHttp 후킹 실패: ' + e);
    }
    
    console.log('[*] HTTPS 캡처 준비 완료');
});
'@; `$script | Out-File -FilePath 'https-capture.js' -Encoding UTF8"

:: run.bat 생성
(
echo @echo off
echo echo Frida 서버 재시작...
echo adb shell "su -c 'pkill -f frida-server'"
echo timeout /t 1 ^>nul
echo adb shell "su -c '/data/local/tmp/frida-server ^&'"
echo timeout /t 3 ^>nul
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
echo echo [3] 예시:
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
    echo   ✓ Frida 정상 작동 확인!
    echo.
    echo   실행 중인 프로세스 (일부):
    frida-ps -U | findstr /N "^" | findstr "^[1-5]:"
) else (
    echo   ! Frida 연결 테스트 중...
    echo   수동 확인: frida-ps -U
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