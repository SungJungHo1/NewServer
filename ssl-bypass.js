console.log("[*] SSL Pinning 우회 시작");

Java.perform(function() {
    // 1. 일반 SSL 우회
    try {
        var SSLContext = Java.use('javax.net.ssl.SSLContext');
        var X509TrustManager = Java.use('javax.net.ssl.X509TrustManager');
        
        var TrustManager = Java.registerClass({
            name: 'com.dummy.TrustManager',
            implements: [X509TrustManager],
            methods: {
                checkClientTrusted: function() {
                    console.log('[+] checkClientTrusted 우회');
                },
                checkServerTrusted: function() {
                    console.log('[+] checkServerTrusted 우회');
                },
                getAcceptedIssuers: function() {
                    return [];
                }
            }
        });
        
        SSLContext.init.overload('[Ljavax.net.ssl.KeyManager;', '[Ljavax.net.ssl.TrustManager;', 'java.security.SecureRandom')
            .implementation = function(a, b, c) {
                console.log('[+] SSLContext.init 후킹');
                this.init(a, [TrustManager.$new()], c);
            };
    } catch(e) {
        console.log('[-] SSL 우회 실패: ' + e);
    }
    
    // 2. OkHttp 우회
    try {
        var CertificatePinner = Java.use('okhttp3.CertificatePinner');
        CertificatePinner.check.overload('java.lang.String', 'java.util.List')
            .implementation = function() {
                console.log('[+] CertificatePinner.check 우회');
            };
    } catch(e) {}
    
    console.log("[*] SSL 우회 준비 완료");
});