Java.perform(function() {
    console.log("[*] HTTPS 요청/응답 캡처 시작");
    
    // OkHttp3 요청/응답 캡처
    try {
        var OkHttpClient = Java.use('okhttp3.OkHttpClient');
        var RealCall = Java.use('okhttp3.internal.connection.RealCall');
        var Buffer = Java.use('okio.Buffer');
        
        // 동기 요청 캡처
        RealCall.execute.implementation = function() {
            var request = this.request();
            console.log("\n========== HTTPS 요청 ==========");
            console.log("URL: " + request.url().toString());
            console.log("Method: " + request.method());
            console.log("Headers: " + request.headers().toString());
            
            // Request Body 캡처
            try {
                var requestBody = request.body();
                if(requestBody) {
                    var buffer = Buffer.$new();
                    requestBody.writeTo(buffer);
                    console.log("Request Body: " + buffer.readUtf8());
                }
            } catch(e) {}
            
            // Response 실행
            var response = this.execute();
            
            // Response 캡처
            console.log("\n========== HTTPS 응답 ==========");
            console.log("Status Code: " + response.code());
            console.log("Headers: " + response.headers().toString());
            
            // Response Body 캡처 (주의: body는 한번만 읽을 수 있음)
            try {
                var responseBody = response.body();
                if(responseBody) {
                    var content = responseBody.string();
                    console.log("Response Body: " + content);
                    
                    // 새로운 response body 생성하여 반환 (앱이 정상작동하도록)
                    var ResponseBody = Java.use('okhttp3.ResponseBody');
                    var MediaType = Java.use('okhttp3.MediaType');
                    var newBody = ResponseBody.create(
                        MediaType.parse("application/json"),
                        content
                    );
                    
                    // Response 재생성
                    var builder = response.newBuilder();
                    builder.body(newBody);
                    response = builder.build();
                }
            } catch(e) {
                console.log("Response Body 읽기 실패: " + e);
            }
            
            console.log("================================\n");
            return response;
        };
        
        // 비동기 요청 캡처
        RealCall.enqueue.implementation = function(callback) {
            var request = this.request();
            console.log("\n========== HTTPS 비동기 요청 ==========");
            console.log("URL: " + request.url().toString());
            console.log("Method: " + request.method());
            console.log("Headers: " + request.headers().toString());
            
            // Request Body
            try {
                var requestBody = request.body();
                if(requestBody) {
                    var buffer = Buffer.$new();
                    requestBody.writeTo(buffer);
                    console.log("Request Body: " + buffer.readUtf8());
                }
            } catch(e) {}
            
            // Callback 래핑
            var originalCallback = callback;
            var Callback = Java.use('okhttp3.Callback');
            var wrappedCallback = Java.registerClass({
                name: 'com.frida.WrappedCallback',
                implements: [Callback],
                methods: {
                    onFailure: function(call, exception) {
                        console.log("[!] 요청 실패: " + exception.toString());
                        originalCallback.onFailure(call, exception);
                    },
                    onResponse: function(call, response) {
                        console.log("\n========== HTTPS 비동기 응답 ==========");
                        console.log("Status Code: " + response.code());
                        console.log("Headers: " + response.headers().toString());
                        
                        try {
                            var responseBody = response.body();
                            if(responseBody) {
                                var content = responseBody.string();
                                console.log("Response Body: " + content);
                                
                                // 새 body 생성
                                var ResponseBody = Java.use('okhttp3.ResponseBody');
                                var MediaType = Java.use('okhttp3.MediaType');
                                var newBody = ResponseBody.create(
                                    MediaType.parse("application/json"),
                                    content
                                );
                                
                                var builder = response.newBuilder();
                                builder.body(newBody);
                                response = builder.build();
                            }
                        } catch(e) {}
                        
                        console.log("================================\n");
                        originalCallback.onResponse(call, response);
                    }
                }
            });
            
            this.enqueue(wrappedCallback.$new());
        };
        
    } catch(e) {
        console.log("[-] OkHttp 후킹 실패: " + e);
    }
    
    // Retrofit 인터셉터
    try {
        var Interceptor = Java.use('okhttp3.Interceptor');
        var MyInterceptor = Java.registerClass({
            name: 'com.frida.MyInterceptor',
            implements: [Interceptor],
            methods: {
                intercept: function(chain) {
                    var request = chain.request();
                    console.log("[Interceptor] Request: " + request.url().toString());
                    
                    var response = chain.proceed(request);
                    console.log("[Interceptor] Response: " + response.code());
                    
                    return response;
                }
            }
        });
        
        // OkHttpClient.Builder에 인터셉터 추가
        var Builder = Java.use('okhttp3.OkHttpClient$Builder');
        Builder.build.implementation = function() {
            this.addInterceptor(MyInterceptor.$new());
            return this.build();
        };
        
    } catch(e) {}
    
    console.log("[*] HTTPS 캡처 준비 완료");
});