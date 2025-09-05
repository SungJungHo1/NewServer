Java.perform(function() {
    console.log("[*] 카카오뱅크 SSL Pinning 우회 v2");
    
    // 1. CertificatePinner를 null이 아닌 빈 객체로 반환
    try {
        var CertificatePinner = Java.use('okhttp3.CertificatePinner');
        var Builder = Java.use('okhttp3.CertificatePinner$Builder');
        
        // 빈 CertificatePinner 생성
        Builder.build.implementation = function() {
            console.log('[+] CertificatePinner.Builder.build() - 빈 Pinner 반환');
            return Builder.$new().build();
        };
        
        // check 메소드 무효화
        CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {
            console.log('[+] CertificatePinner.check() 우회');
            return;
        };
        
        CertificatePinner.check.overload('java.lang.String', '[Ljava.security.cert.Certificate;').implementation = function() {
            console.log('[+] CertificatePinner.check() 우회 2');
            return;
        };
        
        // OkHttpClient의 certificatePinner는 null이 아닌 기본값 반환
        var OkHttpClient = Java.use('okhttp3.OkHttpClient');
        OkHttpClient.certificatePinner.overload().implementation = function() {
            console.log('[+] OkHttpClient.certificatePinner() - 기본 Pinner 반환');
            return CertificatePinner.DEFAULT.value;
        };
        
    } catch(e) {
        console.log('[-] CertificatePinner 우회 실패: ' + e);
    }
    
    // 2. SSL Context 우회 (안전한 방식)
    try {
        var X509TrustManager = Java.use('javax.net.ssl.X509TrustManager');
        var SSLContext = Java.use('javax.net.ssl.SSLContext');
        
        var TrustManager = Java.registerClass({
            name: 'com.dummy.TrustManager',
            implements: [X509TrustManager],
            methods: {
                checkClientTrusted: function(chain, authType) {},
                checkServerTrusted: function(chain, authType) {},
                getAcceptedIssuers: function() {
                    return Java.array('java.security.cert.X509Certificate', []);
                }
            }
        });
        
        // SSLContext.init 후킹
        SSLContext.init.overload('[Ljavax.net.ssl.KeyManager;', '[Ljavax.net.ssl.TrustManager;', 'java.security.SecureRandom').implementation = function(km, tm, sr) {
            console.log('[+] SSLContext.init() 호출');
            this.init(km, [TrustManager.$new()], sr);
        };
        
    } catch(e) {
        console.log('[-] SSLContext 우회 실패: ' + e);
    }
    
    // 3. HostnameVerifier 우회
    try {
        var HostnameVerifier = Java.use('javax.net.ssl.HostnameVerifier');
        var HttpsURLConnection = Java.use('javax.net.ssl.HttpsURLConnection');
        
        HttpsURLConnection.setDefaultHostnameVerifier.implementation = function(hv) {
            console.log('[+] setDefaultHostnameVerifier() 우회');
            var NullHostnameVerifier = Java.registerClass({
                name: 'com.dummy.NullHostnameVerifier', 
                implements: [HostnameVerifier],
                methods: {
                    verify: function(hostname, session) {
                        return true;
                    }
                }
            });
            this.setDefaultHostnameVerifier(NullHostnameVerifier.$new());
        };
        
    } catch(e) {}
    
    // 4. WebView SSL 에러 처리
    try {
        var WebViewClient = Java.use('android.webkit.WebViewClient');
        WebViewClient.onReceivedSslError.implementation = function(view, handler, error) {
            console.log('[+] WebView SSL 에러 처리');
            handler.proceed();
        };
    } catch(e) {}
    
    // 5. 네트워크 보안 설정 우회
    try {
        var NetworkSecurityConfig = Java.use('android.security.net.config.NetworkSecurityConfig');
        NetworkSecurityConfig.getDefaultBuilder.implementation = function(applicationInfo) {
            console.log('[+] NetworkSecurityConfig 우회');
            return this.getDefaultBuilder(applicationInfo);
        };
    } catch(e) {}
    
    // 6. 루팅 체크 우회
    try {
        var File = Java.use('java.io.File');
        File.exists.implementation = function() {
            var path = this.getPath();
            var rootPaths = ['/su', '/magisk', '/busybox', 'superuser'];
            for(var i = 0; i < rootPaths.length; i++) {
                if(path.toLowerCase().indexOf(rootPaths[i]) !== -1) {
                    console.log('[+] 루팅 파일 체크 우회: ' + path);
                    return false;
                }
            }
            return this.exists();
        };
    } catch(e) {}
    
    console.log('[*] 우회 스크립트 로드 완료');
});